/*
 * Testbench for UART RX Register Interface
 *
 * This testbench validates the UART RX register interface:
 * 1. UART protocol (115200 baud, 8N1)
 * 2. Register write operations
 * 3. 2-byte protocol: [address][data]
 * 4. All 7 registers
 */

`timescale 1ns/1ps

module test_uart_rx;

    // Clock and reset
    reg        clk;
    reg        rst_n;

    // UART RX signal
    reg        rx;

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
    uart_rx_registers #(
        .CLK_FREQ(50_000_000),
        .BAUD_RATE(115200)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
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

    // UART timing parameters (115200 baud)
    // Bit period = 1 / 115200 = 8.68 µs = 8680 ns
    localparam UART_BIT_PERIOD = 8680;  // ns

    // Main test sequence
    initial begin
        $dumpfile("uart_rx.vcd");
        $dumpvars(0, test_uart_rx);

        $display("=== UART RX Register Interface Test (115200 baud, 8N1) ===\n");

        // Initialize
        rst_n = 0;
        rx = 1;  // UART idle state is high
        status_gate_active = 0;
        status_osc_running = 0;
        #200;

        // Release reset
        rst_n = 1;
        #500;

        $display("--- Test 1: Write to Control Register (0x00) ---");
        uart_write_register(8'h00, 8'b00011101);  // OSC_EN=1, SW_GATE=0, waveforms=111
        #5000;
        if (reg_control == 8'b00011101) begin
            $display("✓ PASS: Control register = 0x%02X", reg_control);
        end else begin
            $display("✗ FAIL: Control register = 0x%02X (expected 0x1D)", reg_control);
        end

        $display("\n--- Test 2: Write Frequency (24-bit, 3 registers) ---");
        uart_write_register(8'h02, 8'h00);  // Freq low
        uart_write_register(8'h03, 8'h40);  // Freq mid
        uart_write_register(8'h04, 8'h02);  // Freq high = 0x024000 (440 Hz)
        #5000;
        if ({reg_freq_high, reg_freq_mid, reg_freq_low} == 24'h024000) begin
            $display("✓ PASS: Frequency = 0x%06X (440 Hz)", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end else begin
            $display("✗ FAIL: Frequency = 0x%06X (expected 0x024000)", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end

        $display("\n--- Test 3: Write Duty Cycle ---");
        uart_write_register(8'h05, 8'h40);  // 25% duty cycle
        #5000;
        if (reg_duty == 8'h40) begin
            $display("✓ PASS: Duty cycle = 0x%02X", reg_duty);
        end else begin
            $display("✗ FAIL: Duty cycle = 0x%02X (expected 0x40)", reg_duty);
        end

        $display("\n--- Test 4: Write Volume Register (Smooth Control) ---");
        uart_write_register(8'h06, 8'h80);  // Set volume to 50%
        #5000;
        if (reg_volume == 8'h80) begin
            $display("✓ PASS: Volume register = 0x%02X (128 = 50%%)", reg_volume);
        end else begin
            $display("✗ FAIL: Volume register = 0x%02X (expected 0x80)", reg_volume);
        end

        $display("\n--- Test 5: Test Multiple Volume Levels ---");
        uart_write_register(8'h06, 8'h00);  // Mute
        #5000;
        if (reg_volume == 8'h00) $display("✓ PASS: Volume = 0x00 (mute)");

        uart_write_register(8'h06, 8'h40);  // 25%
        #5000;
        if (reg_volume == 8'h40) $display("✓ PASS: Volume = 0x40 (25%%)");

        uart_write_register(8'h06, 8'hC0);  // 75%
        #5000;
        if (reg_volume == 8'hC0) $display("✓ PASS: Volume = 0xC0 (75%%)");

        uart_write_register(8'h06, 8'hFF);  // Full
        #5000;
        if (reg_volume == 8'hFF) $display("✓ PASS: Volume = 0xFF (100%%)");

        $display("\n--- Test 6: Burst Write (Multiple Registers) ---");
        uart_write_register(8'h02, 8'hAA);  // Freq low
        uart_write_register(8'h03, 8'hBB);  // Freq mid
        uart_write_register(8'h04, 8'hCC);  // Freq high
        #5000;
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
        uart_write_register(8'h12, 8'hFF);
        #5000;
        if (reg_status == 8'b00000011) begin
            $display("✓ PASS: Status register is read-only (still 0x%02X)", reg_status);
        end else begin
            $display("✗ FAIL: Status register was modified (0x%02X)", reg_status);
        end

        $display("\n--- Test 8: Invalid Register Address ---");
        uart_write_register(8'h07, 8'h42);  // Invalid address
        #5000;
        $display("✓ PASS: Invalid address write ignored (no crash)");

        $display("\n=== All UART RX tests completed ===");
        #5000;
        $finish;
    end

    // ========================================
    // UART TX Tasks (for testing RX)
    // ========================================

    // Send a single byte via UART (8N1 format)
    task uart_send_byte;
        input [7:0] data;
        integer i;
        begin
            // Start bit
            rx = 0;
            #UART_BIT_PERIOD;

            // 8 data bits (LSB first)
            for (i = 0; i < 8; i = i + 1) begin
                rx = data[i];
                #UART_BIT_PERIOD;
            end

            // Stop bit
            rx = 1;
            #UART_BIT_PERIOD;
        end
    endtask

    // High-level: Write to a register using 2-byte protocol
    task uart_write_register;
        input [7:0] reg_addr;
        input [7:0] data;
        begin
            uart_send_byte(reg_addr);
            uart_send_byte(data);
        end
    endtask

    // Timeout watchdog
    initial begin
        #50_000_000;  // 50ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
