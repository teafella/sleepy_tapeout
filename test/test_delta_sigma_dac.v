/*
 * Testbench for Delta-Sigma DAC
 *
 * This testbench verifies the basic operation of the delta-sigma DAC
 * by applying different input levels and observing the output density.
 */

`timescale 1ns/1ps

module test_delta_sigma_dac;

    // Testbench signals
    reg        clk;
    reg        rst_n;
    reg  [7:0] data_in;
    wire       dac_out;

    // Instantiate the DUT (Device Under Test)
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

    // Test sequence
    integer i;
    integer ones_count;
    initial begin
        $dumpfile("delta_sigma_dac.vcd");
        $dumpvars(0, test_delta_sigma_dac);

        // Initialize
        rst_n = 0;
        data_in = 8'h00;
        #100;

        // Release reset
        rst_n = 1;
        #100;

        // Test 1: Zero input (should produce ~0% high)
        $display("Test 1: Zero input");
        data_in = 8'h00;
        ones_count = 0;
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);
            if (dac_out) ones_count = ones_count + 1;
        end
        $display("  Input: 0x00, Output density: %0d%% (expected ~0%%)", (ones_count * 100) / 1000);

        // Test 2: Mid-level input (should produce ~50% high)
        $display("Test 2: Mid-level input");
        data_in = 8'h80;  // 128 = 50%
        ones_count = 0;
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);
            if (dac_out) ones_count = ones_count + 1;
        end
        $display("  Input: 0x80, Output density: %0d%% (expected ~50%%)", (ones_count * 100) / 1000);

        // Test 3: Full-scale input (should produce ~100% high)
        $display("Test 3: Full-scale input");
        data_in = 8'hFF;  // 255 = 100%
        ones_count = 0;
        @(posedge clk);  // Skip first cycle to allow accumulator to settle
        for (i = 0; i < 10000; i = i + 1) begin
            @(posedge clk);
            if (dac_out) ones_count = ones_count + 1;
        end
        $display("  Input: 0xFF, Output density: %0d%% (expected ~100%%)", (ones_count * 100) / 10000);

        // Test 4: Quarter-level input (should produce ~25% high)
        $display("Test 4: Quarter-level input");
        data_in = 8'h40;  // 64 = 25%
        ones_count = 0;
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);
            if (dac_out) ones_count = ones_count + 1;
        end
        $display("  Input: 0x40, Output density: %0d%% (expected ~25%%)", (ones_count * 100) / 1000);

        // Test 5: Three-quarter-level input (should produce ~75% high)
        $display("Test 5: Three-quarter-level input");
        data_in = 8'hC0;  // 192 = 75%
        ones_count = 0;
        for (i = 0; i < 1000; i = i + 1) begin
            @(posedge clk);
            if (dac_out) ones_count = ones_count + 1;
        end
        $display("  Input: 0xC0, Output density: %0d%% (expected ~75%%)", (ones_count * 100) / 1000);

        $display("All tests completed!");
        #1000;
        $finish;
    end

    // Timeout watchdog
    initial begin
        #1000000;  // 1ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
