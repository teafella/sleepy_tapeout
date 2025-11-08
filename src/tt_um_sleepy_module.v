/*
 * TinyTapeout Synthesizer - Top Level Module (Minimal - Area-Optimized)
 *
 * I2C-Controlled Waveform Generator with ADSR Envelope
 *
 * EXTREME AREA OPTIMIZATION for 1×1 tile fit:
 * - I2C slave interface for configuration (11 registers)
 * - Phase accumulator with 3 waveform generators (square, sawtooth, triangle)
 * - 3-channel waveform mixer with on/off enables
 * - ADSR envelope generator
 * - Amplitude modulator with on/off master control
 * - Delta-sigma DAC for 1-bit audio output
 *
 * Removed: sine wave, noise, individual gain controls
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
    // I2C Slave Interface - Minimal Register Bank (11 registers)
    // ========================================
    wire [7:0] reg_control;       // bits [0]=OSC_EN, [1]=SW_GATE, [2-4]=waveform enables
    wire [7:0] reg_freq_low;
    wire [7:0] reg_freq_mid;
    wire [7:0] reg_freq_high;
    wire [7:0] reg_duty;
    wire [7:0] reg_attack;
    wire [7:0] reg_decay;
    wire [7:0] reg_sustain;
    wire [7:0] reg_release;
    wire [7:0] reg_amplitude;     // bit 0 only: 0=mute, 1=full
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
        // Minimal registers only (11 total)
        .reg_control(reg_control),
        .reg_freq_low(reg_freq_low),
        .reg_freq_mid(reg_freq_mid),
        .reg_freq_high(reg_freq_high),
        .reg_duty(reg_duty),
        .reg_attack(reg_attack),
        .reg_decay(reg_decay),
        .reg_sustain(reg_sustain),
        .reg_release(reg_release),
        .reg_amplitude(reg_amplitude),
        .reg_status(reg_status),
        // Status inputs
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
    // Waveform Generators (3 waveforms only)
    // ========================================
    wire [7:0] sawtooth_out;
    wire [7:0] triangle_out;

    waveform_generators wavegens (
        .clk(clk),
        .rst_n(system_rst_n),
        .enable(reg_control[0] & ena),
        .phase_in(phase),
        .sawtooth_out(sawtooth_out),
        .triangle_out(triangle_out)
    );

    // ========================================
    // 3-Channel Waveform Mixer (on/off control)
    // ========================================
    wire [7:0] mixed_wave;

    waveform_mixer mixer (
        .clk(clk),
        .rst_n(system_rst_n),
        .square_in(square_out),
        .sawtooth_in(sawtooth_out),
        .triangle_in(triangle_out),
        .enable_square(reg_control[2]),    // Control bit 2
        .enable_sawtooth(reg_control[3]),  // Control bit 3
        .enable_triangle(reg_control[4]),  // Control bit 4
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
