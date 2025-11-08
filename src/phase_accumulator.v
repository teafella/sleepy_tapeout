/*
 * Phase Accumulator with Square Wave Generator
 *
 * The phase accumulator is the core of the DDS (Direct Digital Synthesis)
 * oscillator. It's a 24-bit register that increments by a frequency control
 * word each clock cycle, creating a linear phase ramp.
 *
 * This module also includes a simple square wave generator with variable
 * duty cycle for testing and basic waveform output.
 *
 * Frequency Calculation:
 *   f_out = (frequency_word × f_clk) / 2^24
 *   frequency_word = (f_out × 2^24) / f_clk
 *
 * Examples at 50 MHz clock:
 *   440 Hz: frequency_word = 147,456 (0x024000)
 *   1 kHz:  frequency_word = 335,544 (0x051EB8)
 *   10 kHz: frequency_word = 3,355,443 (0x333333)
 *
 * Parameters:
 *   - clk: 50 MHz system clock
 *   - rst_n: Active-low reset
 *   - enable: Enable phase accumulation
 *   - frequency: 24-bit frequency control word
 *   - duty_cycle: 8-bit duty cycle (0=0%, 128=50%, 255=100%)
 *   - phase_out: 24-bit phase output (for other waveform generators)
 *   - square_out: 8-bit square wave output (0x00 or 0xFF)
 *
 * Resource Usage: ~24 DFFs + 24-bit adder + 8-bit comparator ≈ 60 cells
 */

module phase_accumulator (
    input  wire        clk,           // 50 MHz system clock
    input  wire        rst_n,         // Active-low reset
    input  wire        enable,        // Enable accumulation
    input  wire [23:0] frequency,     // 24-bit frequency control word
    input  wire [7:0]  duty_cycle,    // 8-bit duty cycle control
    output reg  [23:0] phase_out,     // 24-bit phase output
    output wire [7:0]  square_out     // Square wave output
);

    // 24-bit phase accumulator
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            phase_out <= 24'b0;
        end else if (enable) begin
            // Increment phase by frequency word each clock
            // Automatic wraparound at 2^24 creates the oscillation
            phase_out <= phase_out + frequency;
        end
    end

    // Square wave generator with variable duty cycle
    // Compare upper 8 bits of phase against duty cycle
    // duty_cycle = 0:   always low (0%)
    // duty_cycle = 128: 50% duty cycle
    // duty_cycle = 255: always high (~100%)
    assign square_out = (phase_out[23:16] < duty_cycle) ? 8'hFF : 8'h00;

endmodule
