/*
 * Testbench for drum trigger module
 * This testbench verifies the circular shift register and drum trigger functionality
 */

module tb;

    // Clock generation
    reg clk;
    reg rst_n;
    reg ena;
    
    // I/O signals
    reg [7:0] ui_in;
    wire [7:0] uo_out;
    reg [7:0] uio_in;
    wire [7:0] uio_out;
    wire [7:0] uio_oe;
    
    // Trigger counting
    integer trigger_count;
    integer rising_edge_count;
    reg prev_trigger;  // Track previous trigger state for edge detection
    
    // Monitor rising edges in real-time
    always @(posedge uo_out[7]) begin
        if (rst_n) begin
            rising_edge_count = rising_edge_count + 1;
        end
    end
    
    // Instantiate the design under test
    tt_um_user_module dut (
        .ui_in(ui_in),
        .uo_out(uo_out),
        .uio_in(uio_in),
        .uio_out(uio_out),
        .uio_oe(uio_oe),
        .ena(ena),
        .clk(clk),
        .rst_n(rst_n)
    );
    
    // Clock generation - 50MHz (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 10ns half period = 20ns full period
    end
    
    // Test stimulus
    initial begin
        // Initialize
        rst_n = 0;
        ena = 1;
        ui_in = 8'h00;
        uio_in = 8'h00;
        trigger_count = 0;
        rising_edge_count = 0;
        
        // Wait a bit, then release reset
        #25;
        rst_n = 1;
        #10;
        
        $display("=== Drum Trigger Module Test ===");
        $display("After reset: trigger = %b", uo_out[7]);
        $display("");
        
        // Test 1: Shift in pattern 1101 - should produce 3 triggers
        $display("Test 1: Shifting in pattern 1101 - expecting 3 triggers");
        rst_n = 0;
        #20;
        rst_n = 1;
        #10;
        trigger_count = 0;
        
        // Shift in 1
        ui_in[0] = 1;
        @(posedge clk);  // Wait for 1 clock edge (shift happens)
        #1;  // Small delay to sample during clock high phase
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Shift 1: Input=1, Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        // Shift in 0
        ui_in[0] = 0;
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Shift 2: Input=0, Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        // Shift in 1
        ui_in[0] = 1;
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Shift 3: Input=1, Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        // Shift in 1
        ui_in[0] = 1;
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Shift 4: Input=1, Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        if (trigger_count == 3) begin
            $display("PASS: Got 3 triggers for pattern 1101");
        end else begin
            $display("FAIL: Expected 3 triggers, got %0d", trigger_count);
        end
        $display("");
        
        // Test 2: Continue shifting to test buffer circulation
        $display("Test 2: Testing trigger circulation in buffer");
        ui_in[0] = 0;
        trigger_count = 0;
        
        // Shift 4 more times (no new 1s, so no triggers at position 0)
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Shift 5: Input=0, Trigger=%b", uo_out[7]);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Shift 6: Input=0, Trigger=%b", uo_out[7]);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Shift 7: Input=0, Trigger=%b", uo_out[7]);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Shift 8: Input=0, Trigger=%b", uo_out[7]);
        
        $display("After 8 shifts total, pattern is loaded into 8-bit buffer");
        $display("Expecting triggers to repeat as pattern circulates...");
        $display("");
        
        // Now the pattern should repeat - we should see 3 more triggers in the next 8 cycles
        trigger_count = 0;
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Cycle 9: Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Cycle 10: Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Cycle 11: Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Cycle 12: Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Cycle 13: Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Cycle 14: Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Cycle 15: Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        @(posedge clk);
        #1;
        if (uo_out[7]) trigger_count = trigger_count + 1;
        $display("Cycle 16: Trigger=%b, Count=%0d", uo_out[7], trigger_count);
        
        if (trigger_count == 3) begin
            $display("PASS: Got 3 triggers in second cycle through buffer");
        end else begin
            $display("FAIL: Expected 3 triggers, got %0d", trigger_count);
        end
        $display("");
        
        // Test 3: Test consecutive 1s - pattern 11110000
        $display("Test 3: Testing consecutive triggers - pattern 11110000");
        rst_n = 0;
        #20;
        rst_n = 1;
        #10;
        trigger_count = 0;
        
        // Shift in 11110000
        ui_in[0] = 1; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 1; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 1; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 1; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        
        $display("Trigger count for 11110000: %0d", trigger_count);
        if (trigger_count == 4) begin
            $display("PASS: Got 4 consecutive triggers");
        end else begin
            $display("FAIL: Expected 4 triggers, got %0d", trigger_count);
        end
        $display("");
        
        // Test 4: Single trigger test
        $display("Test 4: Testing single trigger - pattern 10000000");
        rst_n = 0;
        #20;
        rst_n = 1;
        #10;
        trigger_count = 0;
        
        ui_in[0] = 1; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        ui_in[0] = 0; @(posedge clk); #1; if (uo_out[7]) trigger_count = trigger_count + 1;
        
        $display("Trigger count for 10000000: %0d", trigger_count);
        if (trigger_count == 1) begin
            $display("PASS: Got 1 trigger");
        end else begin
            $display("FAIL: Expected 1 trigger, got %0d", trigger_count);
        end
        $display("");
        
        // Test 5: Verify rising edges for consecutive 1s
        $display("Test 5: Verifying RISING EDGES for consecutive 1s - pattern 1111");
        rst_n = 0;
        #20;
        rst_n = 1;
        rising_edge_count = 0;  // Reset counter
        #10;
        
        // Shift in four consecutive 1s
        ui_in[0] = 1; #20;
        $display("Shift 1: Input=1, Rising edges so far=%0d", rising_edge_count);
        
        ui_in[0] = 1; #20;
        $display("Shift 2: Input=1, Rising edges so far=%0d", rising_edge_count);
        
        ui_in[0] = 1; #20;
        $display("Shift 3: Input=1, Rising edges so far=%0d", rising_edge_count);
        
        ui_in[0] = 1; #20;
        $display("Shift 4: Input=1, Rising edges so far=%0d", rising_edge_count);
        
        $display("Total rising edge count for 1111: %0d", rising_edge_count);
        if (rising_edge_count == 4) begin
            $display("PASS: Got 4 rising edges for 4 consecutive 1s!");
        end else begin
            $display("FAIL: Expected 4 rising edges, got %0d", rising_edge_count);
        end
        $display("");
        
        // Test 6: Reset test
        $display("Test 6: Testing reset functionality");
        rst_n = 0;
        #20;
        $display("After reset: trigger = %b (expected: 0)", uo_out[7]);
        if (uo_out[7] == 0) begin
            $display("PASS: Reset works correctly!");
        end else begin
            $display("FAIL: Reset failed! Expected 0, got %b", uo_out[7]);
        end
        
        #100;
        $display("");
        $display("=== Simulation complete ===");
        $finish;
    end
    
    // Dump waveforms for viewing in GTKWave
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

endmodule

