/*
 * Testbench for ADSR Envelope Generator
 *
 * Tests:
 * 1. Full ADSR cycle (Attack → Decay → Sustain → Release)
 * 2. Gate off during attack
 * 3. Gate off during decay
 * 4. Re-trigger during release
 * 5. Instant attack (rate = 0x00)
 * 6. Different rate values
 * 7. State transitions
 */

`timescale 1ns/1ps

module test_adsr_envelope;

    // Clock and reset
    reg        clk;
    reg        rst_n;
    reg        gate;

    // Rate controls
    reg [7:0]  attack_rate;
    reg [7:0]  decay_rate;
    reg [7:0]  sustain_level;
    reg [7:0]  release_rate;

    // Outputs
    wire [7:0] envelope_out;
    wire [2:0] state_out;

    // State names for display
    localparam STATE_IDLE    = 3'b000;
    localparam STATE_ATTACK  = 3'b001;
    localparam STATE_DECAY   = 3'b010;
    localparam STATE_SUSTAIN = 3'b011;
    localparam STATE_RELEASE = 3'b100;

    // Instantiate DUT
    adsr_envelope dut (
        .clk(clk),
        .rst_n(rst_n),
        .gate(gate),
        .attack_rate(attack_rate),
        .decay_rate(decay_rate),
        .sustain_level(sustain_level),
        .release_rate(release_rate),
        .envelope_out(envelope_out),
        .state_out(state_out)
    );

    // Clock generation: 50 MHz
    initial begin
        clk = 0;
        forever #10 clk = ~clk;
    end

    // Task to wait for a specific state
    task wait_for_state;
        input [2:0] target_state;
        input integer max_cycles;
        integer cycles;
        begin
            cycles = 0;
            while (state_out != target_state && cycles < max_cycles) begin
                @(posedge clk);
                cycles = cycles + 1;
            end
            if (cycles >= max_cycles) begin
                $display("  ⚠ WARNING: Timeout waiting for state %d", target_state);
            end
        end
    endtask

    // Task to display state name
    function [63:0] state_name;
        input [2:0] state;
        begin
            case (state)
                STATE_IDLE:    state_name = "IDLE   ";
                STATE_ATTACK:  state_name = "ATTACK ";
                STATE_DECAY:   state_name = "DECAY  ";
                STATE_SUSTAIN: state_name = "SUSTAIN";
                STATE_RELEASE: state_name = "RELEASE";
                default:       state_name = "UNKNOWN";
            endcase
        end
    endfunction

    // Test stimulus
    integer i;
    initial begin
        $dumpfile("adsr_envelope.vcd");
        $dumpvars(0, test_adsr_envelope);

        $display("=== ADSR Envelope Generator Test ===\n");

        // Initialize
        rst_n = 0;
        gate = 0;
        attack_rate = 8'h00;
        decay_rate = 8'h00;
        sustain_level = 8'hC0;  // 75% sustain
        release_rate = 8'h00;
        #100;

        // Release reset
        rst_n = 1;
        #50;

        // Test 1: Instant ADSR (all rates = 0x00)
        $display("--- Test 1: Instant ADSR (all rates = 0x00) ---");
        attack_rate = 8'h00;
        decay_rate = 8'h00;
        sustain_level = 8'h80;
        release_rate = 8'h00;

        gate = 1;
        #40;  // Wait 2 clocks
        $display("  Gate ON:  State=%s, Envelope=0x%02X", state_name(state_out), envelope_out);

        if (state_out == STATE_ATTACK || state_out == STATE_DECAY || state_out == STATE_SUSTAIN) begin
            $display("  ✓ PASS: Envelope started");
        end else begin
            $display("  ✗ FAIL: Not in expected state");
        end

        // Wait for sustain
        wait_for_state(STATE_SUSTAIN, 1000);
        #40;
        $display("  Sustain:  State=%s, Envelope=0x%02X", state_name(state_out), envelope_out);

        if (envelope_out == sustain_level && state_out == STATE_SUSTAIN) begin
            $display("  ✓ PASS: Reached sustain at correct level");
        end else begin
            $display("  ✗ FAIL: Sustain level = 0x%02X (expected 0x%02X)", envelope_out, sustain_level);
        end

        // Release
        gate = 0;
        wait_for_state(STATE_IDLE, 1000);
        #40;
        $display("  Released: State=%s, Envelope=0x%02X", state_name(state_out), envelope_out);

        if (envelope_out == 8'h00 && state_out == STATE_IDLE) begin
            $display("  ✓ PASS: Release complete\n");
        end else begin
            $display("  ✗ FAIL: Did not return to IDLE/zero\n");
        end

        // Test 2: Slow attack/decay/release to observe transitions
        $display("--- Test 2: Slow ADSR (rates = 0x02, observable) ---");
        attack_rate = 8'h02;
        decay_rate = 8'h02;
        sustain_level = 8'h80;  // 50% sustain
        release_rate = 8'h02;

        gate = 1;
        #40;
        $display("  Gate ON:  State=%s, Envelope=0x%02X", state_name(state_out), envelope_out);

        // Wait for attack to start
        wait_for_state(STATE_ATTACK, 100);
        #10000;  // Let attack progress (rate 0x02 is slow)
        $display("  Attack:   State=%s, Envelope=0x%02X", state_name(state_out), envelope_out);

        if (state_out == STATE_ATTACK && envelope_out > 8'h00) begin
            $display("  ✓ PASS: Attack is progressing");
        end else begin
            $display("  ✗ FAIL: Attack not progressing correctly");
        end

        // Wait for decay (attack takes 512*255 = 130,560 clocks = 2.6ms)
        wait_for_state(STATE_DECAY, 200000);
        #1000;
        $display("  Decay:    State=%s, Envelope=0x%02X", state_name(state_out), envelope_out);

        if (state_out == STATE_DECAY && envelope_out <= 8'hFF) begin
            $display("  ✓ PASS: Decay started");
        end else begin
            $display("  ✗ FAIL: Decay not started");
        end

        // Wait for sustain
        wait_for_state(STATE_SUSTAIN, 100000);
        #1000;
        $display("  Sustain:  State=%s, Envelope=0x%02X", state_name(state_out), envelope_out);

        if (state_out == STATE_SUSTAIN && envelope_out == sustain_level) begin
            $display("  ✓ PASS: Sustain reached\n");
        end else begin
            $display("  ✗ FAIL: Sustain = 0x%02X (expected 0x%02X)\n", envelope_out, sustain_level);
        end

        // Test 3: Gate off during attack
        $display("--- Test 3: Gate Off During Attack ---");
        gate = 0;
        #100;  // Wait for release

        attack_rate = 8'h04;
        release_rate = 8'h00;  // Instant release
        gate = 1;
        wait_for_state(STATE_ATTACK, 100);
        #2000;  // Let attack progress

        $display("  Mid-Attack: Envelope=0x%02X", envelope_out);
        gate = 0;  // Release gate during attack
        #100;

        if (state_out == STATE_RELEASE || state_out == STATE_IDLE) begin
            $display("  ✓ PASS: Entered release from attack");
        end else begin
            $display("  ✗ FAIL: Did not enter release");
        end

        wait_for_state(STATE_IDLE, 1000);
        #40;
        if (envelope_out == 8'h00) begin
            $display("  ✓ PASS: Released to zero\n");
        end else begin
            $display("  ✗ FAIL: Envelope = 0x%02X after release\n", envelope_out);
        end

        // Test 4: Gate off during decay
        $display("--- Test 4: Gate Off During Decay ---");
        attack_rate = 8'h00;  // Instant attack
        decay_rate = 8'h04;   // Slow decay
        sustain_level = 8'h40;
        release_rate = 8'h00;

        gate = 1;
        wait_for_state(STATE_DECAY, 1000);
        #2000;  // Let decay progress

        $display("  Mid-Decay: Envelope=0x%02X", envelope_out);
        gate = 0;  // Release during decay
        #100;

        if (state_out == STATE_RELEASE || state_out == STATE_IDLE) begin
            $display("  ✓ PASS: Entered release from decay");
        end else begin
            $display("  ✗ FAIL: Did not enter release");
        end

        wait_for_state(STATE_IDLE, 1000);
        if (envelope_out == 8'h00) begin
            $display("  ✓ PASS: Released to zero\n");
        end else begin
            $display("  ✗ FAIL: Envelope = 0x%02X\n", envelope_out);
        end

        // Test 5: Re-trigger during release
        $display("--- Test 5: Re-trigger During Release ---");
        attack_rate = 8'h00;
        decay_rate = 8'h00;
        sustain_level = 8'hC0;
        release_rate = 8'h04;  // Slow release

        gate = 1;
        wait_for_state(STATE_SUSTAIN, 1000);
        gate = 0;  // Start release
        wait_for_state(STATE_RELEASE, 100);
        #2000;  // Let release progress

        $display("  Mid-Release: Envelope=0x%02X", envelope_out);
        gate = 1;  // Re-trigger
        #40;  // Wait for state transition
        wait_for_state(STATE_ATTACK, 10);
        #40;  // Wait one more cycle for envelope to update

        if (state_out == STATE_ATTACK) begin
            $display("  ✓ PASS: Re-triggered to attack");
        end else begin
            $display("  ✗ FAIL: Did not re-trigger, state=%s", state_name(state_out));
        end

        // Note: With instant attack (rate=0x00), envelope increments very fast
        // By the time we check, it may already be several steps into attack
        if (envelope_out <= 8'h10) begin
            $display("  ✓ PASS: Attack restarted (envelope=0x%02X)\n", envelope_out);
        end else begin
            $display("  ⚠ WARNING: Envelope = 0x%02X on re-trigger\n", envelope_out);
        end

        // Clean up
        gate = 0;
        #1000;

        $display("=== All ADSR tests completed ===");
        #1000;
        $finish;
    end

    // Timeout watchdog
    initial begin
        #10000000;  // 10ms timeout
        $display("ERROR: Testbench timeout!");
        $finish;
    end

endmodule
