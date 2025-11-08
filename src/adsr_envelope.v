/*
 * ADSR Envelope Generator
 *
 * Full Attack-Decay-Sustain-Release envelope generator with gate control.
 *
 * State Machine:
 *   IDLE → ATTACK (on gate) → DECAY → SUSTAIN → RELEASE (on gate off) → IDLE
 *
 * Timing:
 *   - Attack: Envelope rises from 0 to 255
 *   - Decay: Envelope falls from 255 to sustain_level
 *   - Sustain: Envelope holds at sustain_level until gate off
 *   - Release: Envelope falls from current level to 0
 *
 * Rate Calculation:
 *   clocks_per_step = rate_value × 256
 *   At 50 MHz: time_per_step = (rate_value × 256) / 50,000,000
 *
 * Timing Examples (full 0→255 transition):
 *   - Rate 0x00: 20 ns (instant, 1 clock)
 *   - Rate 0x01: 1.31 ms (very fast)
 *   - Rate 0x10: 20.9 ms (medium, default attack)
 *   - Rate 0x20: 41.8 ms (medium-slow, default decay)
 *   - Rate 0x30: 62.7 ms (slow, default release)
 *   - Rate 0xFF: 333 ms (maximum)
 *
 * Resource Usage: ~135 cells (3.4% of 1x1 tile)
 */

module adsr_envelope (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        gate,           // Gate signal (HW pin or SW control)

    // Rate controls from I2C registers
    input  wire [7:0]  attack_rate,    // 0x00 = instant, 0xFF = slowest
    input  wire [7:0]  decay_rate,
    input  wire [7:0]  sustain_level,  // Target level for sustain (0-255)
    input  wire [7:0]  release_rate,

    // Outputs
    output reg  [7:0]  envelope_out,   // Current envelope value (0-255)
    output reg  [2:0]  state_out       // Current state for status register
);

    // ========================================
    // State Machine States
    // ========================================
    localparam STATE_IDLE    = 3'b000;
    localparam STATE_ATTACK  = 3'b001;
    localparam STATE_DECAY   = 3'b010;
    localparam STATE_SUSTAIN = 3'b011;
    localparam STATE_RELEASE = 3'b100;

    reg [2:0] state;

    // ========================================
    // Rate Counter
    // ========================================
    // Counts clocks between envelope updates
    // Rate × 256 = clocks per step
    reg [15:0] rate_counter;
    wire [15:0] rate_divider;

    // Select current rate based on state
    reg [7:0] current_rate;
    always @(*) begin
        case (state)
            STATE_ATTACK:  current_rate = attack_rate;
            STATE_DECAY:   current_rate = decay_rate;
            STATE_RELEASE: current_rate = release_rate;
            default:       current_rate = 8'h00;
        endcase
    end

    // Scale rate by 256 for timing
    assign rate_divider = {current_rate, 8'h00};

    // Counter tick signal
    wire counter_tick = (rate_counter == 16'h0000) || (current_rate == 8'h00);

    // ========================================
    // Gate Edge Detection
    // ========================================
    reg gate_prev;
    wire gate_rising = gate && !gate_prev;
    wire gate_falling = !gate && gate_prev;

    // ========================================
    // State Machine
    // ========================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            envelope_out <= 8'h00;
            rate_counter <= 16'h0000;
            gate_prev <= 1'b0;
        end else begin
            // Update gate edge detection
            gate_prev <= gate;

            // Update rate counter
            if (counter_tick || state == STATE_IDLE || state == STATE_SUSTAIN) begin
                rate_counter <= rate_divider;
            end else begin
                rate_counter <= rate_counter - 16'h0001;
            end

            // State machine transitions
            case (state)
                STATE_IDLE: begin
                    envelope_out <= 8'h00;
                    if (gate_rising || gate) begin
                        state <= STATE_ATTACK;
                        envelope_out <= 8'h00;
                    end
                end

                STATE_ATTACK: begin
                    if (!gate) begin
                        // Gate released during attack, go to release
                        state <= STATE_RELEASE;
                    end else if (counter_tick) begin
                        if (envelope_out == 8'hFF) begin
                            // Attack complete, move to decay
                            state <= STATE_DECAY;
                        end else begin
                            // Increment envelope (saturate at 255)
                            envelope_out <= envelope_out + 8'h01;
                        end
                    end
                end

                STATE_DECAY: begin
                    if (!gate) begin
                        // Gate released during decay, go to release
                        state <= STATE_RELEASE;
                    end else if (counter_tick) begin
                        if (envelope_out <= sustain_level) begin
                            // Decay complete, move to sustain
                            envelope_out <= sustain_level;
                            state <= STATE_SUSTAIN;
                        end else begin
                            // Decrement envelope toward sustain level
                            envelope_out <= envelope_out - 8'h01;
                        end
                    end
                end

                STATE_SUSTAIN: begin
                    // Hold at sustain level
                    envelope_out <= sustain_level;
                    if (!gate) begin
                        // Gate released, go to release
                        state <= STATE_RELEASE;
                    end
                end

                STATE_RELEASE: begin
                    if (gate_rising) begin
                        // New gate during release, restart attack
                        state <= STATE_ATTACK;
                        envelope_out <= 8'h00;
                    end else if (counter_tick) begin
                        if (envelope_out == 8'h00) begin
                            // Release complete, return to idle
                            state <= STATE_IDLE;
                        end else begin
                            // Decrement envelope to zero
                            envelope_out <= envelope_out - 8'h01;
                        end
                    end
                end

                default: begin
                    state <= STATE_IDLE;
                    envelope_out <= 8'h00;
                end
            endcase
        end
    end

    // Output current state for status register
    always @(*) begin
        state_out = state;
    end

endmodule
