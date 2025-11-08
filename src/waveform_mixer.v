/*
 * 3-Channel Waveform Mixer (Minimal - Extreme Area-Optimization)
 *
 * EXTREME AREA OPTIMIZATION: Only 3 waveforms with simple on/off control
 * Reduced from 6 channels to 3, and from 5 gain levels to simple on/off
 *
 * Theory of Operation:
 *   - Each gain is 1-bit: 0=mute, 1=full volume
 *   - Enabled waveforms are summed
 *   - If sum exceeds 255, saturation is applied
 *
 * Resource Usage: ~25 cells (0.6% of 1x1 tile)
 *   - 3× AND gates: ~3 cells
 *   - 2-level adder tree: ~12 cells
 *   - Saturation logic: ~6 cells
 *   - Output register: ~8 cells
 *   (Was ~80 cells with 6 channels and 5 gain levels)
 */

module waveform_mixer (
    input  wire        clk,
    input  wire        rst_n,

    // Waveform inputs (8-bit each) - only 3 waveforms
    input  wire [7:0]  square_in,
    input  wire [7:0]  sawtooth_in,
    input  wire [7:0]  triangle_in,

    // Gain controls (1-bit each): 0=mute, 1=full
    input  wire        enable_square,
    input  wire        enable_sawtooth,
    input  wire        enable_triangle,

    // Mixed output
    output wire [7:0]  mixed_out
);

    // ========================================
    // Stage 1: Enable/mute each waveform (simple on/off)
    // ========================================
    wire [7:0] gated_square   = enable_square   ? square_in   : 8'h00;
    wire [7:0] gated_sawtooth = enable_sawtooth ? sawtooth_in : 8'h00;
    wire [7:0] gated_triangle = enable_triangle ? triangle_in : 8'h00;

    // ========================================
    // Stage 2: Sum enabled waveforms
    // ========================================
    // Two-level adder tree
    wire [8:0] sum_01 = {1'b0, gated_square} + {1'b0, gated_sawtooth};
    wire [9:0] sum_final = {1'b0, sum_01} + {2'b0, gated_triangle};

    // ========================================
    // Stage 3: Saturate to 8-bit range
    // ========================================
    // If upper 2 bits are set, we've exceeded 255
    wire overflow = (sum_final[9:8] != 2'b00);
    wire [7:0] mixed_saturated = overflow ? 8'hFF : sum_final[7:0];

    // Output register removed to save area (~8 cells)
    // Amplitude modulator already has output register
    assign mixed_out = mixed_saturated;

endmodule
