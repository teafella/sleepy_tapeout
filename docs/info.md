<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## Pin Hardware Mapping

**Input Pins (`ui_in[7:0]`)** - Connected to DIP switches on demo board
- Switch ON = logic 1, Switch OFF = logic 0

**Output Pins (`uo_out[7:0]`)** - Connected to 7-segment display
- `uo_out[0:6]` = segments a-g
- `uo_out[7]` = decimal point
- Logic 1 = segment ON, Logic 0 = segment OFF

**Bidirectional Pins (`uio[7:0]`)** - Controlled by RP2040 MCU
- Direction set by `uio_oe` (0=input, 1=output)
- Used for SPI, I2C, UART, or custom MCU communication

## How it works
You take a nap and everrythig is good.
Explain how your project works

## How to test
Put in garbage, doen.
Explain how to use your project

## External hardware
Speaker output
List external hardware used in your project (e.g. PMOD, LED display, etc), if any
