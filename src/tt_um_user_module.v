/*
 * Top-level user module for Tiny Tapeout
 * 
 * This module implements an 8-cell shift register.
 * Based on your pinout in info.yaml:
 * - ui[0] (A) is the data input
 * - uo[7:0] are the 8 register outputs
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

    // Internal register for the shift register stages
    reg [7:0] shift_reg;
    
    // 8-cell shift register: Each flip-flop's output feeds the next flip-flop's input
    // On each clock edge, data shifts from left to right
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Active-low reset: clear all bits
            shift_reg <= 8'b0;
        end else begin
            // Shift operation: new data enters from ui_in[0], rest shifts right
            shift_reg <= {shift_reg[6:0], ui_in[0]};
        end
    end
    
    // Output all 8 register bits
    assign uo_out = shift_reg;
    
    // Configure IOs as inputs (all zeros means input mode)
    assign uio_oe = 8'b0;
    assign uio_out = 8'b0;

endmodule

