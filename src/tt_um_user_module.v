/*
 * Top-level user module for Tiny Tapeout
 * 
 * This module implements your design logic.
 * Based on your pinout in info.yaml:
 * - ui[0] (A) and ui[1] (B) are inputs
 * - uo[0] (OUT) is an output
 */

module tt_um_user_module(
    input wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,  // Dedicated outputs
    input wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out, // IOs: Output path
    output wire [7:0] uio_oe,  // IOs: Enable path (active high: 0=input, 1=output)
    input wire ena,            // Enable
    input wire clk,            // Clock
    input wire rst_n           // Reset (active low)
);

    // Example: Simple AND gate using ui[0] (A) and ui[1] (B) as inputs
    // and outputting to uo[0] (OUT)
    assign uo_out[0] = ui_in[0] & ui_in[1];
    
    // Set unused outputs to 0
    assign uo_out[7:1] = 7'b0;
    
    // Configure IOs as inputs (all zeros means input mode)
    assign uio_oe = 8'b0;
    assign uio_out = 8'b0;

endmodule

