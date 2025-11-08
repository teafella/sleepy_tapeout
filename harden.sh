#!/bin/bash

# Activate virtual environment and set environment variables for TinyTapeout hardening
source ~/ttsetup/venv/bin/activate
export PDK_ROOT=~/ttsetup/pdk
export PDK=sky130A
export LIBRELANE_TAG=2.4.2

# Run tt_tool.py with provided arguments
./tt/tt_tool.py "$@"
