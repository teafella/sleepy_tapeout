![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Sleepy Chip - Dual-Mode Digital Audio Synthesizer

A compact digital audio synthesizer featuring a 3-waveform oscillator with streaming capability and delta-sigma DAC output, designed to fit in a 1×1 Tiny Tapeout tile.

## 🎵 Features

**Dual Operating Modes:**
- **Oscillator Mode** - Traditional synthesis with 3 waveforms (square, sawtooth, triangle)
- **Streaming Mode** - Direct 8-bit sample playback for PCM streaming or custom waveforms

**Core Capabilities:**
- 24-bit phase accumulator (DDS) - 2.98 Hz resolution, <1 cent musical accuracy
- 8-level volume control - Instant bit-shift implementation (mute to full)
- First-order delta-sigma DAC - 1-bit 50 MHz PDM output
- SPI register interface - Mode 0 (CPOL=0, CPHA=0), RX-only, 8 registers

## 📊 Resource Usage

**Total:** ~870 instances (~63% of 1×1 tile)
- SPI Interface: ~45 cells
- Phase Accumulator: ~60 cells
- Waveform Generators: ~103 cells
- Delta-Sigma DAC: ~50 cells

## 🧪 Test Results

All modules validated with comprehensive testbenches:
- ✅ SPI RX Interface: All 8 registers, burst writes, read-only status
- ✅ Phase Accumulator: Frequency accuracy <0.25% @ 440Hz
- ✅ Waveform Generators: Square, sawtooth, triangle verified
- ✅ Mixer: 3-channel mixing with saturation protection
- ✅ Volume Control: All 8 levels verified in both modes
- ✅ Streaming Mode: Sample updates, mode switching
- ✅ Delta-Sigma DAC: Output modulation working correctly
- ✅ End-to-End: 12 comprehensive integration tests passing

## 🛠️ Quick Start

### Hardware Setup

1. **Power On**: Apply 50 MHz clock to the chip
2. **SPI Controller**: Connect microcontroller or SPI master to:
   - `uio[0]` - MOSI
   - `uio[1]` - SCK
   - `uio[2]` - CS (active low)
3. **Audio Output**: Connect `uo_out[0]` (DAC_OUT) to RC low-pass filter

### Oscillator Mode Example

```python
# Enable oscillator with sawtooth waveform
write_register(0x00, 0b00010001)  # OSC_EN=1, STREAM=0, SAW_EN=1

# Set frequency to 440 Hz (A4 note)
write_register(0x02, 0x00)  # Freq low
write_register(0x03, 0x40)  # Freq mid
write_register(0x04, 0x02)  # Freq high = 0x024000

# Set volume to full
write_register(0x06, 0xFF)

# Result: Clean 440 Hz sawtooth wave on audio output
```

### Streaming Mode Example

```python
# Switch to streaming mode
write_register(0x00, 0b00000010)  # OSC_EN=0, STREAM_MODE=1

# Stream different sample values
for sample in [0x00, 0x40, 0x80, 0xC0, 0xFF]:
    write_register(0x10, sample)
    time.sleep(0.001)  # 1ms per sample = 1 kHz sample rate

# Set volume
write_register(0x06, 0x80)  # 50% volume

# Result: Direct sample playback at your chosen rate
```

### Running Tests

```bash
# Run comprehensive Cocotb test (both modes, all features)
cd test
make clean
make

# Expected: 12 tests passing (oscillator + streaming modes)
```

## 📚 Documentation

- **[Complete Documentation](docs/info.md)** - Full technical specs, register map, pin configuration, SPI protocol, frequency calculations

## 📌 Pin Configuration

### Dedicated Inputs (`ui_in[7:0]`)
- `ui_in[0]` - **GATE** - Hardware gate trigger
- `ui_in[1]` - **HW_RST** - Hardware reset (active high)

### Dedicated Outputs (`uo_out[7:0]`)
- `uo_out[0]` - **DAC_OUT** - 1-bit delta-sigma audio output ⚡
- `uo_out[1]` - **GATE_LED** - Gate status indicator
- `uo_out[2]` - **OSC_RUN** - Oscillator running indicator
- `uo_out[3]` - **SYNC** - Sync pulse (phase MSB, frequency visualization)

### Bidirectional IOs (`uio[7:0]`)
- `uio[0]` - **MOSI** - SPI data input
- `uio[1]` - **SCK** - SPI clock input
- `uio[2]` - **CS** - SPI chip select (active low)

## 🎛️ Register Map

| Address | Name | Description |
|---------|------|-------------|
| 0x00 | Control | Oscillator enable, mode selection, waveform enables |
| 0x02 | Freq Low | Frequency control word low byte |
| 0x03 | Freq Mid | Frequency control word middle byte |
| 0x04 | Freq High | Frequency control word high byte (24-bit total) |
| 0x05 | Duty Cycle | Square wave PWM duty cycle (0x00=0%, 0xFF=100%) |
| 0x06 | Volume | Volume level (8 discrete levels, bit-shift based) |
| 0x10 | Stream Sample | Streaming mode sample value (0x00-0xFF) |
| 0x12 | Status | Read-only status register |

## 🔧 External Hardware

**RC Low-Pass Filter** (required):
```
DAC_OUT (uo_out[0]) ──┬─── 10kΩ ───┬─── to audio amp
                      │            │
                     GND         680pF
                                  │
                                 GND
```
- Fc ≈ 23 kHz - Removes 50 MHz carrier from PDM signal

**Recommended additions:**
- Audio amplifier (LM386, TL072, etc.)
- Speaker (8Ω) or headphones

## 🎯 Use Cases

1. **Musical Synthesizer** - Traditional subtractive synthesis with waveform mixing
2. **Sample Player** - Stream custom waveforms or short samples via SPI
3. **Sound Effects** - Generate tones, sweeps, and effects for games/devices
4. **Test Equipment** - Programmable audio frequency generator
5. **Educational** - Learn digital synthesis, DSP, and SPI communication
6. **MIDI Controller** - Microcontroller reads MIDI, controls synth via SPI

## 🏗️ Project Resources

- [Tiny Tapeout](https://tinytapeout.com)
- [FAQ](https://tinytapeout.com/faq/)
- [Community Discord](https://tinytapeout.com/discord)
- [Build Locally](https://www.tinytapeout.com/guides/local-hardening/)

---

**Status**: Design Complete ✅ | **Author**: Ron Sardarian | **Technology**: Sky130 PDK (Tiny Tapeout 09)
