/*
 * Top-level user module for Tiny Tapeout
 * 
 * This module implements an 8-cell circular shift register (ring buffer).
 * Based on your pinout in info.yaml:
 * - ui[0] (A) is the data input (enters at position 0)
 * - uo[7:0] are the 8 register outputs
 * - Data shifts right, and bit 7 wraps around to bit 0
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

    // Internal register for the circular shift register stages
    reg [7:0] shift_reg;
    
    // 8-cell circular shift register: Data shifts right, and bit 7 wraps to bit 0
    // External input (ui_in[0]) can be used to inject new data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Active-low reset: clear all bits
            shift_reg <= 8'b0;
        end else begin
            // Circular shift: bit 7 wraps to bit 0
            // External input can inject new data (OR with wrapped bit) or replace it
            // Using OR so external input can inject a 1, and wrapped bit also wraps
            shift_reg <= {shift_reg[6:0], shift_reg[7] | ui_in[0]};
        end
    end
    
    // Output all 8 register bits
    assign uo_out = shift_reg;
    
    // Configure IOs as inputs (all zeros means input mode)
    assign uio_oe = 8'b0;
    assign uio_out = 8'b0;

endmodule

