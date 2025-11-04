#!/bin/bash
# Simple standalone simulation script using iverilog

# Compile and simulate
iverilog -o sim -I../src ../src/user_module.v tb.v
vvp sim

# View waveforms with GTKWave (if installed)
if command -v gtkwave &> /dev/null; then
    gtkwave tb.vcd
fi

