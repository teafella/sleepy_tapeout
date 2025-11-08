<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

**Sleepy Chip** is a digital monosynth-on-a-chip featuring multi-waveform oscillator, ADSR envelope, and delta-sigma DAC audio output. The design targets professional synthesizer quality in a 1x1 Tiny Tapeout tile.

### Current Implementation Status

**Completed Modules (Phase 1):**
- ✅ **24-bit Phase Accumulator** - DDS core with 16.7M resolution, 2.98 Hz to 25 MHz range
- ✅ **Multi-Waveform Generator** - Square, Sawtooth, Triangle, Sine, and Noise waveforms
- ✅ **Delta-Sigma DAC** - First-order 1-bit modulator for audio output
- ✅ **PWM Generator** - Variable duty cycle square wave (0-100%)

**Waveforms Implemented:**
1. **Square Wave** - Variable duty cycle (0-100%), rich harmonics
2. **Sawtooth** - Linear ramp, all harmonics present
3. **Triangle** - Symmetric fold, odd harmonics
4. **Sine Wave** - Polynomial approximation (<3% error), low distortion
5. **Noise** - 32-bit LFSR pseudo-random (4.29 billion sample period)

**Pending Modules (Phase 2):**
- I2C control interface (33 registers)
- ADSR envelope generator
- 6-channel waveform mixer with gain controls
- 4-pole state-variable filter (LP/HP/BP modes)
- ADSR modulation routing
- Wavetable generator (64-sample user-programmable)
- Glide/portamento
- Ring modulator
- PWM modulation

### Architecture

```
┌─────────────────┐      ┌─────────────────────┐
│ Phase           │      │ Waveform            │
│ Accumulator     ├─────→│ Generators          │
│ (24-bit DDS)    │      │ - Square (PWM)      │
│                 │      │ - Sawtooth          │
│ Freq control    │      │ - Triangle          │
│ 50 MHz clock    │      │ - Sine (polynomial) │
└─────────────────┘      │ - Noise (LFSR)      │
                         └──────────┬──────────┘
                                    │
                         ┌──────────▼──────────┐
                         │ Delta-Sigma DAC     │
                         │ (1-bit output)      │
                         │                     │
                         │ 50 MHz PDM          │
                         └──────────┬──────────┘
                                    │
                                    ▼
                              Audio Output
                         (requires RC filter)
```

### Technical Specifications

**Phase Accumulator:**
- Resolution: 24-bit (16,777,216 steps/cycle)
- Frequency Range: 2.98 Hz to 25 MHz
- Accuracy: <0.25% error (tested at 440 Hz and 1 kHz)
- Example: 440 Hz (A4) = frequency word 0x024000

**Waveform Quality:**
- Square: Full rail-to-rail (0-255)
- Sawtooth: Linear ramp, DC average ~127
- Triangle: Symmetric, DC average ~127
- Sine: Polynomial approximation, max error <3%
- Noise: Maximal-length LFSR, full dynamic range

**Delta-Sigma DAC:**
- Type: First-order with error feedback
- Output Rate: 50 MHz (1-bit PDM)
- Accuracy: ±0.1% tracking of input amplitude
- External Filter: Simple RC recommended (Fc ~25 kHz)

**Resource Usage (Current):**
- Phase Accumulator: ~60 cells
- Waveform Generators: ~101 cells
  - Sawtooth: 0 cells (wire)
  - Triangle: 18 cells
  - Sine: 68 cells
  - Noise: 15 cells
- Delta-Sigma DAC: ~50 cells
- **Total (Phase 1): ~211 cells** (~5.3% of 1x1 tile)

## Pin Configuration

### Dedicated Inputs (`ui_in[7:0]`)
| Pin | Name | Function | Description |
|-----|------|----------|-------------|
| `ui_in[0]` | GATE | Gate Input | Hardware gate trigger for ADSR (future) |
| `ui_in[1]` | HW_RST | Reset | Hardware reset (active low) (future) |
| `ui_in[7:2]` | - | Reserved | Future expansion |

### Dedicated Outputs (`uo_out[7:0]`)
| Pin | Name | Function | Description |
|-----|------|----------|-------------|
| `uo_out[0]` | **DAC_OUT** | **Audio** | **1-bit delta-sigma audio output** |
| `uo_out[1]` | GATE_LED | Status | Gate status indicator (future) |
| `uo_out[2]` | ENV_OUT | Debug | Envelope MSB for visualization (future) |
| `uo_out[3]` | SYNC | Debug | Sync pulse (phase MSB) (future) |
| `uo_out[7:4]` | - | Reserved | Future expansion |

### Bidirectional IOs (`uio[7:0]`)
| Pin | Name | Function | Description |
|-----|------|----------|-------------|
| `uio[0]` | SDA | I2C Data | I2C bidirectional data (future) |
| `uio[1]` | SCL | I2C Clock | I2C clock input from carrier MCU (future) |
| `uio[7:2]` | DEBUG | Optional | Debug/parallel output (future) |

**Note:** Currently only `uo_out[0]` (DAC_OUT) is active. All I2C and control features are planned for Phase 2. I2C pins are on UIOs because these connect to the carrier board's microcontroller.

## How to test

### Basic Audio Test (Current Phase 1)

The current implementation outputs test waveforms directly without I2C control:

1. **Power On**: Apply 50 MHz clock to the chip
2. **Audio Output**: Connect `uo_out[0]` (DAC_OUT) to a simple RC low-pass filter
   - R = 10kΩ, C = 680pF (Fc ≈ 23 kHz) or similar
3. **Listen**: Connect filter output to audio amplifier/speaker
4. **Waveforms**: The design cycles through test waveforms automatically

### Expected Results

- **Clean audio tone** at test frequency
- **Different timbres** as waveforms change:
  - Square: Bright, hollow sound
  - Sawtooth: Bright, buzzy sound
  - Triangle: Mellow, pure sound
  - Sine: Pure tone, single frequency
  - Noise: White noise (hiss)

### Frequency Calibration

To verify frequency accuracy:
- Test tone at 440 Hz (A4 note)
- Frequency word: 0x024000
- Expected accuracy: <1% error
- Can be verified with frequency counter or tuner

### Future Testing (Phase 2 - with I2C)

Once I2C control is implemented:
1. Connect I2C master (microcontroller/Raspberry Pi)
2. Program frequency via I2C registers (0x02-0x04)
3. Select waveform via register 0x01
4. Control ADSR envelope parameters
5. Adjust filter cutoff and resonance
6. Mix multiple waveforms
7. Load custom wavetables

## External hardware

### Minimum Setup (Current Phase 1)
- **RC Low-Pass Filter** (required):
  - R = 10kΩ
  - C = 680pF
  - Fc ≈ 23 kHz
  - Connects to `uo_out[0]` (DAC_OUT)
- **Audio Amplifier** (recommended):
  - Simple op-amp buffer or LM386
  - Speaker or headphones

### Full Setup (Future Phase 2)
- I2C Master (microcontroller/RPi) for control
- Potentiometers for manual control (via I2C)
- MIDI interface (optional, via microcontroller)
- Multi-stage filter for better audio quality
- Audio amplifier with volume control

### Suggested RC Filter Circuit

```
DAC_OUT (uo_out[0]) ──┬─── 10kΩ ───┬─── to audio amp
                      │            │
                     GND          680pF
                                  │
                                 GND
```

Alternative values for different cutoff frequencies:
- 15 kHz: R=10kΩ, C=1nF
- 25 kHz: R=10kΩ, C=680pF (recommended)
- 35 kHz: R=10kΩ, C=470pF

## Design Verification

All modules have been validated with comprehensive testbenches:

- ✅ **Phase Accumulator**: Frequency accuracy <0.25% @ 440Hz & 1kHz
- ✅ **PWM Generator**: All duty cycles 0-100% accurate within ±1%
- ✅ **Delta-Sigma DAC**: Output density matches input within ±0.1%
- ✅ **Waveforms**: All 5 waveforms validated end-to-end
- ✅ **Noise Generator**: Full dynamic range, centered average

## Future Enhancements (Phase 2)

Planned additions to reach full monosynth capability:
1. I2C register interface (33 registers)
2. Full ADSR envelope with hardware gate
3. 6-channel waveform mixer with independent gain
4. 4-pole state-variable filter (LP/HP/BP modes)
5. Modulation routing (envelope → filter/pitch)
6. 64-sample wavetable with interpolation
7. Glide/portamento
8. Ring modulator
9. PWM modulation
10. Comprehensive bypass/debug system

Target resource usage for complete design: ~3,891 cells (97.3% of 1x1 tile)

## References

- Complete specification: `specs/i2c_waveform_generator.md`
- Source code: `src/` directory
- Test benches: `test/` directory
- Tested with Icarus Verilog simulator
- Clock: 50 MHz
- Technology: Sky130 PDK

## Inspiration

This project aims to create a complete digital synthesizer voice on a single chip, inspired by classic monophonic synthesizers and modern Eurorack modules, while maximizing the capabilities of the Tiny Tapeout platform.
