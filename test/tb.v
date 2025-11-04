/*
 * Testbench for user_module
 * This is a simple testbench that can be used with cocotb or standalone simulation
 */

module tb;

    // Clock generation
    reg clk;
    reg rst_n;
    
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
        ui_in = 8'h00;
        uio_in = 8'h00;
        
        // Reset
        #20;
        rst_n = 1;
        #10;
        
        // Test case 1: A=0, B=0 -> OUT should be 0
        ui_in[0] = 0;
        ui_in[1] = 0;
        #20;
        $display("Test 1: A=%b, B=%b, OUT=%b", ui_in[0], ui_in[1], uo_out[0]);
        
        // Test case 2: A=0, B=1 -> OUT should be 0
        ui_in[0] = 0;
        ui_in[1] = 1;
        #20;
        $display("Test 2: A=%b, B=%b, OUT=%b", ui_in[0], ui_in[1], uo_out[0]);
        
        // Test case 3: A=1, B=0 -> OUT should be 0
        ui_in[0] = 1;
        ui_in[1] = 0;
        #20;
        $display("Test 3: A=%b, B=%b, OUT=%b", ui_in[0], ui_in[1], uo_out[0]);
        
        // Test case 4: A=1, B=1 -> OUT should be 1
        ui_in[0] = 1;
        ui_in[1] = 1;
        #20;
        $display("Test 4: A=%b, B=%b, OUT=%b", ui_in[0], ui_in[1], uo_out[0]);
        
        #100;
        $display("Simulation complete");
        $finish;
    end
    
    // Dump waveforms for viewing in GTKWave
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

endmodule

