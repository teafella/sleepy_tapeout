/*
 * 6-Channel Waveform Mixer
 *
 * Combines six waveforms (square, sawtooth, triangle, sine, noise, wavetable)
 * with independent gain controls to create complex timbres.
 *
 * Theory of Operation:
 *   mixed_output = (square × gain_sq + sawtooth × gain_saw + triangle × gain_tri +
 *                   sine × gain_sin + noise × gain_noise + wavetable × gain_wt) / 256
 *
 * Each waveform is multiplied by its 8-bit gain value, then all products are
 * summed and divided by 256 (arithmetic right shift by 8). If the sum exceeds
 * the 8-bit range, saturation is applied.
 *
 * Resource Usage: ~642 cells (16.1% of 1x1 tile)
 *   - 6× 8×8 multipliers: ~360 cells
 *   - Adder tree: ~100 cells
 *   - Saturation logic: ~40 cells
 *   - Output register: ~8 cells
 *   - Control logic: ~30 cells
 *   - Routing: ~104 cells
 */

module waveform_mixer (
    input  wire        clk,
    input  wire        rst_n,

    // Waveform inputs (8-bit each)
    input  wire [7:0]  square_in,
    input  wire [7:0]  sawtooth_in,
    input  wire [7:0]  triangle_in,
    input  wire [7:0]  sine_in,
    input  wire [7:0]  noise_in,
    input  wire [7:0]  wavetable_in,

    // Gain controls (8-bit each, from I2C registers)
    input  wire [7:0]  gain_square,
    input  wire [7:0]  gain_sawtooth,
    input  wire [7:0]  gain_triangle,
    input  wire [7:0]  gain_sine,
    input  wire [7:0]  gain_noise,
    input  wire [7:0]  gain_wavetable,

    // Mixed output
    output wire [7:0]  mixed_out
);

    // ========================================
    // Stage 1: Multiply each waveform by its gain
    // ========================================
    // Each multiplication produces a 16-bit result
    wire [15:0] product_square    = square_in * gain_square;
    wire [15:0] product_sawtooth  = sawtooth_in * gain_sawtooth;
    wire [15:0] product_triangle  = triangle_in * gain_triangle;
    wire [15:0] product_sine      = sine_in * gain_sine;
    wire [15:0] product_noise     = noise_in * gain_noise;
    wire [15:0] product_wavetable = wavetable_in * gain_wavetable;

    // ========================================
    // Stage 2: Sum all products using adder tree
    // ========================================
    // Three-level adder tree for better timing

    // First level: Combine products in pairs (3 adders)
    wire [16:0] sum_01 = product_square + product_sawtooth;
    wire [16:0] sum_23 = product_triangle + product_sine;
    wire [16:0] sum_45 = product_noise + product_wavetable;

    // Second level: Combine first two pairs (1 adder)
    wire [17:0] sum_0123 = sum_01 + sum_23;

    // Third level: Add final pair (1 adder)
    wire [17:0] sum_final_temp = sum_0123 + {1'b0, sum_45};

    // ========================================
    // Stage 3: Scale by dividing by 256
    // ========================================
    // Shift right by 8 bits (divide by 256)
    // This normalizes the gain so that full gain (255) on one input
    // produces full output (255) for that waveform
    wire [9:0] sum_scaled = sum_final_temp[17:8];  // Take upper 10 bits

    // ========================================
    // Stage 4: Saturate to 8-bit range
    // ========================================
    // If any of the upper 2 bits are set, we've exceeded 255
    wire overflow = (sum_scaled[9:8] != 2'b00);
    wire [7:0] mixed_saturated = overflow ? 8'hFF : sum_scaled[7:0];

    // ========================================
    // Stage 5: Output register for timing
    // ========================================
    reg [7:0] mixed_out_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mixed_out_reg <= 8'h00;
        else
            mixed_out_reg <= mixed_saturated;
    end

    assign mixed_out = mixed_out_reg;

endmodule
