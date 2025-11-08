/*
 * Detailed testbench for Delta-Sigma DAC
 *
 * This testbench provides detailed analysis of the output pattern
 * to verify proper pulse density modulation.
 */

`timescale 1ns/1ps

module test_delta_sigma_detailed;

    // Testbench signals
    reg        clk;
    reg        rst_n;
    reg  [7:0] data_in;
    wire       dac_out;

    // Instantiate the DUT
    delta_sigma_dac dut (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(data_in),
        .dac_out(dac_out)
    );

    // Clock generation: 50 MHz (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Test sequence with detailed output pattern analysis
    integer i;
    integer ones_count;
    integer sample_window;
    reg [255:0] pattern;  // Store output pattern for visualization

    initial begin
        $dumpfile("delta_sigma_detailed.vcd");
        $dumpvars(0, test_delta_sigma_detailed);

        // Initialize
        rst_n = 0;
        data_in = 8'h00;
        #100;

        // Release reset
        rst_n = 1;
        #100;

        $display("=== Delta-Sigma DAC Detailed Test ===\n");

        // Test different input values and show patterns
        test_input_value(8'h00, "0x00 (0/255 = 0%%)");
        test_input_value(8'h40, "0x40 (64/255 = 25%%)");
        test_input_value(8'h80, "0x80 (128/255 = 50%%)");
        test_input_value(8'hC0, "0xC0 (192/255 = 75%%)");
        test_input_value(8'hFF, "0xFF (255/255 = 100%%)");

        // Additional test points
        test_input_value(8'h20, "0x20 (32/255 = 12.5%%)");
        test_input_value(8'hE0, "0xE0 (224/255 = 87.5%%)");
        test_input_value(8'h10, "0x10 (16/255 = 6.25%%)");

        $display("\n=== All tests completed ===");
        #1000;
        $finish;
    end

    // Task to test a specific input value
    task test_input_value;
        input [7:0] test_value;
        input [255:0] description;
        integer j;
        begin
            $display("\n--- Test: %s ---", description);
            data_in = test_value;

            // Wait for settling
            repeat(10) @(posedge clk);

            // Collect pattern over 256 samples for detailed analysis
            ones_count = 0;
            for (j = 0; j < 256; j = j + 1) begin
                @(posedge clk);
                pattern[j] = dac_out;
                if (dac_out) ones_count = ones_count + 1;
            end

            // Show first 64 bits of pattern
            $write("Pattern (first 64 bits): ");
            for (j = 0; j < 64; j = j + 1) begin
                $write("%0d", pattern[j]);
                if ((j + 1) % 8 == 0) $write(" ");
            end
            $write("\n");

            // Calculate statistics
            $display("Output density: %0d/256 = %0d%%", ones_count, (ones_count * 100) / 256);
            $display("Expected: ~%0d%%", (test_value * 100) / 256);

            // Check if within reasonable tolerance (±5%)
            // Special case for 0 - allow 0-5 ones
            if (test_value == 8'h00) begin
                if (ones_count <= 5) begin
                    $display("PASS: Zero input produces minimal output");
                end else begin
                    $display("FAIL: Zero input produced %0d ones (expected ≤5)", ones_count);
                end
            end else if (ones_count >= ((test_value * 256 / 255) - 13) &&
                         ones_count <= ((test_value * 256 / 255) + 13)) begin
                $display("PASS: Within ±5%% tolerance");
            end else begin
                $display("FAIL: Outside ±5%% tolerance");
            end
        end
    endtask

    // Timeout watchdog
    initial begin
        #10000000;  // 10ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
