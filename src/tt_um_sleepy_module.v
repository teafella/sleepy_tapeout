/*
 * TinyTapeout Wavetable Synthesizer - Top Level Module (Config C)
 *
 * Hybrid Wavetable Synthesizer with Dual Modes
 *
 * Features:
 * - 8-sample wavetable with linear interpolation (32 blend steps)
 * - 24-bit phase accumulator for perfect musical tuning (<1 cent error)
 * - Dual mode: Standalone wavetable synthesis OR sample streaming
 * - 8-level volume control (instant bit-shift)
 * - SPI interface for all configuration
 * - Delta-sigma DAC for 1-bit audio output
 *
 * Area Budget (~254 cells, ~56% utilization):
 * - SPI RX interface: ~45 cells
 * - Wavetable oscillator (24-bit phase + interpolation): ~105 cells
 * - Volume control (8-level bit-shift): ~10 cells
 * - Delta-Sigma DAC: ~30 cells
 * - Control logic: ~10 cells
 * - Routing overhead: ~54 cells
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
 * - uo_out[3]: SYNC (phase sync pulse, phase[23])
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
    // SPI RX Interface - Wavetable Register Bank (12 registers)
    // ========================================
    wire [7:0] reg_control;       // bits [0]=OSC_EN, [1]=STREAM_MODE, [2]=SW_GATE
    wire [7:0] reg_freq_low;
    wire [7:0] reg_freq_mid;
    wire [7:0] reg_freq_high;
    wire [7:0] reg_volume;        // Master volume control (8-level)
    wire [7:0] reg_wavetable_0;   // Wavetable sample 0 (also used for streaming)
    wire [7:0] reg_wavetable_1;   // Wavetable sample 1
    wire [7:0] reg_wavetable_2;   // Wavetable sample 2
    wire [7:0] reg_wavetable_3;   // Wavetable sample 3
    wire [7:0] reg_wavetable_4;   // Wavetable sample 4
    wire [7:0] reg_wavetable_5;   // Wavetable sample 5
    wire [7:0] reg_wavetable_6;   // Wavetable sample 6
    wire [7:0] reg_wavetable_7;   // Wavetable sample 7
    wire [7:0] reg_status;

    // Combined frequency from three 8-bit registers
    wire [23:0] frequency = {reg_freq_high, reg_freq_mid, reg_freq_low};

    // Control bit decode
    wire osc_enable = reg_control[0];
    wire stream_mode = reg_control[1];
    wire sw_gate = reg_control[2];

    // Gate signal: hardware pin OR software control
    wire gate = ui_in[0] | sw_gate;

    // System reset: external reset AND hardware reset pin
    wire system_rst_n = rst_n & ui_in[1];

    // ========================================
    // SPI RX Interface
    // ========================================
    wire osc_running = osc_enable & ena;

    spi_rx_registers spi_rx (
        .clk(clk),
        .rst_n(system_rst_n),
        .spi_mosi(uio_in[0]),        // SPI MOSI on uio[0]
        .spi_sck(uio_in[1]),         // SPI SCK on uio[1]
        .spi_cs(uio_in[2]),          // SPI CS on uio[2]
        // Register outputs (12 total)
        .reg_control(reg_control),
        .reg_freq_low(reg_freq_low),
        .reg_freq_mid(reg_freq_mid),
        .reg_freq_high(reg_freq_high),
        .reg_volume(reg_volume),
        .reg_wavetable_0(reg_wavetable_0),
        .reg_wavetable_1(reg_wavetable_1),
        .reg_wavetable_2(reg_wavetable_2),
        .reg_wavetable_3(reg_wavetable_3),
        .reg_wavetable_4(reg_wavetable_4),
        .reg_wavetable_5(reg_wavetable_5),
        .reg_wavetable_6(reg_wavetable_6),
        .reg_wavetable_7(reg_wavetable_7),
        .reg_status(reg_status),
        // Status inputs
        .status_gate_active(gate),
        .status_osc_running(osc_running)
    );

    // Configure all UIOs as inputs (SPI RX only, no MISO)
    assign uio_oe[7:0] = 8'b00000000;  // All UIOs as inputs
    assign uio_out[7:0] = 8'b00000000;

    // ========================================
    // Wavetable Oscillator (24-bit Phase + Interpolation)
    // ========================================
    wire [7:0] wavetable_out;

    wavetable_oscillator wavetable_osc (
        .clk(clk),
        .rst_n(system_rst_n),
        .enable(osc_enable & ena),
        .frequency(frequency),
        .stream_mode(stream_mode),
        .wavetable_0(reg_wavetable_0),
        .wavetable_1(reg_wavetable_1),
        .wavetable_2(reg_wavetable_2),
        .wavetable_3(reg_wavetable_3),
        .wavetable_4(reg_wavetable_4),
        .wavetable_5(reg_wavetable_5),
        .wavetable_6(reg_wavetable_6),
        .wavetable_7(reg_wavetable_7),
        .audio_out(wavetable_out)
    );

    // ========================================
    // Volume Control (Bit-Shift)
    // ========================================
    // AREA OPTIMIZATION: Replace 8×8 multiplier (~220 cells) with bit-shift (~10 cells)
    // Savings: ~210 cells!
    //
    // Features:
    // - 8 discrete volume levels (using bit-shifts)
    // - Instant volume changes (SPI write directly controls output)
    // - Volume set via SPI (reg_volume: 0-255)
    //
    // Volume levels (based on top 3 bits of reg_volume):
    //   0: Mute (0-31)
    //   1: 1/8 volume (32-63)
    //   2: 1/4 volume (64-95)
    //   3: 3/8 volume (96-127)
    //   4: 1/2 volume (128-159)
    //   5: 5/8 volume (160-191)
    //   6: 3/4 volume (192-223)
    //   7: Full volume (224-255)

    // Bit-shift volume scaling based on volume register
    reg [7:0] volume_scaled;
    always @(posedge clk or negedge system_rst_n) begin
        if (!system_rst_n) begin
            volume_scaled <= 8'h00;
        end else begin
            case (reg_volume[7:5])  // Use top 3 bits for 8 discrete levels
                3'd0: volume_scaled <= 8'h00;                                          // Mute
                3'd1: volume_scaled <= wavetable_out >> 3;                             // 1/8 volume
                3'd2: volume_scaled <= wavetable_out >> 2;                             // 1/4 volume
                3'd3: volume_scaled <= (wavetable_out >> 2) + (wavetable_out >> 3);   // 3/8 volume
                3'd4: volume_scaled <= wavetable_out >> 1;                             // 1/2 volume
                3'd5: volume_scaled <= (wavetable_out >> 1) + (wavetable_out >> 3);   // 5/8 volume
                3'd6: volume_scaled <= (wavetable_out >> 1) + (wavetable_out >> 2);   // 3/4 volume
                3'd7: volume_scaled <= wavetable_out;                                  // Full volume
            endcase
        end
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
    assign uo_out[3] = stream_mode;       // Mode indicator (0=wavetable, 1=streaming)
    assign uo_out[7:4] = 4'b0000;         // Reserved/unused outputs

endmodule
