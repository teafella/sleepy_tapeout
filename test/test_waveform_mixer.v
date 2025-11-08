/*
 * Testbench for 6-Channel Waveform Mixer
 *
 * Tests:
 * 1. Individual waveform gain control
 * 2. Multiple waveform mixing
 * 3. Saturation behavior
 * 4. Zero gain behavior
 * 5. Full gain behavior
 */

`timescale 1ns/1ps

module test_waveform_mixer;

    // Clock and reset
    reg        clk;
    reg        rst_n;

    // Waveform inputs
    reg [7:0]  square_in;
    reg [7:0]  sawtooth_in;
    reg [7:0]  triangle_in;
    reg [7:0]  sine_in;
    reg [7:0]  noise_in;
    reg [7:0]  wavetable_in;

    // Gain controls
    reg [7:0]  gain_square;
    reg [7:0]  gain_sawtooth;
    reg [7:0]  gain_triangle;
    reg [7:0]  gain_sine;
    reg [7:0]  gain_noise;
    reg [7:0]  gain_wavetable;

    // Output
    wire [7:0] mixed_out;

    // Instantiate DUT
    waveform_mixer dut (
        .clk(clk),
        .rst_n(rst_n),
        .square_in(square_in),
        .sawtooth_in(sawtooth_in),
        .triangle_in(triangle_in),
        .sine_in(sine_in),
        .noise_in(noise_in),
        .wavetable_in(wavetable_in),
        .gain_square(gain_square),
        .gain_sawtooth(gain_sawtooth),
        .gain_triangle(gain_triangle),
        .gain_sine(gain_sine),
        .gain_noise(gain_noise),
        .gain_wavetable(gain_wavetable),
        .mixed_out(mixed_out)
    );

    // Clock generation: 50 MHz
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test stimulus
    initial begin
        $dumpfile("waveform_mixer.vcd");
        $dumpvars(0, test_waveform_mixer);

        $display("=== 6-Channel Waveform Mixer Test ===\n");

        // Initialize
        rst_n = 0;
        square_in = 0;
        sawtooth_in = 0;
        triangle_in = 0;
        sine_in = 0;
        noise_in = 0;
        wavetable_in = 0;
        gain_square = 0;
        gain_sawtooth = 0;
        gain_triangle = 0;
        gain_sine = 0;
        gain_noise = 0;
        gain_wavetable = 0;
        #100;

        // Release reset
        rst_n = 1;
        #50;

        // Test 1: Single waveform at full gain
        $display("--- Test 1: Single Waveform (Square) at Full Gain ---");
        square_in = 8'hFF;
        gain_square = 8'hFF;  // 11 in upper 2 bits = full volume
        #40;  // Wait for output to settle (1 clock cycle + margin)
        // Note: With bit-shift gain, 0xFF at full gain = 0xFF
        if (mixed_out == 8'hFF) begin
            $display("✓ PASS: Square at full gain = 0x%02X", mixed_out);
        end else begin
            $display("✗ FAIL: Square at full gain = 0x%02X (expected 0xFF)", mixed_out);
        end

        // Test 2: Half gain
        $display("\n--- Test 2: Square at Half Gain ---");
        square_in = 8'hFF;
        gain_square = 8'h80;  // 10 in upper 2 bits = 1/2 volume (>> 1)
        gain_sawtooth = 0;
        gain_triangle = 0;
        gain_sine = 0;
        gain_noise = 0;
        gain_wavetable = 0;
        #40;
        if (mixed_out >= 8'h7F && mixed_out <= 8'h81) begin
            $display("✓ PASS: Square at half gain = 0x%02X (expected ~0x80)", mixed_out);
        end else begin
            $display("✗ FAIL: Square at half gain = 0x%02X (expected ~0x80)", mixed_out);
        end

        // Test 3: Zero gain (silence)
        $display("\n--- Test 3: Zero Gain (All Waveforms) ---");
        square_in = 8'hFF;
        sawtooth_in = 8'hFF;
        triangle_in = 8'hFF;
        sine_in = 8'hFF;
        noise_in = 8'hFF;
        wavetable_in = 8'hFF;
        gain_square = 0;
        gain_sawtooth = 0;
        gain_triangle = 0;
        gain_sine = 0;
        gain_noise = 0;
        gain_wavetable = 0;
        #40;
        if (mixed_out == 8'h00) begin
            $display("✓ PASS: All gains zero = 0x%02X", mixed_out);
        end else begin
            $display("✗ FAIL: All gains zero = 0x%02X (expected 0x00)", mixed_out);
        end

        // Test 4: Mix two waveforms
        $display("\n--- Test 4: Mix Two Waveforms (Square + Sine) ---");
        square_in = 8'h80;     // 128
        sine_in = 8'h80;       // 128
        gain_square = 8'h80;   // 50% gain
        gain_sine = 8'h80;     // 50% gain
        gain_sawtooth = 0;
        gain_triangle = 0;
        gain_noise = 0;
        gain_wavetable = 0;
        #40;
        // Expected: (128*128 + 128*128) / 256 = (16384 + 16384) / 256 = 128
        if (mixed_out >= 8'h7E && mixed_out <= 8'h82) begin
            $display("✓ PASS: Two waveforms mixed = 0x%02X (expected ~0x80)", mixed_out);
        end else begin
            $display("✗ FAIL: Two waveforms mixed = 0x%02X (expected ~0x80)", mixed_out);
        end

        // Test 5: Saturation test
        $display("\n--- Test 5: Saturation (All Waveforms at Full) ---");
        square_in = 8'hFF;
        sawtooth_in = 8'hFF;
        triangle_in = 8'hFF;
        sine_in = 8'hFF;
        noise_in = 8'hFF;
        wavetable_in = 8'hFF;
        gain_square = 8'hFF;
        gain_sawtooth = 8'hFF;
        gain_triangle = 8'hFF;
        gain_sine = 8'hFF;
        gain_noise = 8'hFF;
        gain_wavetable = 8'hFF;
        #40;
        // Expected: Saturation to 0xFF (6 × 255 × 255 / 256 = 1530 → saturate)
        if (mixed_out == 8'hFF) begin
            $display("✓ PASS: Saturation works = 0x%02X", mixed_out);
        end else begin
            $display("✗ FAIL: Saturation = 0x%02X (expected 0xFF)", mixed_out);
        end

        // Test 6: Equal mix of all 6 waveforms
        $display("\n--- Test 6: Equal Mix of All 6 Waveforms ---");
        square_in = 8'hC0;      // 192
        sawtooth_in = 8'hC0;
        triangle_in = 8'hC0;
        sine_in = 8'hC0;
        noise_in = 8'hC0;
        wavetable_in = 8'hC0;
        gain_square = 8'h2A;    // ~16.7% each (42/256 ≈ 1/6)
        gain_sawtooth = 8'h2A;
        gain_triangle = 8'h2A;
        gain_sine = 8'h2A;
        gain_noise = 8'h2A;
        gain_wavetable = 8'h2A;
        #40;
        // Expected: 6 × (192 × 42) / 256 ≈ 192
        if (mixed_out >= 8'hB0 && mixed_out <= 8'hD0) begin
            $display("✓ PASS: 6-way equal mix = 0x%02X (expected ~0xC0)", mixed_out);
        end else begin
            $display("✗ FAIL: 6-way equal mix = 0x%02X (expected ~0xC0)", mixed_out);
        end

        // Test 7: One waveform at quarter gain
        $display("\n--- Test 7: Sine at Quarter Gain ---");
        sine_in = 8'hFF;
        gain_sine = 8'h40;      // 64/256 = 25%
        gain_square = 0;
        gain_sawtooth = 0;
        gain_triangle = 0;
        gain_noise = 0;
        gain_wavetable = 0;
        #40;
        // Expected: 255 × 64 / 256 = 63.75 ≈ 0x40
        if (mixed_out >= 8'h3E && mixed_out <= 8'h42) begin
            $display("✓ PASS: Quarter gain = 0x%02X (expected ~0x40)", mixed_out);
        end else begin
            $display("✗ FAIL: Quarter gain = 0x%02X (expected ~0x40)", mixed_out);
        end

        // Test 8: Test with different waveform values
        $display("\n--- Test 8: Different Waveform Values ---");
        square_in = 8'h10;      // 16
        sawtooth_in = 8'h20;    // 32
        triangle_in = 8'h30;    // 48
        sine_in = 8'h40;        // 64
        noise_in = 8'h50;       // 80
        wavetable_in = 8'h60;   // 96
        gain_square = 8'hFF;
        gain_sawtooth = 8'hFF;
        gain_triangle = 8'hFF;
        gain_sine = 8'hFF;
        gain_noise = 8'hFF;
        gain_wavetable = 8'hFF;
        #40;
        // Expected: (16+32+48+64+80+96) = 336 / 256 = 1.3125 → 0x01 (after scaling)
        // Actually: each is multiplied by 255, then divided by 256
        // = (16*255 + 32*255 + 48*255 + 64*255 + 80*255 + 96*255) / 256
        // = (4080 + 8160 + 12240 + 16320 + 20400 + 24480) / 256
        // = 85680 / 256 = 334.6875 → saturates to 0xFF
        if (mixed_out == 8'hFF) begin
            $display("✓ PASS: Sum of varied inputs = 0x%02X", mixed_out);
        end else begin
            $display("✗ FAIL: Sum of varied inputs = 0x%02X", mixed_out);
        end

        // Test 9: Reset behavior
        $display("\n--- Test 9: Reset Behavior ---");
        rst_n = 0;
        #40;
        if (mixed_out == 8'h00) begin
            $display("✓ PASS: Reset clears output = 0x%02X", mixed_out);
        end else begin
            $display("✗ FAIL: Reset output = 0x%02X (expected 0x00)", mixed_out);
        end

        $display("\n=== All Waveform Mixer tests completed ===");
        #100;
        $finish;
    end

    // Timeout watchdog
    initial begin
        #100000;  // 100us timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
