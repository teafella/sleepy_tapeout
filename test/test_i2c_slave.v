/*
 * Testbench for I2C Slave Interface (Minimal Version)
 *
 * This testbench validates the minimal 6-register I2C interface:
 * 1. I2C protocol (START, STOP, ACK, NACK)
 * 2. Address matching
 * 3. Register write operations
 * 4. Register read operations
 * 5. Burst write and read
 * 6. Read-only status register
 */

`timescale 1ns/1ps

module test_i2c_slave;

    // Clock and reset
    reg        clk;
    reg        rst_n;

    // I2C bus signals
    reg        scl_drive;
    reg        sda_drive;
    wire       scl_in;
    wire       sda_in;
    wire       sda_out;
    wire       sda_oe;

    // I2C open-drain emulation
    assign scl_in = scl_drive;
    assign sda_in = sda_drive & (~sda_oe | sda_out);  // Slave can pull low

    // Status inputs
    reg        status_gate_active;
    reg        status_osc_running;

    // Register outputs (6 registers only)
    wire [7:0] reg_control;
    wire [7:0] reg_freq_low;
    wire [7:0] reg_freq_mid;
    wire [7:0] reg_freq_high;
    wire [7:0] reg_duty;
    wire [7:0] reg_status;

    // Instantiate DUT
    i2c_slave #(
        .I2C_ADDR(7'h50)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .scl_in(scl_in),
        .sda_in(sda_in),
        .sda_out(sda_out),
        .sda_oe(sda_oe),
        .reg_control(reg_control),
        .reg_freq_low(reg_freq_low),
        .reg_freq_mid(reg_freq_mid),
        .reg_freq_high(reg_freq_high),
        .reg_duty(reg_duty),
        .reg_status(reg_status),
        .status_gate_active(status_gate_active),
        .status_osc_running(status_osc_running)
    );

    // Clock generation: 50 MHz (20ns period)
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // I2C timing parameters (100 kHz Standard Mode)
    localparam I2C_PERIOD = 10000;      // 10us = 100kHz
    localparam I2C_HALF = I2C_PERIOD/2; // 5us

    // Test variables
    integer i;
    reg [7:0] read_data;
    reg ack_bit;

    // Main test sequence
    initial begin
        $dumpfile("i2c_slave.vcd");
        $dumpvars(0, test_i2c_slave);

        $display("=== I2C Slave Interface Test (Minimal 6-Register Version) ===\n");

        // Initialize
        rst_n = 0;
        scl_drive = 1;
        sda_drive = 1;
        status_gate_active = 0;
        status_osc_running = 0;
        #200;

        // Release reset
        rst_n = 1;
        #500;

        $display("--- Test 1: Address Match (should ACK) ---");
        i2c_start();
        i2c_write_byte(8'hA0, ack_bit);  // Address 0x50, Write
        if (ack_bit == 0) begin
            $display("✓ PASS: Address matched, ACK received");
        end else begin
            $display("✗ FAIL: No ACK for correct address");
        end
        i2c_stop();
        #1000;

        $display("\n--- Test 2: Address Mismatch (should NACK) ---");
        i2c_start();
        i2c_write_byte(8'h42, ack_bit);  // Wrong address
        if (ack_bit == 1) begin
            $display("✓ PASS: Wrong address ignored (NACK)");
        end else begin
            $display("✗ FAIL: Wrong address was ACKed");
        end
        i2c_stop();
        #1000;

        $display("\n--- Test 3: Write to Control Register (0x00) ---");
        i2c_write_register(8'h00, 8'b00011101);  // OSC_EN=1, SW_GATE=0, waveforms=111
        #500;
        if (reg_control == 8'b00011101) begin
            $display("✓ PASS: Control register = 0x%02X", reg_control);
        end else begin
            $display("✗ FAIL: Control register = 0x%02X (expected 0x1D)", reg_control);
        end

        $display("\n--- Test 4: Write Frequency (24-bit, 3 registers) ---");
        i2c_write_register(8'h02, 8'h00);  // Freq low
        i2c_write_register(8'h03, 8'h40);  // Freq mid
        i2c_write_register(8'h04, 8'h02);  // Freq high = 0x024000 (440 Hz)
        #500;
        if ({reg_freq_high, reg_freq_mid, reg_freq_low} == 24'h024000) begin
            $display("✓ PASS: Frequency = 0x%06X (440 Hz)", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end else begin
            $display("✗ FAIL: Frequency = 0x%06X (expected 0x024000)", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end

        $display("\n--- Test 5: Write Duty Cycle ---");
        i2c_write_register(8'h05, 8'h40);  // 25% duty cycle
        #500;
        if (reg_duty == 8'h40) begin
            $display("✓ PASS: Duty cycle = 0x%02X", reg_duty);
        end else begin
            $display("✗ FAIL: Duty cycle = 0x%02X (expected 0x40)", reg_duty);
        end

        $display("\n--- Test 6: Burst Write (Frequency registers) ---");
        i2c_start();
        i2c_write_byte(8'hA0, ack_bit);   // Address + Write
        i2c_write_byte(8'h02, ack_bit);   // Reg addr = 0x02 (Freq low)
        i2c_write_byte(8'hAA, ack_bit);   // Freq low = 0xAA
        i2c_write_byte(8'hBB, ack_bit);   // Freq mid = 0xBB (auto-increment)
        i2c_write_byte(8'hCC, ack_bit);   // Freq high = 0xCC
        i2c_stop();
        #500;
        if ({reg_freq_high, reg_freq_mid, reg_freq_low} == 24'hCCBBAA) begin
            $display("✓ PASS: Burst write frequency = 0x%06X", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end else begin
            $display("✗ FAIL: Burst write frequency = 0x%06X (expected 0xCCBBAA)", {reg_freq_high, reg_freq_mid, reg_freq_low});
        end

        $display("\n--- Test 7: Read from Register ---");
        i2c_write_register(8'h05, 8'hA5);  // Write test pattern to duty
        #500;
        i2c_read_register(8'h05, read_data);
        #500;
        if (read_data == 8'hA5) begin
            $display("✓ PASS: Read duty = 0x%02X", read_data);
        end else begin
            $display("✗ FAIL: Read duty = 0x%02X (expected 0xA5)", read_data);
        end

        $display("\n--- Test 8: Read Status Register (read-only) ---");
        status_gate_active = 1;
        status_osc_running = 1;
        #500;
        i2c_read_register(8'h12, read_data);
        #500;
        $display("Status register: 0x%02X", read_data);
        if (read_data == 8'b00000011) begin  // [1]=osc_running, [0]=gate_active
            $display("✓ PASS: Status reflects input signals");
        end else begin
            $display("✗ FAIL: Status = 0x%02X (expected 0x03)", read_data);
        end

        $display("\n--- Test 9: Burst Read (Frequency registers) ---");
        i2c_write_register(8'h02, 8'h11);  // Set known values
        i2c_write_register(8'h03, 8'h22);
        i2c_write_register(8'h04, 8'h33);
        #500;

        i2c_start();
        i2c_write_byte(8'hA0, ack_bit);   // Address + Write
        i2c_write_byte(8'h02, ack_bit);   // Set read pointer to 0x02
        i2c_start();                       // Repeated START
        i2c_write_byte(8'hA1, ack_bit);   // Address + Read
        i2c_read_byte(read_data, 1'b0);   // Read with ACK
        $display("Freq[7:0] = 0x%02X", read_data);
        i2c_read_byte(read_data, 1'b0);   // Read with ACK
        $display("Freq[15:8] = 0x%02X", read_data);
        i2c_read_byte(read_data, 1'b1);   // Read with NACK (last byte)
        $display("Freq[23:16] = 0x%02X", read_data);
        i2c_stop();
        if (read_data == 8'h33) begin
            $display("✓ PASS: Burst read successful");
        end else begin
            $display("✗ FAIL: Burst read failed");
        end

        $display("\n--- Test 10: Verify Read-Only Status Register ---");
        // Try to write to status register (should be ignored)
        i2c_write_register(8'h12, 8'hFF);
        #500;
        i2c_read_register(8'h12, read_data);
        #500;
        if (read_data == 8'b00000011) begin  // Should still reflect status inputs
            $display("✓ PASS: Status register is read-only (0x%02X)", read_data);
        end else begin
            $display("✗ FAIL: Status register was written (0x%02X)", read_data);
        end

        $display("\n--- Test 11: Invalid Register Address ---");
        i2c_write_register(8'h07, 8'h42);  // Invalid address (removed ADSR registers)
        #500;
        i2c_read_register(8'h07, read_data);
        #500;
        if (read_data == 8'hFF) begin
            $display("✓ PASS: Invalid address returns 0xFF");
        end else begin
            $display("⚠ WARNING: Invalid address returns 0x%02X", read_data);
        end

        $display("\n=== All I2C tests completed ===");
        #2000;
        $finish;
    end

    // ========================================
    // I2C Master Tasks
    // ========================================

    // Generate START condition
    task i2c_start;
        begin
            sda_drive = 1;
            scl_drive = 1;
            #I2C_HALF;
            sda_drive = 0;  // SDA falls while SCL high
            #I2C_HALF;
            scl_drive = 0;
            #I2C_HALF;
        end
    endtask

    // Generate STOP condition
    task i2c_stop;
        begin
            sda_drive = 0;
            scl_drive = 0;
            #I2C_HALF;
            scl_drive = 1;
            #I2C_HALF;
            sda_drive = 1;  // SDA rises while SCL high
            #I2C_HALF;
        end
    endtask

    // Write a byte on I2C bus
    task i2c_write_byte;
        input [7:0] data;
        output ack;
        integer j;
        begin
            // Send 8 data bits (MSB first)
            for (j = 7; j >= 0; j = j - 1) begin
                sda_drive = data[j];
                #I2C_HALF;
                scl_drive = 1;
                #I2C_PERIOD;
                scl_drive = 0;
                #I2C_HALF;
            end

            // Read ACK bit
            sda_drive = 1;  // Release SDA
            #I2C_HALF;
            scl_drive = 1;
            #(I2C_HALF/2);
            ack = sda_in;
            #(I2C_HALF/2);
            scl_drive = 0;
            #I2C_HALF;
        end
    endtask

    // Read a byte from I2C bus
    task i2c_read_byte;
        output [7:0] data;
        input ack;
        integer j;
        begin
            sda_drive = 1;  // Release SDA
            data = 8'h00;

            // Read 8 data bits (MSB first)
            for (j = 7; j >= 0; j = j - 1) begin
                #I2C_HALF;
                scl_drive = 1;
                #(I2C_HALF/2);
                data[j] = sda_in;
                #(I2C_HALF/2);
                scl_drive = 0;
                #I2C_HALF;
            end

            // Send ACK/NACK
            sda_drive = ack;
            #I2C_HALF;
            scl_drive = 1;
            #I2C_PERIOD;
            scl_drive = 0;
            #I2C_HALF;
            sda_drive = 1;
        end
    endtask

    // High-level: Write to a register
    task i2c_write_register;
        input [7:0] reg_addr;
        input [7:0] data;
        reg ack1, ack2, ack3;
        begin
            i2c_start();
            i2c_write_byte(8'hA0, ack1);  // Device address + Write
            i2c_write_byte(reg_addr, ack2);
            i2c_write_byte(data, ack3);
            i2c_stop();
        end
    endtask

    // High-level: Read from a register
    task i2c_read_register;
        input [7:0] reg_addr;
        output [7:0] data;
        reg ack1, ack2, ack3;
        begin
            // Set register pointer
            i2c_start();
            i2c_write_byte(8'hA0, ack1);  // Device address + Write
            i2c_write_byte(reg_addr, ack2);

            // Read data
            i2c_start();  // Repeated START
            i2c_write_byte(8'hA1, ack3);  // Device address + Read
            i2c_read_byte(data, 1'b1);     // Read with NACK
            i2c_stop();
        end
    endtask

    // Timeout watchdog
    initial begin
        #50000000;  // 50ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
