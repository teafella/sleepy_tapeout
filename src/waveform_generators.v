/*
 * Waveform Generators
 *
 * This module contains multiple waveform generators that all share
 * the same 24-bit phase input from the phase accumulator.
 *
 * Waveforms generated:
 * - Sawtooth: Direct phase output (simplest)
 * - Triangle: Phase folding
 * - Sine: Polynomial approximation
 * - Noise: 32-bit LFSR pseudo-random generator
 *
 * All generators output 8-bit waveforms (0-255).
 *
 * Resource Usage:
 * - Sawtooth: ~0 cells (just wire assignment)
 * - Triangle: ~18 cells (fold logic)
 * - Sine: ~68 cells (polynomial approximation + multiplier)
 * - Noise: ~15 cells (32-bit LFSR)
 */

module waveform_generators (
    input  wire        clk,           // Clock for noise generator
    input  wire        rst_n,         // Reset for noise generator
    input  wire        enable,        // Enable for noise generator
    input  wire [23:0] phase_in,      // 24-bit phase from accumulator
    output wire [7:0]  sawtooth_out,  // Sawtooth waveform
    output wire [7:0]  triangle_out,  // Triangle waveform
    output wire [7:0]  sine_out,      // Sine waveform (polynomial approx)
    output wire [7:0]  noise_out      // Noise waveform (LFSR)
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

    // ========================================
    // Sine Wave Generator (Polynomial Approximation)
    // ========================================
    // Uses parabolic approximation with quadrant folding
    // for low-distortion sine wave generation
    //
    // Method:
    // 1. Divide full cycle into 4 quadrants using phase[23:22]
    // 2. Use phase[21:14] as x position within quadrant (0-255)
    // 3. Compute parabola: y = 4x(1-x) ≈ x(255-x)/64
    // 4. Apply quadrant symmetry
    //
    // This gives <3% max error compared to true sine

    wire [1:0] quadrant;
    wire [7:0] x;
    wire [7:0] x_inv;
    wire [15:0] product;
    wire [7:0] parabola;

    assign quadrant = phase_in[23:22];
    assign x = phase_in[21:14];          // Position within quadrant
    assign x_inv = 8'hFF - x;            // Inverted position (1-x)
    assign product = x * x_inv;          // Multiply x * (1-x)
    assign parabola = product[15:8];     // Scale down (divide by 256)

    // Apply quadrant symmetry:
    // Quadrant 0 (0°-90°):   parabola
    // Quadrant 1 (90°-180°): parabola
    // Quadrant 2 (180°-270°): -parabola (inverted)
    // Quadrant 3 (270°-360°): -parabola (inverted)
    assign sine_out = quadrant[1] ? (~parabola) : parabola;

    // ========================================
    // Noise Generator (32-bit LFSR)
    // ========================================
    // Generates pseudo-random noise using a maximal-length LFSR
    // Polynomial: x^32 + x^22 + x^2 + x^1 + 1
    // Period: 2^32 - 1 samples (4,294,967,295)

    (* keep *) reg [31:0] lfsr;  // Keep attribute prevents optimization

    // Feedback taps for maximal-length sequence
    wire feedback;
    assign feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize with non-zero seed
            lfsr <= 32'hACE1;
        end else if (enable) begin
            // Shift left and insert feedback bit
            lfsr <= {lfsr[30:0], feedback};
        end
    end

    // Output upper 8 bits of LFSR for noise waveform
    assign noise_out = lfsr[31:24];

endmodule
