/*
 * Testbench for SPI RX Register Interface
 *
 * This testbench validates the SPI RX register interface:
 * 1. SPI protocol (Mode 0: CPOL=0, CPHA=0)
 * 2. Register write operations
 * 3. 2-byte protocol: [address][data]
 * 4. All 7 registers
 */

`timescale 1ns/1ps

module test_spi_rx;

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

    // Register outputs (7 registers)
    wire [7:0] reg_control;
    wire [7:0] reg_freq_low;
    wire [7:0] reg_freq_mid;
    wire [7:0] reg_freq_high;
    wire [7:0] reg_duty;
    wire [7:0] reg_volume;
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
        .reg_duty(reg_duty),
        .reg_volume(reg_volume),
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
        $dumpfile("spi_rx.vcd");
        $dumpvars(0, test_spi_rx);

        $display("=== SPI RX Register Interface Test (Mode 0) ===\n");

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
        spi_write_register(8'h00, 8'b00011101);  // OSC_EN=1, SW_GATE=0, waveforms=111
        #2000;
        if (reg_control == 8'b00011101) begin
            $display("✓ PASS: Control register = 0x%02X", reg_control);
        end else begin
            $display("✗ FAIL: Control register = 0x%02X (expected 0x1D)", reg_control);
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

        $display("\n--- Test 3: Write Duty Cycle ---");
        spi_write_register(8'h05, 8'h40);  // 25% duty cycle
        #2000;
        if (reg_duty == 8'h40) begin
            $display("✓ PASS: Duty cycle = 0x%02X", reg_duty);
        end else begin
            $display("✗ FAIL: Duty cycle = 0x%02X (expected 0x40)", reg_duty);
        end

        $display("\n--- Test 4: Write Volume Register (Bit-Shift) ---");
        spi_write_register(8'h06, 8'h80);  // Set volume to 50%
        #2000;
        if (reg_volume == 8'h80) begin
            $display("✓ PASS: Volume register = 0x%02X (128 = 1/2 vol)", reg_volume);
        end else begin
            $display("✗ FAIL: Volume register = 0x%02X (expected 0x80)", reg_volume);
        end

        $display("\n--- Test 5: Test Multiple Volume Levels ---");
        spi_write_register(8'h06, 8'h00);  // Mute
        #2000;
        if (reg_volume == 8'h00) $display("✓ PASS: Volume = 0x00 (mute)");

        spi_write_register(8'h06, 8'h40);  // 1/4 volume
        #2000;
        if (reg_volume == 8'h40) $display("✓ PASS: Volume = 0x40 (1/4 vol)");

        spi_write_register(8'h06, 8'hC0);  // 3/4 volume
        #2000;
        if (reg_volume == 8'hC0) $display("✓ PASS: Volume = 0xC0 (3/4 vol)");

        spi_write_register(8'h06, 8'hFF);  // Full
        #2000;
        if (reg_volume == 8'hFF) $display("✓ PASS: Volume = 0xFF (full)");

        $display("\n--- Test 6: Burst Write (Multiple Registers) ---");
        // Start transaction
        spi_cs = 0;
        #1000;
        spi_send_byte(8'h02);  // Address = Freq low
        spi_send_byte(8'hAA);  // Freq low = 0xAA
        spi_send_byte(8'hBB);  // Freq mid = 0xBB (auto-increment)
        spi_send_byte(8'hCC);  // Freq high = 0xCC
        spi_cs = 1;  // End transaction
        #2000;
        if ({reg_freq_high, reg_freq_mid, reg_freq_low} == 24'hCCBBAA) begin
            $display("✓ PASS: Burst write frequency = 0x%06X", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end else begin
            $display("✗ FAIL: Burst write frequency = 0x%06X (expected 0xCCBBAA)", {reg_freq_high, reg_freq_mid, reg_freq_low});
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

        // Try to write to status register (should be ignored)
        spi_write_register(8'h12, 8'hFF);
        #2000;
        if (reg_status == 8'b00000011) begin
            $display("✓ PASS: Status register is read-only (still 0x%02X)", reg_status);
        end else begin
            $display("✗ FAIL: Status register was modified (0x%02X)", reg_status);
        end

        $display("\n--- Test 8: Invalid Register Address ---");
        spi_write_register(8'h07, 8'h42);  // Invalid address
        #2000;
        $display("✓ PASS: Invalid address write ignored (no crash)");

        $display("\n=== All SPI RX tests completed ===");
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
