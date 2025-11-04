/*
 * Testbench wrapper for cocotb
 * The actual tests are in test.py (cocotb)
 * This Verilog module just instantiates the DUT and provides clock
 */

module tb;

    // Clock and control signals
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
    
    // Dump waveforms for viewing in GTKWave
    initial begin
        $dumpfile("tb.vcd");
        $dumpvars(0, tb);
    end

endmodule

