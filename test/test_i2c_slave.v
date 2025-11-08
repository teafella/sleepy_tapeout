/*
 * Testbench for I2C Slave Interface
 *
 * This testbench validates:
 * 1. I2C protocol (START, STOP, ACK, NACK)
 * 2. Address matching
 * 3. Register write operations
 * 4. Register read operations
 * 5. Burst write and read
 * 6. Read-only and write-only registers
 */

`timescale 1ns/1ps

module test_i2c_slave;

    // Clock and reset
    reg        clk;
    reg        rst_n;

    // I2C bus signals
    reg        scl_drive;
    reg        sda_drive;
    wire       scl_in;
    wire       sda_in;
    wire       sda_out;
    wire       sda_oe;

    // I2C open-drain emulation
    assign scl_in = scl_drive;
    assign sda_in = sda_drive & (~sda_oe | sda_out);  // Slave can pull low

    // Status inputs
    reg        status_gate_active;
    reg [2:0]  status_adsr_state;
    reg        status_osc_running;

    // Register outputs
    wire [7:0] reg_control;
    wire [7:0] reg_waveform;
    wire [7:0] reg_freq_low;
    wire [7:0] reg_freq_mid;
    wire [7:0] reg_freq_high;
    wire [7:0] reg_duty;
    wire [7:0] reg_phase_offset;
    wire [7:0] reg_attack;
    wire [7:0] reg_decay;
    wire [7:0] reg_sustain;
    wire [7:0] reg_release;
    wire [7:0] reg_amplitude;
    wire [7:0] reg_svf1_cutoff;
    wire [7:0] reg_svf1_resonance;
    wire [7:0] reg_svf2_cutoff;
    wire [7:0] reg_svf2_resonance;
    wire [7:0] reg_filter_mode;
    wire [7:0] reg_filter_enable;
    wire [7:0] reg_status;
    wire [7:0] reg_wavetable_idx;
    wire [7:0] reg_wavetable_data;
    wire [7:0] reg_wavetable_ctrl;
    wire [7:0] reg_mod_routing;
    wire [7:0] reg_mod_depth_cutoff;
    wire [7:0] reg_mod_depth_resonance;
    wire [7:0] reg_mod_depth_pitch;
    wire [7:0] reg_bypass_ctrl;
    wire [7:0] reg_gain_square;
    wire [7:0] reg_gain_sawtooth;
    wire [7:0] reg_gain_triangle;
    wire [7:0] reg_gain_sine;
    wire [7:0] reg_gain_noise;
    wire [7:0] reg_gain_wavetable;
    wire [7:0] reg_glide_rate;
    wire [7:0] reg_pwm_depth;
    wire [7:0] reg_ring_mod_config;

    // Instantiate DUT
    i2c_slave #(
        .I2C_ADDR(7'h50)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .scl_in(scl_in),
        .sda_in(sda_in),
        .sda_out(sda_out),
        .sda_oe(sda_oe),
        .reg_control(reg_control),
        .reg_waveform(reg_waveform),
        .reg_freq_low(reg_freq_low),
        .reg_freq_mid(reg_freq_mid),
        .reg_freq_high(reg_freq_high),
        .reg_duty(reg_duty),
        .reg_phase_offset(reg_phase_offset),
        .reg_attack(reg_attack),
        .reg_decay(reg_decay),
        .reg_sustain(reg_sustain),
        .reg_release(reg_release),
        .reg_amplitude(reg_amplitude),
        .reg_svf1_cutoff(reg_svf1_cutoff),
        .reg_svf1_resonance(reg_svf1_resonance),
        .reg_svf2_cutoff(reg_svf2_cutoff),
        .reg_svf2_resonance(reg_svf2_resonance),
        .reg_filter_mode(reg_filter_mode),
        .reg_filter_enable(reg_filter_enable),
        .reg_status(reg_status),
        .reg_wavetable_idx(reg_wavetable_idx),
        .reg_wavetable_data(reg_wavetable_data),
        .reg_wavetable_ctrl(reg_wavetable_ctrl),
        .reg_mod_routing(reg_mod_routing),
        .reg_mod_depth_cutoff(reg_mod_depth_cutoff),
        .reg_mod_depth_resonance(reg_mod_depth_resonance),
        .reg_mod_depth_pitch(reg_mod_depth_pitch),
        .reg_bypass_ctrl(reg_bypass_ctrl),
        .reg_gain_square(reg_gain_square),
        .reg_gain_sawtooth(reg_gain_sawtooth),
        .reg_gain_triangle(reg_gain_triangle),
        .reg_gain_sine(reg_gain_sine),
        .reg_gain_noise(reg_gain_noise),
        .reg_gain_wavetable(reg_gain_wavetable),
        .reg_glide_rate(reg_glide_rate),
        .reg_pwm_depth(reg_pwm_depth),
        .reg_ring_mod_config(reg_ring_mod_config),
        .status_gate_active(status_gate_active),
        .status_adsr_state(status_adsr_state),
        .status_osc_running(status_osc_running)
    );

    // Clock generation: 50 MHz (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // I2C timing parameters (100 kHz Standard Mode)
    localparam I2C_PERIOD = 10000;      // 10us = 100kHz
    localparam I2C_HALF = I2C_PERIOD/2; // 5us

    // Test variables
    integer i;
    reg [7:0] read_data;
    reg ack_bit;

    // Main test sequence
    initial begin
        $dumpfile("i2c_slave.vcd");
        $dumpvars(0, test_i2c_slave);

        $display("=== I2C Slave Interface Test ===\n");

        // Initialize
        rst_n = 0;
        scl_drive = 1;
        sda_drive = 1;
        status_gate_active = 0;
        status_adsr_state = 3'b000;
        status_osc_running = 0;
        #200;

        // Release reset
        rst_n = 1;
        #500;

        $display("--- Test 1: Address Match (should ACK) ---");
        i2c_start();
        i2c_write_byte(8'hA0, ack_bit);  // Address 0x50, Write
        if (ack_bit == 0) begin
            $display("✓ PASS: Address matched, ACK received");
        end else begin
            $display("✗ FAIL: No ACK for correct address");
        end
        i2c_stop();
        #1000;

        $display("\n--- Test 2: Address Mismatch (should NACK) ---");
        i2c_start();
        i2c_write_byte(8'h42, ack_bit);  // Wrong address
        if (ack_bit == 1) begin
            $display("✓ PASS: Wrong address ignored (NACK)");
        end else begin
            $display("✗ FAIL: Wrong address was ACKed");
        end
        i2c_stop();
        #1000;

        $display("\n--- Test 3: Write to Control Register (0x00) ---");
        i2c_write_register(8'h00, 8'b00000011);  // Enable=1, Gate=1
        #500;
        if (reg_control == 8'b00000011) begin
            $display("✓ PASS: Control register = 0x%02X", reg_control);
        end else begin
            $display("✗ FAIL: Control register = 0x%02X (expected 0x03)", reg_control);
        end

        $display("\n--- Test 4: Write Frequency (24-bit, 3 registers) ---");
        i2c_write_register(8'h02, 8'h00);  // Freq low
        i2c_write_register(8'h03, 8'h40);  // Freq mid
        i2c_write_register(8'h04, 8'h02);  // Freq high = 0x024000 (440 Hz)
        #500;
        if ({reg_freq_high, reg_freq_mid, reg_freq_low} == 24'h024000) begin
            $display("✓ PASS: Frequency = 0x%06X (440 Hz)", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end else begin
            $display("✗ FAIL: Frequency = 0x%06X (expected 0x024000)", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end

        $display("\n--- Test 5: Burst Write (ADSR registers) ---");
        i2c_start();
        i2c_write_byte(8'hA0, ack_bit);   // Address + Write
        i2c_write_byte(8'h07, ack_bit);   // Reg addr = 0x07 (Attack)
        i2c_write_byte(8'h05, ack_bit);   // Attack = 5
        i2c_write_byte(8'h0A, ack_bit);   // Decay = 10 (auto-increment)
        i2c_write_byte(8'h80, ack_bit);   // Sustain = 128
        i2c_write_byte(8'h14, ack_bit);   // Release = 20
        i2c_stop();
        #500;
        if (reg_attack == 8'h05 && reg_decay == 8'h0A &&
            reg_sustain == 8'h80 && reg_release == 8'h14) begin
            $display("✓ PASS: ADSR = %d/%d/%d/%d", reg_attack, reg_decay, reg_sustain, reg_release);
        end else begin
            $display("✗ FAIL: ADSR = %d/%d/%d/%d (expected 5/10/128/20)",
                     reg_attack, reg_decay, reg_sustain, reg_release);
        end

        $display("\n--- Test 6: Read from Register ---");
        i2c_write_register(8'h0B, 8'hA5);  // Write test pattern to amplitude
        #500;
        i2c_read_register(8'h0B, read_data);
        #500;
        if (read_data == 8'hA5) begin
            $display("✓ PASS: Read amplitude = 0x%02X", read_data);
        end else begin
            $display("✗ FAIL: Read amplitude = 0x%02X (expected 0xA5)", read_data);
        end

        $display("\n--- Test 7: Read Status Register (read-only) ---");
        status_gate_active = 1;
        status_adsr_state = 3'b010;  // Decay
        status_osc_running = 1;
        #500;
        i2c_read_register(8'h12, read_data);
        #500;
        $display("Status register: 0x%02X", read_data);
        if (read_data == 8'b00010101) begin  // [7:5]=0, [4]=1 (osc), [3:1]=010 (decay), [0]=1 (gate)
            $display("✓ PASS: Status reflects input signals");
        end else begin
            $display("✗ FAIL: Status = 0x%02X (expected 0x15)", read_data);
        end

        $display("\n--- Test 8: Burst Read (Frequency registers) ---");
        i2c_start();
        i2c_write_byte(8'hA0, ack_bit);   // Address + Write
        i2c_write_byte(8'h02, ack_bit);   // Set read pointer to 0x02
        i2c_start();                       // Repeated START
        i2c_write_byte(8'hA1, ack_bit);   // Address + Read
        i2c_read_byte(read_data, 1'b0);   // Read with ACK
        $display("Freq[7:0] = 0x%02X", read_data);
        i2c_read_byte(read_data, 1'b0);   // Read with ACK
        $display("Freq[15:8] = 0x%02X", read_data);
        i2c_read_byte(read_data, 1'b1);   // Read with NACK (last byte)
        $display("Freq[23:16] = 0x%02X", read_data);
        i2c_stop();
        if (read_data == 8'h02) begin
            $display("✓ PASS: Burst read successful");
        end else begin
            $display("✗ FAIL: Burst read failed");
        end

        $display("\n--- Test 9: Write to Mixer Gains ---");
        i2c_write_register(8'h1B, 8'h10);  // Square gain
        i2c_write_register(8'h1C, 8'h20);  // Sawtooth gain
        i2c_write_register(8'h1D, 8'h30);  // Triangle gain
        i2c_write_register(8'h1E, 8'h40);  // Sine gain
        i2c_write_register(8'h1F, 8'h50);  // Noise gain
        i2c_write_register(8'h20, 8'h60);  // Wavetable gain
        #500;
        if (reg_gain_square == 8'h10 && reg_gain_sawtooth == 8'h20 &&
            reg_gain_triangle == 8'h30 && reg_gain_sine == 8'h40 &&
            reg_gain_noise == 8'h50 && reg_gain_wavetable == 8'h60) begin
            $display("✓ PASS: All mixer gains set correctly");
        end else begin
            $display("✗ FAIL: Mixer gains incorrect");
        end

        $display("\n--- Test 10: Write to Extended Registers ---");
        i2c_write_register(8'h21, 8'h42);  // Glide rate
        i2c_write_register(8'h22, 8'h33);  // PWM depth
        i2c_write_register(8'h23, 8'h55);  // Ring mod config
        #500;
        if (reg_glide_rate == 8'h42 && reg_pwm_depth == 8'h33 &&
            reg_ring_mod_config == 8'h55) begin
            $display("✓ PASS: Extended registers = 0x%02X/0x%02X/0x%02X",
                     reg_glide_rate, reg_pwm_depth, reg_ring_mod_config);
        end else begin
            $display("✗ FAIL: Extended registers incorrect");
        end

        $display("\n=== All I2C tests completed ===");
        #2000;
        $finish;
    end

    // ========================================
    // I2C Master Tasks
    // ========================================

    // Generate START condition
    task i2c_start;
        begin
            sda_drive = 1;
            scl_drive = 1;
            #I2C_HALF;
            sda_drive = 0;  // SDA falls while SCL high
            #I2C_HALF;
            scl_drive = 0;
            #I2C_HALF;
        end
    endtask

    // Generate STOP condition
    task i2c_stop;
        begin
            sda_drive = 0;
            scl_drive = 0;
            #I2C_HALF;
            scl_drive = 1;
            #I2C_HALF;
            sda_drive = 1;  // SDA rises while SCL high
            #I2C_HALF;
        end
    endtask

    // Write a byte on I2C bus
    task i2c_write_byte;
        input [7:0] data;
        output ack;
        integer j;
        begin
            // Send 8 data bits (MSB first)
            for (j = 7; j >= 0; j = j - 1) begin
                sda_drive = data[j];
                #I2C_HALF;
                scl_drive = 1;
                #I2C_PERIOD;
                scl_drive = 0;
                #I2C_HALF;
            end

            // Read ACK bit
            sda_drive = 1;  // Release SDA
            #I2C_HALF;
            scl_drive = 1;
            #(I2C_HALF/2);
            ack = sda_in;
            #(I2C_HALF/2);
            scl_drive = 0;
            #I2C_HALF;
        end
    endtask

    // Read a byte from I2C bus
    task i2c_read_byte;
        output [7:0] data;
        input ack;
        integer j;
        begin
            sda_drive = 1;  // Release SDA
            data = 8'h00;

            // Read 8 data bits (MSB first)
            for (j = 7; j >= 0; j = j - 1) begin
                #I2C_HALF;
                scl_drive = 1;
                #(I2C_HALF/2);
                data[j] = sda_in;
                #(I2C_HALF/2);
                scl_drive = 0;
                #I2C_HALF;
            end

            // Send ACK/NACK
            sda_drive = ack;
            #I2C_HALF;
            scl_drive = 1;
            #I2C_PERIOD;
            scl_drive = 0;
            #I2C_HALF;
            sda_drive = 1;
        end
    endtask

    // High-level: Write to a register
    task i2c_write_register;
        input [7:0] reg_addr;
        input [7:0] data;
        reg ack1, ack2, ack3;
        begin
            i2c_start();
            i2c_write_byte(8'hA0, ack1);  // Device address + Write
            i2c_write_byte(reg_addr, ack2);
            i2c_write_byte(data, ack3);
            i2c_stop();
        end
    endtask

    // High-level: Read from a register
    task i2c_read_register;
        input [7:0] reg_addr;
        output [7:0] data;
        reg ack1, ack2, ack3;
        begin
            // Set register pointer
            i2c_start();
            i2c_write_byte(8'hA0, ack1);  // Device address + Write
            i2c_write_byte(reg_addr, ack2);

            // Read data
            i2c_start();  // Repeated START
            i2c_write_byte(8'hA1, ack3);  // Device address + Read
            i2c_read_byte(data, 1'b1);     // Read with NACK
            i2c_stop();
        end
    endtask

    // Timeout watchdog
    initial begin
        #50000000;  // 50ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
