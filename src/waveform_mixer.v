/*
 * 6-Channel Waveform Mixer (Area-Optimized)
 *
 * Combines six waveforms (square, sawtooth, triangle, sine, noise, wavetable)
 * with independent gain controls to create complex timbres.
 *
 * AREA OPTIMIZATION: Uses bit-shift based gain controls instead of multipliers
 * to reduce area from ~642 cells to ~80 cells (8× reduction).
 *
 * Theory of Operation:
 *   - Each 8-bit gain register selects one of 5 gain levels:
 *     gain = 0x00:        Mute (complete silence)
 *     gain = 0x01-0x3F:   1/4 volume (>> 2)
 *     gain = 0x40-0x7F:   1/2 volume (>> 1)
 *     gain = 0x80-0xBF:   3/4 volume (x0.75)
 *     gain = 0xC0-0xFF:   Full volume (no attenuation)
 *
 *   - Waveforms are shifted right according to gain, then summed
 *   - If sum exceeds 255, saturation is applied
 *
 * Resource Usage: ~80 cells (2% of 1x1 tile)
 *   - 6× shift muxes: ~36 cells
 *   - Adder tree: ~24 cells
 *   - Saturation logic: ~12 cells
 *   - Output register: ~8 cells
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
    // 0x00=mute, 0x01-0x3F=1/4, 0x40-0x7F=1/2, 0x80-0xBF=3/4, 0xC0-0xFF=full
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
    // Stage 1: Apply gain via bit-shift
    // ========================================
    // If gain == 0, mute completely
    // Otherwise use upper 2 bits to select shift amount
    function [7:0] apply_gain;
        input [7:0] waveform;
        input [7:0] gain;
        begin
            if (gain == 8'h00) begin
                apply_gain = 8'h00;  // Mute
            end else begin
                case (gain[7:6])
                    2'b00: apply_gain = waveform >> 2;  // 1/4 volume (0x01-0x3F)
                    2'b01: apply_gain = waveform >> 1;  // 1/2 volume (0x40-0x7F)
                    2'b10: apply_gain = {1'b0, waveform[7:1]} + {2'b0, waveform[7:2]};  // 3/4 volume (0x80-0xBF)
                    2'b11: apply_gain = waveform;       // Full volume (0xC0-0xFF)
                endcase
            end
        end
    endfunction

    wire [7:0] scaled_square    = apply_gain(square_in,    gain_square);
    wire [7:0] scaled_sawtooth  = apply_gain(sawtooth_in,  gain_sawtooth);
    wire [7:0] scaled_triangle  = apply_gain(triangle_in,  gain_triangle);
    wire [7:0] scaled_sine      = apply_gain(sine_in,      gain_sine);
    wire [7:0] scaled_noise     = apply_gain(noise_in,     gain_noise);
    wire [7:0] scaled_wavetable = apply_gain(wavetable_in, gain_wavetable);

    // ========================================
    // Stage 2: Sum all scaled waveforms
    // ========================================
    // Three-level adder tree for better timing

    // First level: Combine in pairs (3 adders)
    wire [8:0] sum_01 = {1'b0, scaled_square} + {1'b0, scaled_sawtooth};
    wire [8:0] sum_23 = {1'b0, scaled_triangle} + {1'b0, scaled_sine};
    wire [8:0] sum_45 = {1'b0, scaled_noise} + {1'b0, scaled_wavetable};

    // Second level: Combine first two pairs (1 adder)
    wire [9:0] sum_0123 = {1'b0, sum_01} + {1'b0, sum_23};

    // Third level: Add final pair (1 adder)
    wire [10:0] sum_final = {1'b0, sum_0123} + {2'b0, sum_45};

    // ========================================
    // Stage 3: Saturate to 8-bit range
    // ========================================
    // If any of the upper 3 bits are set, we've exceeded 255
    wire overflow = (sum_final[10:8] != 3'b000);
    wire [7:0] mixed_saturated = overflow ? 8'hFF : sum_final[7:0];

    // ========================================
    // Stage 4: Output register for timing
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
