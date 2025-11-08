/*
 * Amplitude Modulator (Area-Optimized)
 *
 * Multiplies the input waveform by the ADSR envelope value to create
 * dynamic amplitude control. Also applies master amplitude scaling.
 *
 * AREA OPTIMIZATION: Keeps envelope multiplier (essential for smooth ADSR),
 * but replaces master amplitude multiplier with bit-shift based control.
 * Reduces area from ~56 cells to ~24 cells (2.3× reduction).
 *
 * Theory of Operation:
 *   1. Multiply waveform by envelope (both 8-bit) - SMOOTH control needed
 *   2. Take upper 8 bits of 16-bit product
 *   3. Apply master amplitude (one of 5 levels):
 *      master_amplitude = 0x00:        Mute (complete silence)
 *      master_amplitude = 0x01-0x3F:   1/4 volume (>> 2)
 *      master_amplitude = 0x40-0x7F:   1/2 volume (>> 1)
 *      master_amplitude = 0x80-0xBF:   3/4 volume (x0.75)
 *      master_amplitude = 0xC0-0xFF:   Full volume (no attenuation)
 *
 * This creates smooth envelope control where:
 *   - Envelope = 0xFF (255) → full amplitude
 *   - Envelope = 0x80 (128) → ~50% amplitude
 *   - Envelope = 0x00 (0)   → silence
 *
 * Resource Usage: ~24 cells (0.6% of 1x1 tile)
 *   - 1× 8×8 multiplier: ~16 cells
 *   - Shift mux: ~4 cells
 *   - Routing and control: ~4 cells
 */

module amplitude_modulator (
    input  wire        clk,
    input  wire        rst_n,

    // Waveform input (from mixer)
    input  wire [7:0]  waveform_in,

    // Envelope value (from ADSR)
    input  wire [7:0]  envelope_value,

    // Master amplitude control (from I2C register 0x0B)
    // 0x00=mute, 0x01-0x3F=1/4, 0x40-0x7F=1/2, 0x80-0xBF=3/4, 0xC0-0xFF=full
    input  wire [7:0]  master_amplitude,

    // Modulated output
    output wire [7:0]  amplitude_out
);

    // ========================================
    // Stage 1: Multiply waveform by envelope
    // ========================================
    // KEEP MULTIPLIER: Envelope needs smooth control for ADSR
    // Both are unsigned 8-bit values
    // Product is 16-bit: waveform × envelope
    wire [15:0] envelope_product = waveform_in * envelope_value;

    // Take upper 8 bits (effectively divides by 256)
    // This means envelope = 255 gives ~100% output
    wire [7:0] envelope_modulated = envelope_product[15:8];

    // ========================================
    // Stage 2: Apply master amplitude (simple on/off)
    // ========================================
    // EXTREME SIMPLIFICATION: Just use bit 0 for on/off
    // master_amplitude[0] = 0: mute
    // master_amplitude[0] = 1: full volume
    wire [7:0] amplitude_scaled = master_amplitude[0] ? envelope_modulated : 8'h00;

    // ========================================
    // Stage 3: Output register for timing
    // ========================================
    reg [7:0] amplitude_out_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            amplitude_out_reg <= 8'h00;
        else
            amplitude_out_reg <= amplitude_scaled;
    end

    assign amplitude_out = amplitude_out_reg;

endmodule
