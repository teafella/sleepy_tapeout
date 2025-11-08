/*
 * SPI RX Slave with Register Bank (Minimal - Area-Optimized)
 *
 * This module implements a minimal SPI slave receiver for the synthesizer.
 * It supports:
 * - SPI Mode 0 (CPOL=0, CPHA=0): Sample on rising edge, shift on falling edge
 * - RX-only (no MISO, saves area)
 * - 8 essential registers (includes streaming sample)
 * - Simple 2-byte protocol: [address][data]
 * - Burst writes with auto-increment
 *
 * EXTREME AREA OPTIMIZATION: SPI is simpler than UART
 * - No baud rate generator (~30 cells saved)
 * - No oversampling logic (~20 cells saved)
 * - Synchronous protocol (simpler state machine, ~10 cells saved)
 * Total: ~45 cells (vs ~180 for UART, ~220 for I2C)
 *
 * Protocol:
 * 1. Assert CS (active low)
 * 2. Send register address byte (8 bits)
 * 3. Send data byte (8 bits)
 * 4. Deassert CS (or continue for burst write)
 *
 * Pins:
 * - MOSI: Master Out Slave In (data from master)
 * - SCK:  SPI Clock (from master)
 * - CS:   Chip Select (active low)
 *
 * Register Map (8 registers):
 * 0x00: Control (bit 0=OSC_EN, bit 1=STREAM_MODE, bit 2=SW_GATE, bits 3-5=waveform enables)
 * 0x02-0x04: Frequency (24-bit, little-endian)
 * 0x05: Duty cycle (square wave PWM)
 * 0x06: Volume (8-level bit-shift: 0x00=mute, 0xFF=full)
 * 0x10: Streaming sample (8-bit sample for direct DAC output)
 * 0x12: Status (read-only, writes ignored)
 *
 * Resource Usage: ~45 cells
 */

module spi_rx_registers (
    input  wire        clk,            // System clock (50 MHz)
    input  wire        rst_n,          // Active-low reset

    // SPI interface (3 pins, all inputs for RX-only)
    input  wire        spi_mosi,       // Master Out Slave In (uio[0])
    input  wire        spi_sck,        // SPI Clock (uio[1])
    input  wire        spi_cs,         // Chip Select, active low (uio[2])

    // Essential register outputs (8 registers total)
    output reg [7:0]   reg_control,       // 0x00: Control with waveform enables + STREAM_MODE
    output reg [7:0]   reg_freq_low,      // 0x02: Frequency low byte
    output reg [7:0]   reg_freq_mid,      // 0x03: Frequency mid byte
    output reg [7:0]   reg_freq_high,     // 0x04: Frequency high byte
    output reg [7:0]   reg_duty,          // 0x05: Square wave duty cycle
    output reg [7:0]   reg_volume,        // 0x06: Master volume (8-level bit-shift)
    output reg [7:0]   reg_stream_sample, // 0x10: Streaming sample (direct DAC)
    output wire [7:0]  reg_status,        // 0x12: Read-only status

    // Status inputs (for read-only status register)
    input  wire        status_gate_active,
    input  wire        status_osc_running
);

    // ========================================
    // Input Synchronizers (2-stage)
    // ========================================
    reg [1:0] mosi_sync;
    reg [1:0] sck_sync;
    reg [1:0] cs_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mosi_sync <= 2'b00;
            sck_sync <= 2'b00;
            cs_sync <= 2'b11;  // CS idle high
        end else begin
            mosi_sync <= {mosi_sync[0], spi_mosi};
            sck_sync <= {sck_sync[0], spi_sck};
            cs_sync <= {cs_sync[0], spi_cs};
        end
    end

    wire mosi = mosi_sync[1];
    wire sck = sck_sync[1];
    wire cs = cs_sync[1];

    // Edge detection for SCK (sample on rising edge)
    wire sck_rising = (sck_sync == 2'b01);

    // ========================================
    // SPI RX State Machine
    // ========================================
    localparam STATE_IDLE = 2'd0;
    localparam STATE_ADDR = 2'd1;
    localparam STATE_DATA = 2'd2;

    reg [1:0] state;
    reg [2:0] bit_count;
    reg [7:0] shift_reg;
    reg [7:0] address_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            bit_count <= 0;
            shift_reg <= 0;
            address_reg <= 0;
            // Initialize all registers on reset (required for synthesis)
            reg_control <= 8'b00011100;     // OSC=0, STREAM=0, SW_GATE=0, all waveforms enabled
            reg_freq_low <= 8'h00;
            reg_freq_mid <= 8'h00;
            reg_freq_high <= 8'h00;
            reg_duty <= 8'h80;              // 50% duty cycle
            reg_volume <= 8'hFF;            // Full volume by default
            reg_stream_sample <= 8'h80;     // Middle value (128) for streaming
        end else begin
            // CS deasserted - return to idle
            if (cs) begin
                state <= STATE_IDLE;
                bit_count <= 0;
            end
            // CS asserted and SCK rising edge - shift in data
            else if (sck_rising) begin
                // Shift in MOSI bit (MSB first)
                shift_reg <= {shift_reg[6:0], mosi};

                case (state)
                    STATE_IDLE: begin
                        // First bit of address
                        state <= STATE_ADDR;
                        bit_count <= 1;
                    end

                    STATE_ADDR: begin
                        if (bit_count == 7) begin
                            // Byte complete (8 bits received)
                            address_reg <= {shift_reg[6:0], mosi};
                            state <= STATE_DATA;
                            bit_count <= 0;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                    end

                    STATE_DATA: begin
                        if (bit_count == 7) begin
                            // Byte complete (8 bits received)
                            write_register(address_reg, {shift_reg[6:0], mosi});
                            // Auto-increment for burst writes
                            address_reg <= address_reg + 1;
                            bit_count <= 0;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                    end

                    default: state <= STATE_IDLE;
                endcase
            end
        end
    end

    // ========================================
    // Status Register (Read-Only)
    // ========================================
    assign reg_status = {6'b000000, status_osc_running, status_gate_active};

    // ========================================
    // Register Write Task (8 essential registers)
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
                8'h10: reg_stream_sample <= data;
                // 0x12 is read-only status register, writes ignored
                default: begin
                    // Invalid address, ignore
                end
            endcase
        end
    endtask

    // ========================================
    // Register Initialization
    // ========================================
    // NOTE: Registers are now initialized in the reset clause of the always block above
    // initial blocks are not synthesizable for ASIC designs!

endmodule
