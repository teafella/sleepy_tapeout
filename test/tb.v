/*
 * Testbench for 8-cell shift register
 * This testbench verifies the shift register functionality
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
        
        // Wait a bit, then release reset
        #25;
        rst_n = 1;
        #10;
        
        $display("=== Shift Register Test ===");
        $display("After reset: Q[7:0] = %b", uo_out);
        $display("");
        
        // Test 1: Shift in a 1, then zeros
        $display("Test 1: Shifting in 1, then zeros");
        ui_in[0] = 1;
        #20;  // Wait for clock edge
        $display("Cycle 1: Input=1, Q[7:0] = %b (expected: 00000001)", uo_out);
        
        ui_in[0] = 0;
        #20;
        $display("Cycle 2: Input=0, Q[7:0] = %b (expected: 00000010)", uo_out);
        
        #20;
        $display("Cycle 3: Input=0, Q[7:0] = %b (expected: 00000100)", uo_out);
        
        #20;
        $display("Cycle 4: Input=0, Q[7:0] = %b (expected: 00001000)", uo_out);
        
        #20;
        $display("Cycle 5: Input=0, Q[7:0] = %b (expected: 00010000)", uo_out);
        
        #20;
        $display("Cycle 6: Input=0, Q[7:0] = %b (expected: 00100000)", uo_out);
        
        #20;
        $display("Cycle 7: Input=0, Q[7:0] = %b (expected: 01000000)", uo_out);
        
        #20;
        $display("Cycle 8: Input=0, Q[7:0] = %b (expected: 10000000)", uo_out);
        
        #20;
        $display("Cycle 9: Input=0, Q[7:0] = %b (expected: 00000000)", uo_out);
        $display("");
        
        // Test 2: Shift in a pattern 10110110
        $display("Test 2: Shifting in pattern 10110110");
        rst_n = 0;
        #20;
        rst_n = 1;
        #10;
        
        ui_in[0] = 1;  // bit 0
        #20;
        $display("Cycle 1: Input=1, Q[7:0] = %b", uo_out);
        
        ui_in[0] = 0;  // bit 1
        #20;
        $display("Cycle 2: Input=0, Q[7:0] = %b", uo_out);
        
        ui_in[0] = 1;  // bit 2
        #20;
        $display("Cycle 3: Input=1, Q[7:0] = %b", uo_out);
        
        ui_in[0] = 1;  // bit 3
        #20;
        $display("Cycle 4: Input=1, Q[7:0] = %b", uo_out);
        
        ui_in[0] = 0;  // bit 4
        #20;
        $display("Cycle 5: Input=0, Q[7:0] = %b", uo_out);
        
        ui_in[0] = 1;  // bit 5
        #20;
        $display("Cycle 6: Input=1, Q[7:0] = %b", uo_out);
        
        ui_in[0] = 1;  // bit 6
        #20;
        $display("Cycle 7: Input=1, Q[7:0] = %b", uo_out);
        
        ui_in[0] = 0;  // bit 7
        #20;
        $display("Cycle 8: Input=0, Q[7:0] = %b (expected: 10110110)", uo_out);
        $display("Expected pattern: 10110110");
        
        // Verify final result
        if (uo_out == 8'b10110110) begin
            $display("PASS: Pattern matches expected value!");
        end else begin
            $display("FAIL: Pattern mismatch! Expected 10110110, got %b", uo_out);
        end
        $display("");
        
        // Test 3: Reset test
        $display("Test 3: Testing reset functionality");
        rst_n = 0;
        #20;
        $display("After reset: Q[7:0] = %b (expected: 00000000)", uo_out);
        if (uo_out == 8'b00000000) begin
            $display("PASS: Reset works correctly!");
        end else begin
            $display("FAIL: Reset failed! Expected 00000000, got %b", uo_out);
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

