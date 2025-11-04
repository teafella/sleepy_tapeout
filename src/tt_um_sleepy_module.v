/*
 * Top-level user module for Tiny Tapeout
 * 
 * This module implements an 8-cell circular shift register (ring buffer)
 * with drum trigger output to segment display dot.
 * - clk (button press) shifts in a "1" into the pattern
 * - uo[7] is the drum trigger output (dot segment - high when position 0 contains a 1)
 * - Data shifts right, and bit 7 wraps around to bit 0
 * - Each 1 in the buffer triggers the output once per cycle through position 0
 */

module tt_um_sleepy_module(
    input wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,  // Dedicated outputs
    input wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out, // IOs: Output path
    output wire [7:0] uio_oe,  // IOs: Enable path (active high: 0=input, 1=output)
    input wire ena,            // Enable
    input wire clk,            // Clock
    input wire rst_n           // Reset (active low)
);

    // Internal register for the circular shift register
    reg [7:0] shift_reg;
    
    // Circular shift register: Data shifts right, bit 7 wraps to bit 0
    // Each clock pulse (button press) shifts in a "1"
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Active-low reset: clear all bits
            shift_reg <= 8'b0;
        end else begin
            // Circular shift - each button press injects a "1"
            shift_reg <= {shift_reg[6:0], shift_reg[7] | 1'b1};
        end
    end
    
    // Generate half-clock-period trigger pulses
    // When shift_reg[0] is HIGH, output is HIGH only when clock is HIGH
    // This creates 10ns pulses (half of 20ns clock period)
    // Consecutive "1"s will create separate rising edges
    // Output to dot segment (bit 7) of 7-segment display
    assign uo_out[7] = shift_reg[0] & clk;
    
    // Set other outputs to 0
    assign uo_out[6:0] = 7'b0;
    
    // Configure IOs as inputs (all zeros means input mode)
    assign uio_oe = 8'b0;
    assign uio_out = 8'b0;

endmodule

