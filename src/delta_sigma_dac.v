/*
 * Delta-Sigma DAC
 *
 * Converts an 8-bit digital audio signal to a 1-bit output stream
 * using delta-sigma modulation. This provides a simple way to generate
 * analog audio output with just an external RC low-pass filter.
 *
 * Parameters:
 * - clk: 50 MHz system clock
 * - rst_n: Active-low reset
 * - data_in: 8-bit audio input (0-255)
 * - dac_out: 1-bit delta-sigma modulated output
 *
 * Theory of Operation:
 * The delta-sigma DAC accumulates the input value (left-shifted by 4 bits
 * to provide headroom) into a 12-bit accumulator. The MSB of the accumulator
 * is output as the 1-bit stream. This creates a pulse-density modulated
 * signal where the average duty cycle represents the input amplitude.
 *
 * At 50 MHz output rate, a simple RC filter with cutoff ~25 kHz will
 * recover the audio signal.
 *
 * Resource Usage: ~47 cells (12 DFFs + 12-bit adder)
 */

module delta_sigma_dac (
    input  wire        clk,      // 50 MHz system clock
    input  wire        rst_n,    // Active-low reset
    input  wire [7:0]  data_in,  // 8-bit audio input
    output wire        dac_out   // 1-bit delta-sigma output
);

    // First-order delta-sigma modulator with proper signed arithmetic
    reg signed [9:0] error_acc;  // 10-bit signed error accumulator
    reg dac_out_reg;              // Registered output for feedback

    // Delta-sigma modulation with error feedback
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_acc <= 10'sd0;
            dac_out_reg <= 1'b0;
        end else begin
            // Accumulate: error = error + input - feedback
            // feedback = 255 when output high, 0 when output low
            // This keeps error centered around 0
            error_acc <= error_acc + $signed({2'b0, data_in}) - $signed(dac_out_reg ? 10'd255 : 10'd0);

            // Output 1 when error accumulator is positive
            // This creates pulse density proportional to input
            dac_out_reg <= (error_acc >= 10'sd0);
        end
    end

    // Output the registered value
    assign dac_out = dac_out_reg;

endmodule
