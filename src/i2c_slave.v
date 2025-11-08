/*
 * I2C Slave Interface with Register Bank (Minimal - Extreme Area-Optimized)
 *
 * This module implements a minimal I2C slave interface for the synthesizer.
 * It supports:
 * - 7-bit addressing
 * - Standard mode (100 kHz) and Fast mode (400 kHz)
 * - 11 essential registers only (was 16)
 * - Read and write operations
 * - Input synchronizers for SCL and SDA
 *
 * EXTREME AREA OPTIMIZATION: Removed individual gain registers
 * Waveform enables are now in control register bits
 * Saves ~100 cells from register storage and muxing logic
 *
 * Register Map (7 registers):
 * 0x00: Control (bit 0=OSC_EN, bit 1=SW_GATE, bits 2-4=waveform enables)
 * 0x02-0x04: Frequency (24-bit, little-endian)
 * 0x05: Duty cycle (square wave PWM)
 * 0x06: Volume (0x00=mute, 0xFF=full volume)
 * 0x12: Status (read-only: gate, osc running)
 *
 * Resource Usage: ~220 cells (5.5% of 1x1 tile, was ~300 cells)
 */

module i2c_slave #(
    parameter I2C_ADDR = 7'h50  // Default 7-bit I2C address
) (
    input  wire        clk,        // System clock (50 MHz)
    input  wire        rst_n,      // Active-low reset

    // I2C bus (from UIOs)
    input  wire        scl_in,     // I2C clock input (uio[1])
    input  wire        sda_in,     // I2C data input (uio[0])
    output wire        sda_out,    // I2C data output
    output wire        sda_oe,     // I2C data output enable (1=drive, 0=hi-z)

    // Essential register outputs (7 registers total)
    // Control register bits: [0]=OSC_EN, [1]=SW_GATE, [2]=enable_square, [3]=enable_sawtooth, [4]=enable_triangle
    output reg [7:0]   reg_control,       // 0x00: Control with waveform enables
    output reg [7:0]   reg_freq_low,      // 0x02: Frequency low byte
    output reg [7:0]   reg_freq_mid,      // 0x03: Frequency mid byte
    output reg [7:0]   reg_freq_high,     // 0x04: Frequency high byte
    output reg [7:0]   reg_duty,          // 0x05: Square wave duty cycle
    output reg [7:0]   reg_volume,        // 0x06: Master volume (0x00=mute, 0xFF=full)
    output wire [7:0]  reg_status,        // 0x12: Read-only status

    // Status inputs (for read-only status register)
    input  wire        status_gate_active,
    input  wire        status_osc_running
);

    // ========================================
    // Input Synchronizers (2-stage - saves 4 FFs vs 3-stage)
    // ========================================
    reg [1:0] scl_sync;
    reg [1:0] sda_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 2'b11;
            sda_sync <= 2'b11;
        end else begin
            scl_sync <= {scl_sync[0], scl_in};
            sda_sync <= {sda_sync[0], sda_in};
        end
    end

    wire scl = scl_sync[1];
    wire sda = sda_sync[1];

    // Edge detection for SCL
    wire scl_rising = (scl_sync == 2'b01);   // was low, now high
    wire scl_falling = (scl_sync == 2'b10);  // was high, now low

    // ========================================
    // I2C Protocol State Machine
    // ========================================
    localparam STATE_IDLE       = 4'd0;
    localparam STATE_ADDR       = 4'd1;
    localparam STATE_ADDR_ACK   = 4'd2;
    localparam STATE_REG_ADDR   = 4'd3;
    localparam STATE_REG_ACK    = 4'd4;
    localparam STATE_WRITE_DATA = 4'd5;
    localparam STATE_WRITE_ACK  = 4'd6;
    localparam STATE_READ_DATA  = 4'd7;
    localparam STATE_READ_ACK   = 4'd8;

    reg [3:0] state, next_state;
    reg [3:0] bit_count;
    reg [7:0] shift_reg;
    reg [7:0] reg_addr;
    reg       rw_bit;         // 0=write, 1=read
    reg       sda_out_reg;
    reg       sda_oe_reg;

    assign sda_out = sda_out_reg;
    assign sda_oe = sda_oe_reg;

    // START condition: SDA falling while SCL high
    wire start_cond = (scl_sync[1] == 1'b1) && (sda_sync == 2'b10);

    // STOP condition: SDA rising while SCL high
    wire stop_cond = (scl_sync[1] == 1'b1) && (sda_sync == 2'b01);

    // ========================================
    // Status Register (Read-Only)
    // ========================================
    assign reg_status = {6'b000000, status_osc_running, status_gate_active};

    // ========================================
    // I2C State Machine
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            next_state <= STATE_IDLE;
            bit_count <= 0;
            shift_reg <= 8'h00;
            reg_addr <= 0;
            rw_bit <= 0;
            sda_out_reg <= 1;
            sda_oe_reg <= 0;  // Hi-Z
        end else begin
            // Handle START condition (highest priority)
            if (start_cond) begin
                state <= STATE_ADDR;
                next_state <= STATE_ADDR;
                bit_count <= 0;
                shift_reg <= 0;
                sda_oe_reg <= 0;  // Release SDA
            end

            // Handle STOP condition
            else if (stop_cond) begin
                state <= STATE_IDLE;
                next_state <= STATE_IDLE;
                bit_count <= 0;
                sda_oe_reg <= 0;  // Release SDA
            end

            // Sample data on SCL rising edge
            else if (scl_rising) begin
                case (state)
                    STATE_IDLE: begin
                        // Wait for START condition
                        sda_oe_reg <= 0;
                    end

                    STATE_ADDR: begin
                        // Receive 7-bit address + R/W bit
                        shift_reg <= {shift_reg[6:0], sda};

                        if (bit_count == 7) begin
                            // Complete byte received: shift_reg[6:0] has address, sda is R/W bit
                            if (shift_reg[6:0] == I2C_ADDR) begin
                                rw_bit <= sda;  // R/W bit
                                next_state <= sda ? STATE_READ_DATA : STATE_REG_ADDR;
                                state <= STATE_ADDR_ACK;
                            end else begin
                                state <= STATE_IDLE;  // Address mismatch
                                next_state <= STATE_IDLE;
                            end
                            bit_count <= 0;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                    end

                    STATE_ADDR_ACK: begin
                        // ACK cycle complete, move to next state
                        state <= next_state;
                        if (next_state == STATE_READ_DATA) begin
                            shift_reg <= read_register(reg_addr);
                            bit_count <= 0;
                        end
                    end

                    STATE_REG_ADDR: begin
                        // Receive register address
                        shift_reg <= {shift_reg[6:0], sda};

                        if (bit_count == 7) begin
                            reg_addr <= {shift_reg[6:0], sda};
                            state <= STATE_REG_ACK;
                            bit_count <= 0;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                    end

                    STATE_REG_ACK: begin
                        // ACK cycle complete, move to write data
                        state <= STATE_WRITE_DATA;
                    end

                    STATE_WRITE_DATA: begin
                        // Receive data byte
                        shift_reg <= {shift_reg[6:0], sda};

                        if (bit_count == 7) begin
                            // Complete byte received, write to register
                            write_register(reg_addr, {shift_reg[6:0], sda});
                            reg_addr <= reg_addr + 1;  // Auto-increment
                            state <= STATE_WRITE_ACK;
                            bit_count <= 0;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                    end

                    STATE_WRITE_ACK: begin
                        // ACK cycle complete, ready for next byte
                        state <= STATE_WRITE_DATA;
                    end

                    STATE_READ_DATA: begin
                        // Master is reading data bits
                        if (bit_count == 7) begin
                            state <= STATE_READ_ACK;
                            bit_count <= 0;
                        end else begin
                            bit_count <= bit_count + 1;
                        end
                    end

                    STATE_READ_ACK: begin
                        // Check for ACK from master
                        if (sda == 0) begin
                            // ACK received, load next byte
                            reg_addr <= reg_addr + 1;
                            shift_reg <= read_register(reg_addr + 1);
                            state <= STATE_READ_DATA;
                        end else begin
                            // NACK received, master done reading
                            state <= STATE_IDLE;
                        end
                    end

                    default: begin
                        state <= STATE_IDLE;
                        sda_oe_reg <= 0;
                    end
                endcase
            end

            // Update SDA output on SCL falling edge
            else if (scl_falling) begin
                case (state)
                    STATE_ADDR_ACK, STATE_REG_ACK, STATE_WRITE_ACK: begin
                        // Send ACK (drive SDA low)
                        sda_out_reg <= 0;
                        sda_oe_reg <= 1;
                    end

                    STATE_READ_DATA: begin
                        // Output next data bit (MSB first)
                        if (bit_count == 0) begin
                            // First bit, use loaded register value
                            sda_out_reg <= shift_reg[7];
                            sda_oe_reg <= ~shift_reg[7];  // Drive only for 0
                        end else begin
                            // Subsequent bits, shift out
                            sda_out_reg <= shift_reg[7];
                            sda_oe_reg <= ~shift_reg[7];
                        end
                        shift_reg <= {shift_reg[6:0], 1'b1};
                    end

                    STATE_READ_ACK: begin
                        // Release SDA to read ACK from master
                        sda_oe_reg <= 0;
                    end

                    default: begin
                        // Release SDA by default
                        sda_oe_reg <= 0;
                        sda_out_reg <= 1;
                    end
                endcase
            end
        end
    end

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
                // 0x12 is read-only status register
                default: begin
                    // Invalid/removed address, ignore
                end
            endcase
        end
    endtask

    // ========================================
    // Register Read Function (7 essential registers)
    // ========================================
    function [7:0] read_register;
        input [7:0] addr;
        begin
            case (addr)
                8'h00: read_register = reg_control;
                8'h02: read_register = reg_freq_low;
                8'h03: read_register = reg_freq_mid;
                8'h04: read_register = reg_freq_high;
                8'h05: read_register = reg_duty;
                8'h06: read_register = reg_volume;
                8'h12: read_register = reg_status;  // Read-only status
                default: read_register = 8'hFF;  // Invalid/removed address
            endcase
        end
    endfunction

    // ========================================
    // Register Initialization (7 essential registers)
    // ========================================
    initial begin
        // Initialize essential registers to default values
        // Control: bit 0=OSC_EN, bit 1=SW_GATE, bits 2-4=waveform enables
        reg_control = 8'b00011100;     // Oscillator disabled, all 3 waveforms enabled
        reg_freq_low = 8'h00;
        reg_freq_mid = 8'h00;
        reg_freq_high = 8'h00;
        reg_duty = 8'h80;              // 50% duty cycle
        reg_volume = 8'hFF;            // Full volume by default
    end

endmodule
