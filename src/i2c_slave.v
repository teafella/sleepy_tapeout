/*
 * I2C Slave Interface with Register Bank
 *
 * This module implements a complete I2C slave interface for the synthesizer.
 * It supports:
 * - 7-bit addressing
 * - Standard mode (100 kHz) and Fast mode (400 kHz)
 * - 36 registers (0x00 to 0x23)
 * - Read and write operations
 * - Input synchronizers for SCL and SDA
 *
 * Register Map:
 * 0x00: Control (enable, gate, reset, loop)
 * 0x01: Waveform select
 * 0x02-0x04: Frequency (24-bit, little-endian)
 * 0x05: Duty cycle
 * 0x06: Phase offset
 * 0x07-0x0A: ADSR (attack, decay, sustain, release)
 * 0x0B: Master amplitude
 * 0x0C-0x0F: SVF1/SVF2 cutoff and resonance
 * 0x10-0x11: Filter mode and enable
 * 0x12: Status (read-only)
 * 0x13-0x15: Wavetable index, data, control
 * 0x16-0x19: Modulation routing and depths
 * 0x1A: Bypass control
 * 0x1B-0x20: Mixer gains (6 channels)
 * 0x21: Glide rate
 * 0x22: PWM depth
 * 0x23: Ring modulator config
 *
 * Resource Usage: ~135 cells (3.4% of 1x1 tile)
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

    // Register outputs
    output reg [7:0]   reg_control,
    output reg [7:0]   reg_waveform,
    output reg [7:0]   reg_freq_low,
    output reg [7:0]   reg_freq_mid,
    output reg [7:0]   reg_freq_high,
    output reg [7:0]   reg_duty,
    output reg [7:0]   reg_phase_offset,
    output reg [7:0]   reg_attack,
    output reg [7:0]   reg_decay,
    output reg [7:0]   reg_sustain,
    output reg [7:0]   reg_release,
    output reg [7:0]   reg_amplitude,
    output reg [7:0]   reg_svf1_cutoff,
    output reg [7:0]   reg_svf1_resonance,
    output reg [7:0]   reg_svf2_cutoff,
    output reg [7:0]   reg_svf2_resonance,
    output reg [7:0]   reg_filter_mode,
    output reg [7:0]   reg_filter_enable,
    output wire [7:0]  reg_status,        // Read-only status
    output reg [7:0]   reg_wavetable_idx,
    output reg [7:0]   reg_wavetable_data,
    output reg [7:0]   reg_wavetable_ctrl,
    output reg [7:0]   reg_mod_routing,
    output reg [7:0]   reg_mod_depth_cutoff,
    output reg [7:0]   reg_mod_depth_resonance,
    output reg [7:0]   reg_mod_depth_pitch,
    output reg [7:0]   reg_bypass_ctrl,
    output reg [7:0]   reg_gain_square,
    output reg [7:0]   reg_gain_sawtooth,
    output reg [7:0]   reg_gain_triangle,
    output reg [7:0]   reg_gain_sine,
    output reg [7:0]   reg_gain_noise,
    output reg [7:0]   reg_gain_wavetable,
    output reg [7:0]   reg_glide_rate,
    output reg [7:0]   reg_pwm_depth,
    output reg [7:0]   reg_ring_mod_config,

    // Status inputs (for read-only status register)
    input  wire        status_gate_active,
    input  wire [2:0]  status_adsr_state,
    input  wire        status_osc_running
);

    // ========================================
    // Input Synchronizers
    // ========================================
    // Two-stage synchronizers to prevent metastability
    reg [2:0] scl_sync;
    reg [2:0] sda_sync;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            scl_sync <= 3'b111;
            sda_sync <= 3'b111;
        end else begin
            scl_sync <= {scl_sync[1:0], scl_in};
            sda_sync <= {sda_sync[1:0], sda_in};
        end
    end

    wire scl = scl_sync[2];
    wire sda = sda_sync[2];

    // Edge detection for SCL (scl_sync[2] is older, scl_sync[1] is newer)
    wire scl_rising = (scl_sync[2:1] == 2'b01);   // older=0, newer=1
    wire scl_falling = (scl_sync[2:1] == 2'b10);  // older=1, newer=0

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

    // START condition: SDA falling while SCL high (older=1, newer=0)
    wire start_cond = (scl_sync[2] == 1'b1) && (sda_sync[2:1] == 2'b10);

    // STOP condition: SDA rising while SCL high (older=0, newer=1)
    wire stop_cond = (scl_sync[2] == 1'b1) && (sda_sync[2:1] == 2'b01);

    // ========================================
    // Status Register (Read-Only)
    // ========================================
    assign reg_status = {3'b000, status_osc_running, status_adsr_state, status_gate_active};

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
    // Register Write Task
    // ========================================
    task write_register;
        input [7:0] addr;
        input [7:0] data;
        begin
            case (addr)
                8'h00: reg_control <= data;
                8'h01: reg_waveform <= data;
                8'h02: reg_freq_low <= data;
                8'h03: reg_freq_mid <= data;
                8'h04: reg_freq_high <= data;
                8'h05: reg_duty <= data;
                8'h06: reg_phase_offset <= data;
                8'h07: reg_attack <= data;
                8'h08: reg_decay <= data;
                8'h09: reg_sustain <= data;
                8'h0A: reg_release <= data;
                8'h0B: reg_amplitude <= data;
                8'h0C: reg_svf1_cutoff <= data;
                8'h0D: reg_svf1_resonance <= data;
                8'h0E: reg_svf2_cutoff <= data;
                8'h0F: reg_svf2_resonance <= data;
                8'h10: reg_filter_mode <= data;
                8'h11: reg_filter_enable <= data;
                // 0x12 is read-only status register
                8'h13: reg_wavetable_idx <= data;
                8'h14: reg_wavetable_data <= data;
                8'h15: reg_wavetable_ctrl <= data;
                8'h16: reg_mod_routing <= data;
                8'h17: reg_mod_depth_cutoff <= data;
                8'h18: reg_mod_depth_resonance <= data;
                8'h19: reg_mod_depth_pitch <= data;
                8'h1A: reg_bypass_ctrl <= data;
                8'h1B: reg_gain_square <= data;
                8'h1C: reg_gain_sawtooth <= data;
                8'h1D: reg_gain_triangle <= data;
                8'h1E: reg_gain_sine <= data;
                8'h1F: reg_gain_noise <= data;
                8'h20: reg_gain_wavetable <= data;
                8'h21: reg_glide_rate <= data;
                8'h22: reg_pwm_depth <= data;
                8'h23: reg_ring_mod_config <= data;
                default: begin
                    // Invalid address, ignore
                end
            endcase
        end
    endtask

    // ========================================
    // Register Read Function
    // ========================================
    function [7:0] read_register;
        input [7:0] addr;
        begin
            case (addr)
                8'h00: read_register = reg_control;
                8'h01: read_register = reg_waveform;
                8'h02: read_register = reg_freq_low;
                8'h03: read_register = reg_freq_mid;
                8'h04: read_register = reg_freq_high;
                8'h05: read_register = reg_duty;
                8'h06: read_register = reg_phase_offset;
                8'h07: read_register = reg_attack;
                8'h08: read_register = reg_decay;
                8'h09: read_register = reg_sustain;
                8'h0A: read_register = reg_release;
                8'h0B: read_register = reg_amplitude;
                8'h0C: read_register = reg_svf1_cutoff;
                8'h0D: read_register = reg_svf1_resonance;
                8'h0E: read_register = reg_svf2_cutoff;
                8'h0F: read_register = reg_svf2_resonance;
                8'h10: read_register = reg_filter_mode;
                8'h11: read_register = reg_filter_enable;
                8'h12: read_register = reg_status;  // Read-only
                8'h13: read_register = reg_wavetable_idx;
                8'h14: read_register = 8'h00;  // Write-only
                8'h15: read_register = reg_wavetable_ctrl;
                8'h16: read_register = reg_mod_routing;
                8'h17: read_register = reg_mod_depth_cutoff;
                8'h18: read_register = reg_mod_depth_resonance;
                8'h19: read_register = reg_mod_depth_pitch;
                8'h1A: read_register = reg_bypass_ctrl;
                8'h1B: read_register = reg_gain_square;
                8'h1C: read_register = reg_gain_sawtooth;
                8'h1D: read_register = reg_gain_triangle;
                8'h1E: read_register = reg_gain_sine;
                8'h1F: read_register = reg_gain_noise;
                8'h20: read_register = reg_gain_wavetable;
                8'h21: read_register = reg_glide_rate;
                8'h22: read_register = reg_pwm_depth;
                8'h23: read_register = reg_ring_mod_config;
                default: read_register = 8'hFF;
            endcase
        end
    endfunction

    // ========================================
    // Register Initialization
    // ========================================
    initial begin
        // Initialize all registers to default values
        reg_control = 8'h00;
        reg_waveform = 8'h00;
        reg_freq_low = 8'h00;
        reg_freq_mid = 8'h00;
        reg_freq_high = 8'h00;
        reg_duty = 8'h80;              // 50% duty cycle
        reg_phase_offset = 8'h00;
        reg_attack = 8'h10;
        reg_decay = 8'h20;
        reg_sustain = 8'hC0;
        reg_release = 8'h30;
        reg_amplitude = 8'hFF;         // Full amplitude
        reg_svf1_cutoff = 8'hFF;       // Max cutoff
        reg_svf1_resonance = 8'h00;
        reg_svf2_cutoff = 8'hFF;
        reg_svf2_resonance = 8'h00;
        reg_filter_mode = 8'h00;
        reg_filter_enable = 8'h01;     // Filter enabled
        reg_wavetable_idx = 8'h00;
        reg_wavetable_data = 8'h00;
        reg_wavetable_ctrl = 8'h00;
        reg_mod_routing = 8'h00;
        reg_mod_depth_cutoff = 8'h00;
        reg_mod_depth_resonance = 8'h00;
        reg_mod_depth_pitch = 8'h00;
        reg_bypass_ctrl = 8'h00;
        reg_gain_square = 8'h00;
        reg_gain_sawtooth = 8'h00;
        reg_gain_triangle = 8'h00;
        reg_gain_sine = 8'hFF;         // Sine at full by default
        reg_gain_noise = 8'h00;
        reg_gain_wavetable = 8'h00;
        reg_glide_rate = 8'h00;        // Instant frequency changes
        reg_pwm_depth = 8'h00;         // No PWM modulation
        reg_ring_mod_config = 8'h00;   // Ring mod disabled
    end

endmodule
