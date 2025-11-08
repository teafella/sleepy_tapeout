/*
 * SPI RX Slave with Register Bank (Wavetable Synthesizer)
 *
 * This module implements a minimal SPI slave receiver for the wavetable synthesizer.
 * It supports:
 * - SPI Mode 0 (CPOL=0, CPHA=0): Sample on rising edge, shift on falling edge
 * - RX-only (no MISO, saves area)
 * - 12 registers total (control + frequency + volume + 8 wavetable samples)
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
 * Register Map (12 registers total):
 * 0x00: Control (bit 0=OSC_EN, bit 1=STREAM_MODE, bit 2=SW_GATE)
 * 0x02-0x04: Frequency (24-bit, little-endian)
 * 0x05: Volume (8-level bit-shift: 0x00=mute, 0xFF=full)
 * 0x10-0x17: Wavetable (8 samples, 8-bit each)
 * 0x18: Status (read-only, writes ignored)
 *
 * Resource Usage: ~45 cells (SPI interface only, wavetable RAM in oscillator)
 */

module spi_rx_registers (
    input  wire        clk,            // System clock (50 MHz)
    input  wire        rst_n,          // Active-low reset

    // SPI interface (3 pins, all inputs for RX-only)
    input  wire        spi_mosi,       // Master Out Slave In (uio[0])
    input  wire        spi_sck,        // SPI Clock (uio[1])
    input  wire        spi_cs,         // Chip Select, active low (uio[2])

    // Register outputs (12 registers total)
    output reg [7:0]   reg_control,       // 0x00: Control (OSC_EN, STREAM_MODE, SW_GATE)
    output reg [7:0]   reg_freq_low,      // 0x02: Frequency low byte
    output reg [7:0]   reg_freq_mid,      // 0x03: Frequency mid byte
    output reg [7:0]   reg_freq_high,     // 0x04: Frequency high byte
    output reg [7:0]   reg_volume,        // 0x05: Master volume (8-level 0x00-0xFF)
    output reg [7:0]   reg_wavetable_0,   // 0x10: Wavetable sample 0
    output reg [7:0]   reg_wavetable_1,   // 0x11: Wavetable sample 1
    output reg [7:0]   reg_wavetable_2,   // 0x12: Wavetable sample 2
    output reg [7:0]   reg_wavetable_3,   // 0x13: Wavetable sample 3
    output reg [7:0]   reg_wavetable_4,   // 0x14: Wavetable sample 4
    output reg [7:0]   reg_wavetable_5,   // 0x15: Wavetable sample 5
    output reg [7:0]   reg_wavetable_6,   // 0x16: Wavetable sample 6
    output reg [7:0]   reg_wavetable_7,   // 0x17: Wavetable sample 7
    output wire [7:0]  reg_status,        // 0x18: Read-only status

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
    // Register Write Task (12 registers total)
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
                8'h05: reg_volume <= data;
                8'h10: reg_wavetable_0 <= data;
                8'h11: reg_wavetable_1 <= data;
                8'h12: reg_wavetable_2 <= data;
                8'h13: reg_wavetable_3 <= data;
                8'h14: reg_wavetable_4 <= data;
                8'h15: reg_wavetable_5 <= data;
                8'h16: reg_wavetable_6 <= data;
                8'h17: reg_wavetable_7 <= data;
                // 0x18 is read-only status register, writes ignored
                default: begin
                    // Invalid address, ignore
                end
            endcase
        end
    endtask

    // ========================================
    // Register Initialization (12 registers total)
    // ========================================
    initial begin
        reg_control = 8'b00000000;     // Oscillator disabled, wavetable mode, gate off
        reg_freq_low = 8'h00;
        reg_freq_mid = 8'h00;
        reg_freq_high = 8'h00;
        reg_volume = 8'hFF;            // Full volume by default

        // Initialize wavetable with sawtooth (example)
        reg_wavetable_0 = 8'd0;
        reg_wavetable_1 = 8'd36;
        reg_wavetable_2 = 8'd73;
        reg_wavetable_3 = 8'd109;
        reg_wavetable_4 = 8'd146;
        reg_wavetable_5 = 8'd182;
        reg_wavetable_6 = 8'd219;
        reg_wavetable_7 = 8'd255;
    end

endmodule
