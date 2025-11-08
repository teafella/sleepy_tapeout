/*
 * UART RX with Register Bank (Minimal - Area-Optimized)
 *
 * This module implements a simple UART receiver for the synthesizer.
 * It supports:
 * - 115200 baud (8N1 format)
 * - RX-only (no TX, saves ~40 cells)
 * - 7 essential registers (same as I2C version)
 * - Simple 2-byte protocol: [address][data]
 *
 * AREA OPTIMIZATION: UART RX is much simpler than I2C slave
 * - No bidirectional pin handling
 * - No ACK/NACK protocol
 * - No clock stretching
 * - No address matching complexity
 * Saves ~140 cells compared to I2C slave (220 vs 80)
 *
 * Protocol:
 * Send pairs of bytes: [register_address][data_value]
 * Example: 0x00 0x1D → Write 0x1D to control register
 *          0x02 0x00 0x03 0x40 0x04 0x02 → Write frequency 0x024000
 *
 * Register Map (7 registers, same as I2C version):
 * 0x00: Control (bit 0=OSC_EN, bit 1=SW_GATE, bits 2-4=waveform enables)
 * 0x02-0x04: Frequency (24-bit, little-endian)
 * 0x05: Duty cycle (square wave PWM)
 * 0x06: Volume (0x00=mute, 0xFF=full volume, now smooth!)
 * 0x12: Status (read-only, writes ignored)
 *
 * Resource Usage: ~80 cells (2% of 1x1 tile, vs ~220 for I2C)
 */

module uart_rx_registers #(
    parameter CLK_FREQ = 50_000_000,   // 50 MHz system clock
    parameter BAUD_RATE = 115200       // 115200 baud
) (
    input  wire        clk,            // System clock (50 MHz)
    input  wire        rst_n,          // Active-low reset

    // UART RX pin
    input  wire        rx,             // UART receive pin (uio[0])

    // Essential register outputs (7 registers total)
    output reg [7:0]   reg_control,       // 0x00: Control with waveform enables
    output reg [7:0]   reg_freq_low,      // 0x02: Frequency low byte
    output reg [7:0]   reg_freq_mid,      // 0x03: Frequency mid byte
    output reg [7:0]   reg_freq_high,     // 0x04: Frequency high byte
    output reg [7:0]   reg_duty,          // 0x05: Square wave duty cycle
    output reg [7:0]   reg_volume,        // 0x06: Master volume (smooth 0x00-0xFF)
    output wire [7:0]  reg_status,        // 0x12: Read-only status

    // Status inputs (for read-only status register)
    input  wire        status_gate_active,
    input  wire        status_osc_running
);

    // ========================================
    // Baud Rate Generator
    // ========================================
    // At 50 MHz, 115200 baud with 8x oversampling:
    // Divisor = 50,000,000 / (115200 × 8) = 54.25 ≈ 54
    localparam BAUD_DIV = CLK_FREQ / (BAUD_RATE * 8);

    reg [$clog2(BAUD_DIV)-1:0] baud_counter;
    reg baud_tick;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            baud_counter <= 0;
            baud_tick <= 0;
        end else begin
            if (baud_counter == BAUD_DIV - 1) begin
                baud_counter <= 0;
                baud_tick <= 1;
            end else begin
                baud_counter <= baud_counter + 1;
                baud_tick <= 0;
            end
        end
    end

    // ========================================
    // RX Input Synchronizer (2-stage)
    // ========================================
    reg [1:0] rx_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            rx_sync <= 2'b11;
        else
            rx_sync <= {rx_sync[0], rx};
    end

    wire rx_stable = rx_sync[1];

    // ========================================
    // UART RX State Machine
    // ========================================
    localparam STATE_IDLE  = 3'd0;
    localparam STATE_START = 3'd1;
    localparam STATE_DATA  = 3'd2;
    localparam STATE_STOP  = 3'd3;

    reg [2:0] state;
    reg [2:0] bit_index;
    reg [2:0] sample_count;
    reg [7:0] rx_shift_reg;
    reg [7:0] rx_byte;
    reg       rx_valid;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            bit_index <= 0;
            sample_count <= 0;
            rx_shift_reg <= 0;
            rx_byte <= 0;
            rx_valid <= 0;
        end else begin
            rx_valid <= 0;  // Pulse for one clock

            if (baud_tick) begin
                case (state)
                    STATE_IDLE: begin
                        // Wait for start bit (falling edge)
                        if (rx_stable == 0) begin
                            state <= STATE_START;
                            sample_count <= 0;
                        end
                    end

                    STATE_START: begin
                        // Wait for middle of start bit
                        if (sample_count == 3) begin  // Middle of bit at 8x oversampling
                            if (rx_stable == 0) begin
                                // Valid start bit
                                state <= STATE_DATA;
                                bit_index <= 0;
                                sample_count <= 0;
                            end else begin
                                // False start bit
                                state <= STATE_IDLE;
                            end
                        end else begin
                            sample_count <= sample_count + 1;
                        end
                    end

                    STATE_DATA: begin
                        if (sample_count == 7) begin  // Sample at end of bit period
                            // Sample data bit
                            rx_shift_reg <= {rx_stable, rx_shift_reg[7:1]};
                            sample_count <= 0;

                            if (bit_index == 7) begin
                                // Last data bit received
                                state <= STATE_STOP;
                            end else begin
                                bit_index <= bit_index + 1;
                            end
                        end else begin
                            sample_count <= sample_count + 1;
                        end
                    end

                    STATE_STOP: begin
                        if (sample_count == 7) begin
                            // Sample stop bit
                            if (rx_stable == 1) begin
                                // Valid stop bit, byte received
                                rx_byte <= rx_shift_reg;
                                rx_valid <= 1;
                            end
                            state <= STATE_IDLE;
                            sample_count <= 0;
                        end else begin
                            sample_count <= sample_count + 1;
                        end
                    end

                    default: state <= STATE_IDLE;
                endcase
            end
        end
    end

    // ========================================
    // Protocol Handler (2-byte: address, data)
    // ========================================
    reg protocol_state;  // 0=waiting for address, 1=waiting for data
    reg [7:0] current_address;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            protocol_state <= 0;
            current_address <= 0;
        end else if (rx_valid) begin
            if (protocol_state == 0) begin
                // Received address byte
                current_address <= rx_byte;
                protocol_state <= 1;
            end else begin
                // Received data byte, write to register
                write_register(current_address, rx_byte);
                protocol_state <= 0;
            end
        end
    end

    // ========================================
    // Status Register (Read-Only)
    // ========================================
    assign reg_status = {6'b000000, status_osc_running, status_gate_active};

    // ========================================
    // Register Write Task (7 essential registers)
    // ========================================
    task write_register;
        input [7:0] addr;
        input [7:0] data;
        begin
            case (addr)
                8'h00: reg_control <= data;
                8'h02: reg_freq_low <= data;
                8'h03: reg_freq_mid <= data;
                8'h04: reg_freq_high <= data;
                8'h05: reg_duty <= data;
                8'h06: reg_volume <= data;
                // 0x12 is read-only status register, writes ignored
                default: begin
                    // Invalid address, ignore
                end
            endcase
        end
    endtask

    // ========================================
    // Register Initialization (7 essential registers)
    // ========================================
    initial begin
        reg_control = 8'b00011100;     // Oscillator disabled, all 3 waveforms enabled
        reg_freq_low = 8'h00;
        reg_freq_mid = 8'h00;
        reg_freq_high = 8'h00;
        reg_duty = 8'h80;              // 50% duty cycle
        reg_volume = 8'hFF;            // Full volume by default
    end

endmodule
