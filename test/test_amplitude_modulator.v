/*
 * Testbench for Amplitude Modulator
 *
 * Tests:
 * 1. Full envelope and amplitude (both 0xFF)
 * 2. Half envelope
 * 3. Zero envelope (silence)
 * 4. Half master amplitude
 * 5. Combined envelope and amplitude scaling
 * 6. Edge cases
 */

`timescale 1ns/1ps

module test_amplitude_modulator;

    // Clock and reset
    reg        clk;
    reg        rst_n;

    // Inputs
    reg [7:0]  waveform_in;
    reg [7:0]  envelope_value;
    reg [7:0]  master_amplitude;

    // Output
    wire [7:0] amplitude_out;

    // Instantiate DUT
    amplitude_modulator dut (
        .clk(clk),
        .rst_n(rst_n),
        .waveform_in(waveform_in),
        .envelope_value(envelope_value),
        .master_amplitude(master_amplitude),
        .amplitude_out(amplitude_out)
    );

    // Clock generation: 50 MHz
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test stimulus
    initial begin
        $dumpfile("amplitude_modulator.vcd");
        $dumpvars(0, test_amplitude_modulator);

        $display("=== Amplitude Modulator Test ===\n");

        // Initialize
        rst_n = 0;
        waveform_in = 0;
        envelope_value = 0;
        master_amplitude = 0;
        #100;

        // Release reset
        rst_n = 1;
        #50;

        // Test 1: Full amplitude (all max)
        $display("--- Test 1: Full Amplitude (all 0xFF) ---");
        waveform_in = 8'hFF;
        envelope_value = 8'hFF;
        master_amplitude = 8'hFF;
        #40;
        // Expected: (255×255)/256 = 254, then (254×255)/256 = 253
        if (amplitude_out >= 8'hFC && amplitude_out <= 8'hFF) begin
            $display("✓ PASS: Full amplitude = 0x%02X (expected ~0xFE)", amplitude_out);
        end else begin
            $display("✗ FAIL: Full amplitude = 0x%02X (expected ~0xFE)", amplitude_out);
        end

        // Test 2: Half envelope
        $display("\n--- Test 2: Half Envelope ---");
        waveform_in = 8'hFF;
        envelope_value = 8'h80;  // 128/256 = 50%
        master_amplitude = 8'hFF;
        #40;
        // Expected: (255×128)/256 = 127, then (127×255)/256 = 126
        if (amplitude_out >= 8'h7C && amplitude_out <= 8'h80) begin
            $display("✓ PASS: Half envelope = 0x%02X (expected ~0x7F)", amplitude_out);
        end else begin
            $display("✗ FAIL: Half envelope = 0x%02X (expected ~0x7F)", amplitude_out);
        end

        // Test 3: Zero envelope (silence)
        $display("\n--- Test 3: Zero Envelope (Silence) ---");
        waveform_in = 8'hFF;
        envelope_value = 8'h00;
        master_amplitude = 8'hFF;
        #40;
        if (amplitude_out == 8'h00) begin
            $display("✓ PASS: Zero envelope = 0x%02X", amplitude_out);
        end else begin
            $display("✗ FAIL: Zero envelope = 0x%02X (expected 0x00)", amplitude_out);
        end

        // Test 4: Half master amplitude
        $display("\n--- Test 4: Half Master Amplitude ---");
        waveform_in = 8'hFF;
        envelope_value = 8'hFF;
        master_amplitude = 8'h80;  // 128/256 = 50%
        #40;
        // Expected: (255×255)/256 = 254, then (254×128)/256 = 127
        if (amplitude_out >= 8'h7C && amplitude_out <= 8'h80) begin
            $display("✓ PASS: Half master amp = 0x%02X (expected ~0x7F)", amplitude_out);
        end else begin
            $display("✗ FAIL: Half master amp = 0x%02X (expected ~0x7F)", amplitude_out);
        end

        // Test 5: Quarter envelope, half amplitude
        $display("\n--- Test 5: Quarter Envelope + Half Amplitude ---");
        waveform_in = 8'hFF;
        envelope_value = 8'h40;  // 64/256 = 25%
        master_amplitude = 8'h80; // 128/256 = 50%
        #40;
        // Expected: (255×64)/256 = 63, then (63×128)/256 = 31
        if (amplitude_out >= 8'h1E && amplitude_out <= 8'h22) begin
            $display("✓ PASS: 1/4 env + 1/2 amp = 0x%02X (expected ~0x20)", amplitude_out);
        end else begin
            $display("✗ FAIL: 1/4 env + 1/2 amp = 0x%02X (expected ~0x20)", amplitude_out);
        end

        // Test 6: Mid-range waveform
        $display("\n--- Test 6: Mid-Range Waveform ---");
        waveform_in = 8'h80;  // 128
        envelope_value = 8'hFF;
        master_amplitude = 8'hFF;
        #40;
        // Expected: (128×255)/256 = 127, then (127×255)/256 = 126
        if (amplitude_out >= 8'h7C && amplitude_out <= 8'h80) begin
            $display("✓ PASS: Mid waveform = 0x%02X (expected ~0x7F)", amplitude_out);
        end else begin
            $display("✗ FAIL: Mid waveform = 0x%02X (expected ~0x7F)", amplitude_out);
        end

        // Test 7: Low waveform value
        $display("\n--- Test 7: Low Waveform Value ---");
        waveform_in = 8'h10;  // 16
        envelope_value = 8'hFF;
        master_amplitude = 8'hFF;
        #40;
        // Expected: (16×255)/256 = 15, then (15×255)/256 = 14
        if (amplitude_out >= 8'h0D && amplitude_out <= 8'h11) begin
            $display("✓ PASS: Low waveform = 0x%02X (expected ~0x0F)", amplitude_out);
        end else begin
            $display("✗ FAIL: Low waveform = 0x%02X (expected ~0x0F)", amplitude_out);
        end

        // Test 8: Zero waveform
        $display("\n--- Test 8: Zero Waveform ---");
        waveform_in = 8'h00;
        envelope_value = 8'hFF;
        master_amplitude = 8'hFF;
        #40;
        if (amplitude_out == 8'h00) begin
            $display("✓ PASS: Zero waveform = 0x%02X", amplitude_out);
        end else begin
            $display("✗ FAIL: Zero waveform = 0x%02X (expected 0x00)", amplitude_out);
        end

        // Test 9: Zero master amplitude
        $display("\n--- Test 9: Zero Master Amplitude ---");
        waveform_in = 8'hFF;
        envelope_value = 8'hFF;
        master_amplitude = 8'h00;
        #40;
        if (amplitude_out == 8'h00) begin
            $display("✓ PASS: Zero master amp = 0x%02X", amplitude_out);
        end else begin
            $display("✗ FAIL: Zero master amp = 0x%02X (expected 0x00)", amplitude_out);
        end

        // Test 10: Reset behavior
        $display("\n--- Test 10: Reset Behavior ---");
        waveform_in = 8'hFF;
        envelope_value = 8'hFF;
        master_amplitude = 8'hFF;
        rst_n = 0;
        #40;
        if (amplitude_out == 8'h00) begin
            $display("✓ PASS: Reset clears output = 0x%02X", amplitude_out);
        end else begin
            $display("✗ FAIL: Reset output = 0x%02X (expected 0x00)", amplitude_out);
        end

        $display("\n=== All Amplitude Modulator tests completed ===");
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
