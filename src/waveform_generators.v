/*
 * Waveform Generators (Minimal - Area-Optimized)
 *
 * EXTREME AREA OPTIMIZATION: Only 3 basic waveforms
 * Removed sine (68 cells) and noise (50 cells) to save ~120 cells
 *
 * Waveforms generated:
 * - Sawtooth: Direct phase output (simplest)
 * - Triangle: Phase folding
 *
 * All generators output 8-bit waveforms (0-255).
 *
 * Resource Usage:
 * - Sawtooth: ~0 cells (just wire assignment)
 * - Triangle: ~18 cells (fold logic)
 * Total: ~18 cells (was ~100 cells)
 */

module waveform_generators (
    input  wire        clk,           // Clock (unused, kept for compatibility)
    input  wire        rst_n,         // Reset (unused, kept for compatibility)
    input  wire        enable,        // Enable (unused, kept for compatibility)
    input  wire [23:0] phase_in,      // 24-bit phase from accumulator
    output wire [7:0]  sawtooth_out,  // Sawtooth waveform
    output wire [7:0]  triangle_out   // Triangle waveform
);

    // ========================================
    // Sawtooth Wave Generator
    // ========================================
    // Simplest waveform - just output the upper 8 bits of phase
    // Creates a linear ramp from 0 to 255
    assign sawtooth_out = phase_in[23:16];

    // ========================================
    // Triangle Wave Generator
    // ========================================
    // Fold the phase to create a triangle wave
    // When phase MSB is 0: rising edge (0 to 255)
    // When phase MSB is 1: falling edge (255 to 0)

    wire [7:0] phase_top;
    assign phase_top = phase_in[23:16];

    // Fold logic:
    // If in first half (MSB=0): output 2*phase (rising)
    // If in second half (MSB=1): output 2*(255-phase) (falling)
    assign triangle_out = phase_top[7] ? (~phase_top << 1) : (phase_top << 1);

endmodule
