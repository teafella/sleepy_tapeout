/*
 * Amplitude Modulator
 *
 * Multiplies the input waveform by the ADSR envelope value to create
 * dynamic amplitude control. Also applies master amplitude scaling.
 *
 * Theory of Operation:
 *   1. Multiply waveform by envelope (both 8-bit)
 *   2. Take upper 8 bits of 16-bit product
 *   3. Multiply by master amplitude
 *   4. Take upper 8 bits again
 *
 * This creates smooth envelope control where:
 *   - Envelope = 0xFF (255) → full amplitude
 *   - Envelope = 0x80 (128) → ~50% amplitude
 *   - Envelope = 0x00 (0)   → silence
 *
 * Resource Usage: ~56 cells (1.4% of 1x1 tile)
 *   - 2× 8×8 multipliers: ~32 cells
 *   - Routing and control: ~24 cells
 */

module amplitude_modulator (
    input  wire        clk,
    input  wire        rst_n,

    // Waveform input (from mixer)
    input  wire [7:0]  waveform_in,

    // Envelope value (from ADSR)
    input  wire [7:0]  envelope_value,

    // Master amplitude control (from I2C register 0x0B)
    input  wire [7:0]  master_amplitude,

    // Modulated output
    output wire [7:0]  amplitude_out
);

    // ========================================
    // Stage 1: Multiply waveform by envelope
    // ========================================
    // Both are unsigned 8-bit values
    // Product is 16-bit: waveform × envelope
    wire [15:0] envelope_product = waveform_in * envelope_value;

    // Take upper 8 bits (effectively divides by 256)
    // This means envelope = 255 gives ~100% output
    wire [7:0] envelope_modulated = envelope_product[15:8];

    // ========================================
    // Stage 2: Apply master amplitude
    // ========================================
    // Multiply by master amplitude for additional level control
    wire [15:0] amplitude_product = envelope_modulated * master_amplitude;

    // Take upper 8 bits again
    wire [7:0] amplitude_scaled = amplitude_product[15:8];

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
