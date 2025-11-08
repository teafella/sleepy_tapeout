`timescale 1ns/1ps

module test_simple_osc;
    reg clk;
    reg rst_n;
    reg enable;
    wire [23:0] phase;
    wire [7:0] square_out, saw_out, tri_out, mixed_out;

    // Clock generation
    initial begin
        clk = 0;
        forever #10 clk = ~clk;  // 50 MHz
    end

    // Phase accumulator
    phase_accumulator phase_acc (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .frequency(24'h024000),  // 440 Hz
        .duty_cycle(8'h80),      // 50%
        .phase_out(phase),
        .square_out(square_out)
    );

    // Waveform generators
    waveform_generators wavegens (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .phase_in(phase),
        .sawtooth_out(saw_out),
        .triangle_out(tri_out)
    );

    // Mixer
    waveform_mixer mixer (
        .clk(clk),
        .rst_n(rst_n),
        .square_in(square_out),
        .sawtooth_in(saw_out),
        .triangle_in(tri_out),
        .enable_square(1'b1),
        .enable_sawtooth(1'b1),
        .enable_triangle(1'b1),
        .mixed_out(mixed_out)
    );

    initial begin
        $dumpfile("simple_osc.vcd");
        $dumpvars(0, test_simple_osc);

        rst_n = 0;
        enable = 0;
        #100;

        rst_n = 1;
        #100;

        enable = 1;
        $display("=== Testing oscillator ===");
        $display("Time\tPhase\t\tSquare\tSaw\tTri\tMixed");

        repeat (20) begin
            #200;
            $display("%0t\t%06X\t%03d\t%03d\t%03d\t%03d",
                     $time, phase, square_out, saw_out, tri_out, mixed_out);
        end

        $display("\n=== Test complete ===");
        $finish;
    end
endmodule
