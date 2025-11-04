#!/bin/bash
# Simple standalone simulation script using iverilog

# Compile and simulate
iverilog -o sim -I../src ../src/tt_um_user_module.v tb.v
vvp sim

# View waveforms with Surfer (if installed)
# if command -v surfer &> /dev/null; then
#     surfer tb.vcd
# fi

