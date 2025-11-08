/*
 * TinyTapeout Synthesizer - Top Level Module
 *
 * I2C-Controlled Waveform Generator with ADSR Envelope
 *
 * This is a simplified integration that includes the core synthesizer components:
 * - I2C slave interface for configuration
 * - Phase accumulator with 6 waveform generators
 * - 6-channel waveform mixer with individual gain controls
 * - ADSR envelope generator
 * - Amplitude modulator
 * - Delta-sigma DAC for 1-bit audio output
 *
 * Additional components (filter, modulation routing, etc.) will be added incrementally.
 *
 * TinyTapeout Pin Assignments:
 * - ui_in[0]: GATE (hardware gate trigger)
 * - ui_in[1]: HW_RST (hardware reset, active low)
 * - uio[0]: SDA (I2C data, bidirectional)
 * - uio[1]: SCL (I2C clock input)
 * - uo_out[0]: DAC_OUT (1-bit delta-sigma audio)
 * - uo_out[1]: GATE_LED (gate status indicator)
 * - uo_out[2]: ENV_OUT (envelope MSB for visualization)
 * - uo_out[3]: SYNC (phase sync pulse)
 */

module tt_um_sleepy_module (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // Enable signal
    input  wire       clk,      // 50 MHz clock
    input  wire       rst_n     // Active-low reset
);

    // ========================================
    // I2C Slave Interface - Register Bank
    // ========================================
    wire [7:0] reg_control;
    wire [7:0] reg_waveform;
    wire [7:0] reg_freq_low;
    wire [7:0] reg_freq_mid;
    wire [7:0] reg_freq_high;
    wire [7:0] reg_duty;
    wire [7:0] reg_phase_offset;
    wire [7:0] reg_attack;
    wire [7:0] reg_decay;
    wire [7:0] reg_sustain;
    wire [7:0] reg_release;
    wire [7:0] reg_amplitude;
    wire [7:0] reg_svf1_cutoff;
    wire [7:0] reg_svf1_resonance;
    wire [7:0] reg_svf2_cutoff;
    wire [7:0] reg_svf2_resonance;
    wire [7:0] reg_filter_mode;
    wire [7:0] reg_filter_enable;
    wire [7:0] reg_wavetable_idx;
    wire [7:0] reg_wavetable_data;
    wire [7:0] reg_wavetable_ctrl;
    wire [7:0] reg_mod_routing;
    wire [7:0] reg_mod_depth_cutoff;
    wire [7:0] reg_mod_depth_resonance;
    wire [7:0] reg_mod_depth_pitch;
    wire [7:0] reg_bypass_ctrl;
    wire [7:0] reg_gain_square;
    wire [7:0] reg_gain_sawtooth;
    wire [7:0] reg_gain_triangle;
    wire [7:0] reg_gain_sine;
    wire [7:0] reg_gain_noise;
    wire [7:0] reg_gain_wavetable;
    wire [7:0] reg_glide_rate;
    wire [7:0] reg_pwm_depth;
    wire [7:0] reg_ring_mod_config;
    wire [7:0] reg_status;

    // Combined frequency from three 8-bit registers
    wire [23:0] frequency = {reg_freq_high, reg_freq_mid, reg_freq_low};

    // Gate signal: hardware pin OR software control
    wire gate = ui_in[0] | reg_control[1];

    // System reset: external reset AND hardware reset pin
    wire system_rst_n = rst_n & ui_in[1];

    // ========================================
    // I2C Slave Interface
    // ========================================
    wire sda_out_i2c;
    wire sda_oe_i2c;
    wire [2:0] adsr_state_for_status;
    wire osc_running;

    i2c_slave #(
        .I2C_ADDR(7'h50)
    ) i2c (
        .clk(clk),
        .rst_n(system_rst_n),
        .scl_in(uio_in[1]),
        .sda_in(uio_in[0]),
        .sda_out(sda_out_i2c),
        .sda_oe(sda_oe_i2c),
        .reg_control(reg_control),
        .reg_waveform(reg_waveform),
        .reg_freq_low(reg_freq_low),
        .reg_freq_mid(reg_freq_mid),
        .reg_freq_high(reg_freq_high),
        .reg_duty(reg_duty),
        .reg_phase_offset(reg_phase_offset),
        .reg_attack(reg_attack),
        .reg_decay(reg_decay),
        .reg_sustain(reg_sustain),
        .reg_release(reg_release),
        .reg_amplitude(reg_amplitude),
        .reg_svf1_cutoff(reg_svf1_cutoff),
        .reg_svf1_resonance(reg_svf1_resonance),
        .reg_svf2_cutoff(reg_svf2_cutoff),
        .reg_svf2_resonance(reg_svf2_resonance),
        .reg_filter_mode(reg_filter_mode),
        .reg_filter_enable(reg_filter_enable),
        .reg_status(reg_status),
        .reg_wavetable_idx(reg_wavetable_idx),
        .reg_wavetable_data(reg_wavetable_data),
        .reg_wavetable_ctrl(reg_wavetable_ctrl),
        .reg_mod_routing(reg_mod_routing),
        .reg_mod_depth_cutoff(reg_mod_depth_cutoff),
        .reg_mod_depth_resonance(reg_mod_depth_resonance),
        .reg_mod_depth_pitch(reg_mod_depth_pitch),
        .reg_bypass_ctrl(reg_bypass_ctrl),
        .reg_gain_square(reg_gain_square),
        .reg_gain_sawtooth(reg_gain_sawtooth),
        .reg_gain_triangle(reg_gain_triangle),
        .reg_gain_sine(reg_gain_sine),
        .reg_gain_noise(reg_gain_noise),
        .reg_gain_wavetable(reg_gain_wavetable),
        .reg_glide_rate(reg_glide_rate),
        .reg_pwm_depth(reg_pwm_depth),
        .reg_ring_mod_config(reg_ring_mod_config),
        .status_gate_active(gate),
        .status_adsr_state(adsr_state_for_status),
        .status_osc_running(osc_running)
    );

    // Configure I2C SDA as bidirectional
    assign uio_out[0] = sda_out_i2c;
    assign uio_oe[0] = sda_oe_i2c;
    assign uio_oe[7:1] = 7'b0000000;  // Other UIOs as inputs
    assign uio_out[7:1] = 7'b0000000;

    // ========================================
    // Phase Accumulator
    // ========================================
    wire [23:0] phase;
    wire [7:0] square_out;

    phase_accumulator phase_acc (
        .clk(clk),
        .rst_n(system_rst_n),
        .enable(reg_control[0] & ena),
        .frequency(frequency),
        .duty_cycle(reg_duty),
        .phase_out(phase),
        .square_out(square_out)
    );

    assign osc_running = reg_control[0] & ena;

    // ========================================
    // Waveform Generators
    // ========================================
    wire [7:0] sawtooth_out;
    wire [7:0] triangle_out;
    wire [7:0] sine_out;
    wire [7:0] noise_out;

    waveform_generators wavegens (
        .clk(clk),
        .rst_n(system_rst_n),
        .enable(reg_control[0] & ena),
        .phase_in(phase),
        .sawtooth_out(sawtooth_out),
        .triangle_out(triangle_out),
        .sine_out(sine_out),
        .noise_out(noise_out)
    );

    // Wavetable placeholder (not yet implemented)
    wire [7:0] wavetable_out = 8'h00;

    // ========================================
    // 6-Channel Waveform Mixer
    // ========================================
    wire [7:0] mixed_wave;

    waveform_mixer mixer (
        .clk(clk),
        .rst_n(system_rst_n),
        .square_in(square_out),
        .sawtooth_in(sawtooth_out),
        .triangle_in(triangle_out),
        .sine_in(sine_out),
        .noise_in(noise_out),
        .wavetable_in(wavetable_out),
        .gain_square(reg_gain_square),
        .gain_sawtooth(reg_gain_sawtooth),
        .gain_triangle(reg_gain_triangle),
        .gain_sine(reg_gain_sine),
        .gain_noise(reg_gain_noise),
        .gain_wavetable(reg_gain_wavetable),
        .mixed_out(mixed_wave)
    );

    // ========================================
    // ADSR Envelope Generator
    // ========================================
    wire [7:0] envelope_value;

    adsr_envelope adsr (
        .clk(clk),
        .rst_n(system_rst_n),
        .gate(gate),
        .attack_rate(reg_attack),
        .decay_rate(reg_decay),
        .sustain_level(reg_sustain),
        .release_rate(reg_release),
        .envelope_out(envelope_value),
        .state_out(adsr_state_for_status)
    );

    // ========================================
    // Amplitude Modulator
    // ========================================
    wire [7:0] modulated_out;

    amplitude_modulator amp_mod (
        .clk(clk),
        .rst_n(system_rst_n),
        .waveform_in(mixed_wave),
        .envelope_value(envelope_value),
        .master_amplitude(reg_amplitude),
        .amplitude_out(modulated_out)
    );

    // ========================================
    // Delta-Sigma DAC (1-bit output)
    // ========================================
    wire dac_out;

    delta_sigma_dac dac (
        .clk(clk),
        .rst_n(system_rst_n),
        .data_in(modulated_out),
        .dac_out(dac_out)
    );

    // ========================================
    // Output Assignments
    // ========================================
    assign uo_out[0] = dac_out;           // 1-bit audio output
    assign uo_out[1] = gate;              // Gate LED indicator
    assign uo_out[2] = envelope_value[7]; // Envelope MSB (visualization)
    assign uo_out[3] = phase[23];         // Sync pulse (phase MSB)
    assign uo_out[7:4] = 4'b0000;         // Reserved/unused outputs

endmodule
