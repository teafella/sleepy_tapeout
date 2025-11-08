/*
 * Testbench for SPI RX Register Interface (Wavetable Synth)
 *
 * This testbench validates the wavetable synthesizer SPI interface:
 * 1. SPI protocol (Mode 0: CPOL=0, CPHA=0)
 * 2. Register write operations
 * 3. Wavetable loading (8 samples)
 * 4. Control register (OSC_EN, STREAM_MODE, SW_GATE)
 * 5. Frequency, volume, status registers
 */

`timescale 1ns/1ps

module test_spi_wavetable;

    // Clock and reset
    reg        clk;
    reg        rst_n;

    // SPI signals
    reg        spi_mosi;
    reg        spi_sck;
    reg        spi_cs;

    // Status inputs
    reg        status_gate_active;
    reg        status_osc_running;

    // Register outputs (12 registers)
    wire [7:0] reg_control;
    wire [7:0] reg_freq_low;
    wire [7:0] reg_freq_mid;
    wire [7:0] reg_freq_high;
    wire [7:0] reg_volume;
    wire [7:0] reg_wavetable_0;
    wire [7:0] reg_wavetable_1;
    wire [7:0] reg_wavetable_2;
    wire [7:0] reg_wavetable_3;
    wire [7:0] reg_wavetable_4;
    wire [7:0] reg_wavetable_5;
    wire [7:0] reg_wavetable_6;
    wire [7:0] reg_wavetable_7;
    wire [7:0] reg_status;

    // Instantiate DUT
    spi_rx_registers dut (
        .clk(clk),
        .rst_n(rst_n),
        .spi_mosi(spi_mosi),
        .spi_sck(spi_sck),
        .spi_cs(spi_cs),
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
        .status_gate_active(status_gate_active),
        .status_osc_running(status_osc_running)
    );

    // Clock generation: 50 MHz (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // SPI timing parameters (1 MHz SPI clock = 1us period)
    localparam SPI_HALF_PERIOD = 500;  // 500ns = 1 MHz SPI clock

    // Main test sequence
    initial begin
        $dumpfile("spi_wavetable.vcd");
        $dumpvars(0, test_spi_wavetable);

        $display("=== Wavetable Synthesizer SPI Test ===\n");

        // Initialize
        rst_n = 0;
        spi_mosi = 0;
        spi_sck = 0;
        spi_cs = 1;  // CS idle high
        status_gate_active = 0;
        status_osc_running = 0;
        #200;

        // Release reset
        rst_n = 1;
        #500;

        $display("--- Test 1: Write to Control Register (0x00) ---");
        spi_write_register(8'h00, 8'b00000001);  // OSC_EN=1, STREAM_MODE=0, SW_GATE=0
        #2000;
        if (reg_control == 8'b00000001) begin
            $display("✓ PASS: Control register = 0x%02X (OSC enabled)", reg_control);
        end else begin
            $display("✗ FAIL: Control register = 0x%02X (expected 0x01)", reg_control);
        end

        $display("\n--- Test 2: Write Frequency (24-bit, 3 registers) ---");
        spi_write_register(8'h02, 8'h00);  // Freq low
        spi_write_register(8'h03, 8'h40);  // Freq mid
        spi_write_register(8'h04, 8'h02);  // Freq high = 0x024000 (440 Hz)
        #2000;
        if ({reg_freq_high, reg_freq_mid, reg_freq_low} == 24'h024000) begin
            $display("✓ PASS: Frequency = 0x%06X (440 Hz)", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end else begin
            $display("✗ FAIL: Frequency = 0x%06X (expected 0x024000)", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end

        $display("\n--- Test 3: Write Volume Register ---");
        spi_write_register(8'h05, 8'h80);  // Set volume to 50%
        #2000;
        if (reg_volume == 8'h80) begin
            $display("✓ PASS: Volume = 0x%02X (128 = 1/2 vol)", reg_volume);
        end else begin
            $display("✗ FAIL: Volume = 0x%02X (expected 0x80)", reg_volume);
        end

        $display("\n--- Test 4: Load Wavetable (8 samples) ---");
        // Load sawtooth waveform
        spi_write_register(8'h10, 8'd0);
        spi_write_register(8'h11, 8'd36);
        spi_write_register(8'h12, 8'd73);
        spi_write_register(8'h13, 8'd109);
        spi_write_register(8'h14, 8'd146);
        spi_write_register(8'h15, 8'd182);
        spi_write_register(8'h16, 8'd219);
        spi_write_register(8'h17, 8'd255);
        #2000;
        if (reg_wavetable_0 == 8'd0 && reg_wavetable_7 == 8'd255) begin
            $display("✓ PASS: Wavetable loaded (saw: 0 → 255)");
        end else begin
            $display("✗ FAIL: Wavetable = %d...%d (expected 0...255)", reg_wavetable_0, reg_wavetable_7);
        end

        $display("\n--- Test 5: Burst Write to Wavetable ---");
        // Burst write triangle waveform
        spi_cs = 0;
        #1000;
        spi_send_byte(8'h10);  // Address = wavetable[0]
        spi_send_byte(8'd0);    // Triangle: rising
        spi_send_byte(8'd73);
        spi_send_byte(8'd146);
        spi_send_byte(8'd219);
        spi_send_byte(8'd255);  // Peak
        spi_send_byte(8'd219);  // Falling
        spi_send_byte(8'd146);
        spi_send_byte(8'd73);
        spi_cs = 1;
        #2000;
        if (reg_wavetable_0 == 8'd0 && reg_wavetable_4 == 8'd255 && reg_wavetable_7 == 8'd73) begin
            $display("✓ PASS: Triangle wavetable loaded via burst write");
        end else begin
            $display("✗ FAIL: Wavetable = %d, %d, %d", reg_wavetable_0, reg_wavetable_4, reg_wavetable_7);
        end

        $display("\n--- Test 6: Test STREAM_MODE bit ---");
        spi_write_register(8'h00, 8'b00000010);  // OSC_EN=0, STREAM_MODE=1, SW_GATE=0
        #2000;
        if (reg_control == 8'b00000010) begin
            $display("✓ PASS: STREAM_MODE enabled (control = 0x%02X)", reg_control);
        end else begin
            $display("✗ FAIL: Control = 0x%02X (expected 0x02)", reg_control);
        end

        $display("\n--- Test 7: Read-Only Status Register ---");
        status_gate_active = 1;
        status_osc_running = 1;
        #500;
        if (reg_status == 8'b00000011) begin
            $display("✓ PASS: Status = 0x%02X (gate=1, osc=1)", reg_status);
        end else begin
            $display("✗ FAIL: Status = 0x%02X (expected 0x03)", reg_status);
        end

        $display("\n=== All Wavetable SPI tests completed ===");
        #2000;
        $finish;
    end

    // ========================================
    // SPI Master Tasks (for testing RX slave)
    // ========================================

    // Send a single byte via SPI (Mode 0: CPOL=0, CPHA=0)
    task spi_send_byte;
        input [7:0] data;
        integer i;
        begin
            // Send 8 bits, MSB first
            for (i = 7; i >= 0; i = i - 1) begin
                spi_mosi = data[i];
                #SPI_HALF_PERIOD;
                spi_sck = 1;  // Rising edge - slave samples
                #SPI_HALF_PERIOD;
                spi_sck = 0;  // Falling edge
            end
            spi_mosi = 0;
        end
    endtask

    // High-level: Write to a register using 2-byte protocol
    task spi_write_register;
        input [7:0] reg_addr;
        input [7:0] data;
        begin
            spi_cs = 0;  // Assert chip select
            #1000;
            spi_send_byte(reg_addr);
            spi_send_byte(data);
            spi_cs = 1;  // Deassert chip select
            #1000;
        end
    endtask

    // Timeout watchdog
    initial begin
        #10_000_000;  // 10ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
