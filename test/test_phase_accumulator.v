/*
 * Testbench for Phase Accumulator and Square Wave PWM
 *
 * This testbench verifies:
 * 1. Phase accumulator increments correctly
 * 2. Frequency output matches the frequency word
 * 3. PWM duty cycle is accurate
 */

`timescale 1ns/1ps

module test_phase_accumulator;

    // Testbench signals
    reg        clk;
    reg        rst_n;
    reg        enable;
    reg [23:0] frequency;
    reg [7:0]  duty_cycle;
    wire [23:0] phase_out;
    wire [7:0]  square_out;

    // Instantiate the DUT
    phase_accumulator dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .frequency(frequency),
        .duty_cycle(duty_cycle),
        .phase_out(phase_out),
        .square_out(square_out)
    );

    // Clock generation: 50 MHz (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test variables
    integer i;
    integer ones_count;
    integer cycles_count;
    reg [23:0] phase_prev;
    integer edge_count;
    reg square_prev;
    real measured_freq;
    real expected_freq;
    real freq_error;

    // Main test sequence
    initial begin
        $dumpfile("phase_accumulator.vcd");
        $dumpvars(0, test_phase_accumulator);

        $display("=== Phase Accumulator & PWM Test ===\n");

        // Initialize
        rst_n = 0;
        enable = 0;
        frequency = 24'h000000;
        duty_cycle = 8'h80;  // 50% default
        #100;

        // Release reset
        rst_n = 1;
        #100;

        // Test 1: Phase accumulator disabled (should not increment)
        $display("--- Test 1: Enable = 0 (phase should not increment) ---");
        enable = 0;
        frequency = 24'h100000;  // Non-zero frequency
        phase_prev = phase_out;
        repeat(100) @(posedge clk);
        if (phase_out == phase_prev) begin
            $display("PASS: Phase did not increment when disabled");
        end else begin
            $display("FAIL: Phase incremented when disabled!");
        end

        // Test 2: Basic phase accumulation
        $display("\n--- Test 2: Basic phase accumulation ---");
        enable = 1;
        frequency = 24'h000100;  // Small increment
        @(posedge clk);
        phase_prev = phase_out;
        @(posedge clk);
        if (phase_out == phase_prev + frequency) begin
            $display("PASS: Phase increments by frequency word (0x%06X)", frequency);
        end else begin
            $display("FAIL: Expected 0x%06X, got 0x%06X", phase_prev + frequency, phase_out);
        end

        // Test 3: Phase wraparound
        $display("\n--- Test 3: Phase wraparound at 2^24 ---");
        frequency = 24'hFFFFFF;  // Large frequency word
        // Wait for phase to wrap around
        phase_prev = 24'h000000;
        for (i = 0; i < 100; i = i + 1) begin
            @(posedge clk);
            if (phase_out < phase_prev) begin
                $display("PASS: Phase wrapped around (0x%06X -> 0x%06X)", phase_prev, phase_out);
                i = 100;  // Exit loop
            end
            phase_prev = phase_out;
        end
        if (phase_out >= phase_prev && i != 101) begin
            $display("FAIL: Phase did not wrap in 100 cycles");
        end

        // Test 4: Frequency accuracy test at 440 Hz
        test_frequency(24'h024000, 440.0, "440 Hz (A4 note)");

        // Test 5: Frequency accuracy test at 1 kHz
        test_frequency(24'h051EB8, 1000.0, "1 kHz");

        // Test 6: PWM duty cycle tests
        frequency = 24'h100000;  // Moderate frequency for stable PWM

        test_duty_cycle(8'h00, 0, "0% duty cycle");
        test_duty_cycle(8'h40, 25, "25% duty cycle");
        test_duty_cycle(8'h80, 50, "50% duty cycle");
        test_duty_cycle(8'hC0, 75, "75% duty cycle");
        test_duty_cycle(8'hFF, 100, "~100% duty cycle");

        $display("\n=== All tests completed ===");
        #1000;
        $finish;
    end

    // Task to test frequency accuracy
    task test_frequency;
        input [23:0] freq_word;
        input real expected_hz;
        input [255:0] description;
        integer clock_cycles;
        integer phase_wraps;
        reg [23:0] phase_prev_local;
        real measured_hz;
        real error_pct;
        begin
            $display("\n--- Test Frequency: %s ---", description);
            $display("Frequency word: 0x%06X", freq_word);

            enable = 1;
            frequency = freq_word;
            duty_cycle = 8'h80;  // 50% duty cycle

            // Wait for stabilization
            repeat(10) @(posedge clk);

            // Method: Count clock cycles for a fixed number of phase wraparounds
            // Phase wraps = output frequency cycles
            // Frequency = (wraps * clock_freq) / clock_cycles

            phase_wraps = 0;
            clock_cycles = 0;
            phase_prev_local = phase_out;

            // Count enough cycles for good accuracy
            // Higher frequencies need more samples for precision
            // Target: measure for at least ~5000 clock cycles or 100 wraps
            while ((phase_wraps < 100) && (clock_cycles < 5000) && (clock_cycles < 10000000)) begin
                @(posedge clk);
                clock_cycles = clock_cycles + 1;

                // Detect phase wraparound
                if (phase_out < phase_prev_local) begin
                    phase_wraps = phase_wraps + 1;
                end
                phase_prev_local = phase_out;
            end

            // Check for timeout or no wraps
            if (clock_cycles >= 10000000) begin
                $display("WARNING: Timeout waiting for phase wraps");
            end
            if (phase_wraps == 0) begin
                $display("ERROR: No phase wraparounds detected!");
                phase_wraps = 1;  // Prevent division by zero
            end

            // Calculate measured frequency
            // f = (cycles_counted * f_clk) / clocks_elapsed
            // f_clk = 50 MHz
            measured_hz = (phase_wraps * 50000000.0) / clock_cycles;
            expected_freq = (freq_word * 50000000.0) / 16777216.0;
            freq_error = ((measured_hz - expected_freq) / expected_freq) * 100.0;

            $display("Phase wraparounds: %0d", phase_wraps);
            $display("Clock cycles: %0d", clock_cycles);
            $display("Expected frequency: %0.2f Hz", expected_freq);
            $display("Measured frequency: %0.2f Hz", measured_hz);
            $display("Error: %0.3f%%", freq_error);

            if (freq_error > -1.0 && freq_error < 1.0) begin
                $display("PASS: Within ±1%% tolerance");
            end else begin
                $display("FAIL: Outside ±1%% tolerance");
            end
        end
    endtask

    // Task to test PWM duty cycle
    task test_duty_cycle;
        input [7:0] duty;
        input integer expected_percent;
        input [255:0] description;
        integer samples;
        begin
            $display("\n--- Test PWM: %s ---", description);
            duty_cycle = duty;

            // Wait for settling
            repeat(10) @(posedge clk);

            // Count high samples over 256 phase cycles
            // We need to wait for phase to wrap around once
            ones_count = 0;
            samples = 0;

            // Sample for a good number of cycles
            for (i = 0; i < 1024; i = i + 1) begin
                @(posedge clk);
                if (square_out == 8'hFF) ones_count = ones_count + 1;
                samples = samples + 1;
            end

            $display("Duty cycle register: 0x%02X (%0d/256)", duty, duty);
            $display("Output density: %0d/%0d = %0d%%", ones_count, samples, (ones_count * 100) / samples);
            $display("Expected: ~%0d%%", expected_percent);

            // Check within ±5% tolerance
            if (((ones_count * 100) / samples) >= (expected_percent - 5) &&
                ((ones_count * 100) / samples) <= (expected_percent + 5)) begin
                $display("PASS: Within ±5%% tolerance");
            end else begin
                $display("FAIL: Outside ±5%% tolerance");
            end
        end
    endtask

    // Timeout watchdog
    initial begin
        #50000000;  // 50ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
