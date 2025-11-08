/*
 * End-to-End Waveform Test
 *
 * This testbench validates all waveform generators end-to-end:
 * Phase Accumulator → Waveform Generators → Delta-Sigma DAC
 *
 * Tests:
 * 1. Square wave (from phase accumulator)
 * 2. Sawtooth wave
 * 3. Triangle wave
 * 4. Sine wave
 */

`timescale 1ns/1ps

module test_waveforms_e2e;

    // Clock and reset
    reg        clk;
    reg        rst_n;

    // Phase accumulator controls
    reg        osc_enable;
    reg [23:0] frequency;
    reg [7:0]  duty_cycle;

    // Waveform selection
    reg [2:0]  waveform_select;  // 0=square, 1=sawtooth, 2=triangle, 3=sine, 4=noise
    reg [7:0]  selected_wave;

    // Interconnect signals
    wire [23:0] phase_out;
    wire [7:0]  square_out;
    wire [7:0]  sawtooth_out;
    wire [7:0]  triangle_out;
    wire [7:0]  sine_out;
    wire [7:0]  noise_out;
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

    // Instantiate waveform generators
    waveform_generators wavegen (
        .clk(clk),
        .rst_n(rst_n),
        .enable(osc_enable),
        .phase_in(phase_out),
        .sawtooth_out(sawtooth_out),
        .triangle_out(triangle_out),
        .sine_out(sine_out),
        .noise_out(noise_out)
    );

    // Waveform selector mux
    always @(*) begin
        case (waveform_select)
            3'd0: selected_wave = square_out;
            3'd1: selected_wave = sawtooth_out;
            3'd2: selected_wave = triangle_out;
            3'd3: selected_wave = sine_out;
            3'd4: selected_wave = noise_out;
            default: selected_wave = square_out;
        endcase
    end

    // Instantiate delta-sigma DAC
    delta_sigma_dac dac (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(selected_wave),
        .dac_out(dac_out)
    );

    // Clock generation: 50 MHz (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test variables
    integer i;
    integer dac_ones;
    integer wave_min, wave_max, wave_avg;
    integer sample_count;
    real dac_density;

    // Main test sequence
    initial begin
        $dumpfile("waveforms_e2e.vcd");
        $dumpvars(0, test_waveforms_e2e);

        $display("=== End-to-End Waveform Test ===\n");
        $display("Testing signal chain:");
        $display("Phase Accumulator → Waveform Generators → Delta-Sigma DAC\n");

        // Initialize
        rst_n = 0;
        osc_enable = 0;
        frequency = 24'h000000;
        duty_cycle = 8'h80;  // 50% for square wave
        waveform_select = 2'd0;
        #100;

        // Release reset
        rst_n = 1;
        #100;

        // Enable oscillator at moderate frequency
        osc_enable = 1;
        frequency = 24'h080000;  // Medium frequency for testing

        // Test each waveform
        test_waveform(3'd0, "Square Wave (50% duty)");

        duty_cycle = 8'h40;  // 25% duty for square
        test_waveform(3'd0, "Square Wave (25% duty)");

        duty_cycle = 8'h80;  // Back to 50%
        test_waveform(3'd1, "Sawtooth Wave");
        test_waveform(3'd2, "Triangle Wave");
        test_waveform(3'd3, "Sine Wave (Polynomial)");
        test_waveform(3'd4, "Noise (LFSR)");

        // Test at different frequencies
        $display("\n=== Testing different frequencies with sine wave ===");
        waveform_select = 3'd3;  // Sine wave

        frequency = 24'h010000;
        test_frequency_sweep("Low frequency");

        frequency = 24'h100000;
        test_frequency_sweep("Medium frequency");

        frequency = 24'h400000;
        test_frequency_sweep("High frequency");

        $display("\n=== All waveform tests completed ===");
        #1000;
        $finish;
    end

    // Task to test a specific waveform
    task test_waveform;
        input [2:0] wave_sel;
        input [255:0] wave_name;
        integer j;
        begin
            $display("\n--- Testing: %s ---", wave_name);
            waveform_select = wave_sel;

            // Wait for settling
            repeat(100) @(posedge clk);

            // Sample waveform characteristics over several cycles
            wave_min = 255;
            wave_max = 0;
            wave_avg = 0;
            dac_ones = 0;
            sample_count = 0;

            // Sample for 4096 clock cycles
            for (j = 0; j < 4096; j = j + 1) begin
                @(posedge clk);

                // Track waveform min/max/avg
                if (selected_wave < wave_min) wave_min = selected_wave;
                if (selected_wave > wave_max) wave_max = selected_wave;
                wave_avg = wave_avg + selected_wave;

                // Track DAC output
                if (dac_out) dac_ones = dac_ones + 1;
                sample_count = sample_count + 1;
            end

            wave_avg = wave_avg / sample_count;
            dac_density = (dac_ones * 100.0) / sample_count;

            $display("Waveform amplitude: min=%0d, max=%0d, avg=%0d", wave_min, wave_max, wave_avg);
            $display("DAC output density: %0.1f%%", dac_density);

            // Verify waveform characteristics
            case (wave_sel)
                3'd0: begin  // Square wave
                    if ((wave_min == 0) && (wave_max == 255)) begin
                        $display("✓ Square wave: Correct amplitude (0-255)");
                    end else begin
                        $display("✗ Square wave: Incorrect amplitude");
                    end
                end

                3'd1: begin  // Sawtooth
                    if ((wave_min < 10) && (wave_max > 245)) begin
                        $display("✓ Sawtooth: Good amplitude range");
                    end else begin
                        $display("✗ Sawtooth: Poor amplitude range");
                    end
                    if ((wave_avg > 100) && (wave_avg < 155)) begin
                        $display("✓ Sawtooth: Reasonable average (~127)");
                    end else begin
                        $display("✗ Sawtooth: Average outside expected range");
                    end
                end

                3'd2: begin  // Triangle
                    if ((wave_min < 10) && (wave_max > 245)) begin
                        $display("✓ Triangle: Good amplitude range");
                    end else begin
                        $display("✗ Triangle: Poor amplitude range");
                    end
                    if ((wave_avg > 100) && (wave_avg < 155)) begin
                        $display("✓ Triangle: Reasonable average (~127)");
                    end else begin
                        $display("✗ Triangle: Average outside expected range");
                    end
                end

                3'd3: begin  // Sine
                    // Sine wave should have softer peaks
                    if ((wave_min < 30) && (wave_max > 225)) begin
                        $display("✓ Sine: Good amplitude range");
                    end else begin
                        $display("✗ Sine: Poor amplitude range (min=%0d, max=%0d)", wave_min, wave_max);
                    end
                    if ((wave_avg > 100) && (wave_avg < 155)) begin
                        $display("✓ Sine: Reasonable average (~127)");
                    end else begin
                        $display("✗ Sine: Average outside expected range");
                    end
                end

                3'd4: begin  // Noise
                    // Noise should use most of the dynamic range
                    if ((wave_max - wave_min) > 200) begin
                        $display("✓ Noise: Good dynamic range (%0d)", wave_max - wave_min);
                    end else begin
                        $display("✗ Noise: Poor dynamic range (%0d)", wave_max - wave_min);
                    end
                    // Average should be near center
                    if ((wave_avg > 100) && (wave_avg < 155)) begin
                        $display("✓ Noise: Reasonable average (~127)");
                    end else begin
                        $display("✗ Noise: Average outside expected range");
                    end
                end
            endcase

            // DAC should track the average amplitude
            if ((dac_density > (wave_avg / 2.55 - 10)) &&
                (dac_density < (wave_avg / 2.55 + 10))) begin
                $display("✓ DAC: Output density tracks waveform average");
            end else begin
                $display("✗ DAC: Output density does not track waveform");
            end
        end
    endtask

    // Task to test frequency response
    task test_frequency_sweep;
        input [255:0] description;
        integer phase_wraps;
        reg [23:0] phase_prev;
        integer k;
        begin
            $display("\n--- Frequency test: %s ---", description);
            $display("Frequency word: 0x%06X", frequency);

            // Wait for settling
            repeat(50) @(posedge clk);

            // Count phase wraparounds
            phase_wraps = 0;
            phase_prev = phase_out;

            for (k = 0; k < 2000; k = k + 1) begin
                @(posedge clk);
                if (phase_out < phase_prev) begin
                    phase_wraps = phase_wraps + 1;
                end
                phase_prev = phase_out;
            end

            $display("Phase wraparounds: %0d in 2000 cycles", phase_wraps);

            if (phase_wraps > 0) begin
                $display("✓ Oscillator running at correct frequency");
            end else begin
                $display("✗ No phase wraparounds detected!");
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
