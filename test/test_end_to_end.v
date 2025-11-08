/*
 * End-to-End Test: Phase Accumulator → Delta-Sigma DAC
 *
 * This testbench validates the complete signal chain:
 * 1. Phase accumulator generates square wave PWM
 * 2. Square wave is fed to delta-sigma DAC
 * 3. DAC converts 8-bit PWM to 1-bit modulated output
 *
 * This tests the real-world usage of both modules together.
 */

`timescale 1ns/1ps

module test_end_to_end;

    // Clock and reset
    reg        clk;
    reg        rst_n;

    // Phase accumulator controls
    reg        osc_enable;
    reg [23:0] frequency;
    reg [7:0]  duty_cycle;

    // Interconnect signals
    wire [23:0] phase_out;
    wire [7:0]  square_out;
    wire        dac_out;

    // Instantiate phase accumulator
    phase_accumulator phase_acc (
        .clk(clk),
        .rst_n(rst_n),
        .enable(osc_enable),
        .frequency(frequency),
        .duty_cycle(duty_cycle),
        .phase_out(phase_out),
        .square_out(square_out)
    );

    // Instantiate delta-sigma DAC
    delta_sigma_dac dac (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(square_out),
        .dac_out(dac_out)
    );

    // Clock generation: 50 MHz (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test variables
    integer i;
    integer dac_ones_count;
    integer pwm_ones_count;
    integer total_samples;
    real dac_density;
    real pwm_density;
    real density_error;

    // Main test sequence
    initial begin
        $dumpfile("end_to_end.vcd");
        $dumpvars(0, test_end_to_end);

        $display("=== End-to-End Test: Phase Accumulator → Delta-Sigma DAC ===\n");

        // Initialize
        rst_n = 0;
        osc_enable = 0;
        frequency = 24'h000000;
        duty_cycle = 8'h00;
        #100;

        // Release reset
        rst_n = 1;
        #100;

        $display("Testing complete signal chain:");
        $display("Phase Accumulator (PWM) → Delta-Sigma DAC (1-bit output)\n");

        // Enable oscillator
        osc_enable = 1;
        frequency = 24'h100000;  // Moderate frequency for testing

        // Test different duty cycles end-to-end
        test_e2e_duty_cycle(8'h00, 0, "0% duty cycle");
        test_e2e_duty_cycle(8'h20, 12, "12.5% duty cycle");
        test_e2e_duty_cycle(8'h40, 25, "25% duty cycle");
        test_e2e_duty_cycle(8'h80, 50, "50% duty cycle");
        test_e2e_duty_cycle(8'hC0, 75, "75% duty cycle");
        test_e2e_duty_cycle(8'hE0, 87, "87.5% duty cycle");
        test_e2e_duty_cycle(8'hFF, 100, "~100% duty cycle");

        // Test different frequencies at 50% duty cycle
        $display("\n=== Testing different frequencies at 50%% duty ===");
        duty_cycle = 8'h80;

        test_e2e_frequency(24'h010000, "Low frequency");
        test_e2e_frequency(24'h100000, "Medium frequency");
        test_e2e_frequency(24'h800000, "High frequency");

        $display("\n=== All end-to-end tests completed ===");
        #1000;
        $finish;
    end

    // Task to test end-to-end duty cycle conversion
    task test_e2e_duty_cycle;
        input [7:0] duty;
        input integer expected_percent;
        input [255:0] description;
        begin
            $display("\n--- E2E Test: %s ---", description);
            duty_cycle = duty;

            // Wait for settling (both phase acc and DAC)
            repeat(50) @(posedge clk);

            // Measure over a good sample period
            dac_ones_count = 0;
            pwm_ones_count = 0;
            total_samples = 0;

            for (i = 0; i < 2048; i = i + 1) begin
                @(posedge clk);
                if (dac_out) dac_ones_count = dac_ones_count + 1;
                if (square_out == 8'hFF) pwm_ones_count = pwm_ones_count + 1;
                total_samples = total_samples + 1;
            end

            // Calculate densities
            pwm_density = (pwm_ones_count * 100.0) / total_samples;
            dac_density = (dac_ones_count * 100.0) / total_samples;
            density_error = dac_density - pwm_density;

            $display("Duty cycle setting: 0x%02X (%0d/256)", duty, duty);
            $display("PWM output density: %0.1f%%", pwm_density);
            $display("DAC output density: %0.1f%%", dac_density);
            $display("Density error: %0.1f%%", density_error);
            $display("Expected density: ~%0d%%", expected_percent);

            // Check PWM matches expected
            if ((pwm_density >= (expected_percent - 5)) &&
                (pwm_density <= (expected_percent + 5))) begin
                $display("✓ PWM: PASS (within ±5%%)");
            end else begin
                $display("✗ PWM: FAIL (outside ±5%%)");
            end

            // Check DAC tracks PWM (should be within ±10% due to delta-sigma noise shaping)
            if ((density_error >= -10.0) && (density_error <= 10.0)) begin
                $display("✓ DAC: PASS (tracks PWM within ±10%%)");
            end else begin
                $display("✗ DAC: FAIL (does not track PWM)");
            end
        end
    endtask

    // Task to test different frequencies
    task test_e2e_frequency;
        input [23:0] freq_word;
        input [255:0] description;
        integer phase_wraps;
        reg [23:0] phase_prev;
        begin
            $display("\n--- E2E Frequency Test: %s ---", description);
            $display("Frequency word: 0x%06X", freq_word);
            frequency = freq_word;

            // Wait for settling
            repeat(50) @(posedge clk);

            // Count phase wraparounds and measure output
            phase_wraps = 0;
            phase_prev = phase_out;
            dac_ones_count = 0;
            pwm_ones_count = 0;
            total_samples = 0;

            for (i = 0; i < 5000; i = i + 1) begin
                @(posedge clk);

                // Detect phase wrap
                if (phase_out < phase_prev) begin
                    phase_wraps = phase_wraps + 1;
                end
                phase_prev = phase_out;

                // Sample outputs
                if (dac_out) dac_ones_count = dac_ones_count + 1;
                if (square_out == 8'hFF) pwm_ones_count = pwm_ones_count + 1;
                total_samples = total_samples + 1;
            end

            pwm_density = (pwm_ones_count * 100.0) / total_samples;
            dac_density = (dac_ones_count * 100.0) / total_samples;

            $display("Phase wraparounds: %0d in %0d samples", phase_wraps, total_samples);
            $display("PWM density: %0.1f%% (should be ~50%%)", pwm_density);
            $display("DAC density: %0.1f%%", dac_density);

            if (phase_wraps > 0) begin
                $display("✓ Frequency: PASS (phase is incrementing and wrapping)");
            end else begin
                $display("✗ Frequency: FAIL (no phase wraps detected)");
            end

            if ((pwm_density >= 45.0) && (pwm_density <= 55.0)) begin
                $display("✓ PWM: PASS (50%% duty cycle maintained)");
            end else begin
                $display("✗ PWM: FAIL (duty cycle incorrect)");
            end
        end
    endtask

    // Timeout watchdog
    initial begin
        #100000000;  // 100ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
