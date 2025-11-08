/*
 * TinyTapeout Synthesizer - Top Level Module (Minimal - Area-Optimized)
 *
 * SPI-Controlled Waveform Generator with Smooth Volume Control
 *
 * AREA OPTIMIZATION for 1×1 tile fit:
 * - SPI RX interface for configuration (~45 cells, vs ~180 for UART, ~220 for I2C)
 * - Phase accumulator with 3 waveform generators (square, sawtooth, triangle)
 * - 3-channel waveform mixer with on/off enables
 * - Smooth 8-bit volume control via 8×8 multiplier (saved area by switching to SPI)
 * - Delta-sigma DAC for 1-bit audio output
 *
 * Removed to fit in 1x1 tile:
 * - ADSR envelope generator (~250 cells) - envelope shaping via external SPI control
 * - Amplitude modulator (~80 cells) - not needed without ADSR
 * - Sine wave, noise generators
 * - Individual gain controls
 *
 * TinyTapeout Pin Assignments:
 * - ui_in[0]: GATE (hardware gate trigger)
 * - ui_in[1]: HW_RST (hardware reset, active low)
 * - uio[0]: SPI_MOSI (SPI data input, Master Out Slave In)
 * - uio[1]: SPI_SCK (SPI clock input from master)
 * - uio[2]: SPI_CS (SPI chip select, active low)
 * - uo_out[0]: DAC_OUT (1-bit delta-sigma audio)
 * - uo_out[1]: GATE_LED (gate status indicator)
 * - uo_out[2]: OSC_RUN (oscillator running indicator)
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
    // SPI RX Interface - Minimal Register Bank (7 registers)
    // ========================================
    wire [7:0] reg_control;       // bits [0]=OSC_EN, [1]=SW_GATE, [2-4]=waveform enables
    wire [7:0] reg_freq_low;
    wire [7:0] reg_freq_mid;
    wire [7:0] reg_freq_high;
    wire [7:0] reg_duty;
    wire [7:0] reg_volume;        // Master volume control (smooth 0-255)
    wire [7:0] reg_status;

    // Combined frequency from three 8-bit registers
    wire [23:0] frequency = {reg_freq_high, reg_freq_mid, reg_freq_low};

    // Gate signal: hardware pin OR software control
    wire gate = ui_in[0] | reg_control[1];

    // System reset: external reset AND hardware reset pin
    wire system_rst_n = rst_n & ui_in[1];

    // ========================================
    // SPI RX Interface
    // ========================================
    wire osc_running;

    spi_rx_registers spi_rx (
        .clk(clk),
        .rst_n(system_rst_n),
        .spi_mosi(uio_in[0]),        // SPI MOSI on uio[0]
        .spi_sck(uio_in[1]),         // SPI SCK on uio[1]
        .spi_cs(uio_in[2]),          // SPI CS on uio[2]
        // Minimal registers only (7 total)
        .reg_control(reg_control),
        .reg_freq_low(reg_freq_low),
        .reg_freq_mid(reg_freq_mid),
        .reg_freq_high(reg_freq_high),
        .reg_duty(reg_duty),
        .reg_volume(reg_volume),
        .reg_status(reg_status),
        // Status inputs
        .status_gate_active(gate),
        .status_osc_running(osc_running)
    );

    // Configure all UIOs as inputs (SPI RX only, no MISO)
    assign uio_oe[7:0] = 8'b00000000;  // All UIOs as inputs
    assign uio_out[7:0] = 8'b00000000;

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
    // Volume Control (Smooth 8×8 Multiplier)
    // ========================================
    // Smooth volume control restored by switching to UART (saved ~140 cells)
    // Volume range: 0x00 = mute, 0xFF = full volume (256 smooth levels)
    //
    // Theory: Multiply mixed waveform by volume control
    // - mixed_wave: 8-bit waveform (0-255)
    // - reg_volume: 8-bit volume (0-255)
    // - Product: 16-bit (0-65025)
    // - Output: upper 8 bits (effectively divides by 256)
    //
    // Examples:
    //   volume=0xFF (255): ~100% output
    //   volume=0x80 (128): ~50% output
    //   volume=0x00 (0):   0% output (mute)
    wire [15:0] volume_product = mixed_wave * reg_volume;
    wire [7:0] volume_multiplied = volume_product[15:8];

    reg [7:0] volume_scaled;
    always @(posedge clk or negedge system_rst_n) begin
        if (!system_rst_n)
            volume_scaled <= 8'h00;
        else
            volume_scaled <= volume_multiplied;
    end

    // ========================================
    // Delta-Sigma DAC (1-bit output)
    // ========================================
    wire dac_out;

    delta_sigma_dac dac (
        .clk(clk),
        .rst_n(system_rst_n),
        .data_in(volume_scaled),  // Volume-controlled signal (registered)
        .dac_out(dac_out)
    );

    // ========================================
    // Output Assignments
    // ========================================
    assign uo_out[0] = dac_out;           // 1-bit audio output
    assign uo_out[1] = gate;              // Gate LED indicator
    assign uo_out[2] = osc_running;       // Oscillator running indicator
    assign uo_out[3] = phase[23];         // Sync pulse (phase MSB)
    assign uo_out[7:4] = 4'b0000;         // Reserved/unused outputs

endmodule
