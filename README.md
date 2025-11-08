![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# Sleepy Chip - Digital Monosynth for Tiny Tapeout

A complete digital monosynth voice featuring multi-waveform oscillator, ADSR envelope, and delta-sigma DAC audio output, designed to fit in a 1×1 Tiny Tapeout tile.

## 🎵 Current Status: Phase 1 Complete

### Implemented Modules ✅
- **24-bit Phase Accumulator** - High-resolution DDS core (2.98 Hz - 25 MHz)
- **Multi-Waveform Generator** - 5 waveforms with excellent quality:
  - Square wave with variable PWM (0-100% duty cycle)
  - Sawtooth wave (all harmonics)
  - Triangle wave (odd harmonics)
  - Sine wave (<3% error polynomial approximation)
  - Noise (32-bit LFSR, 4.29B sample period)
- **Delta-Sigma DAC** - First-order 1-bit modulator (±0.1% accuracy)

### Test Results 🧪
All modules validated with comprehensive testbenches:
- ✅ Phase accumulator frequency accuracy: <0.25% @ 440 Hz & 1 kHz
- ✅ PWM duty cycles: All 0-100% within ±1%
- ✅ Delta-sigma DAC: Tracks input amplitude within ±0.1%
- ✅ All 5 waveforms: End-to-end validated with DAC output
- ✅ Noise generator: Full dynamic range, proper randomness

### Resource Usage 📊
**Phase 1:** ~211 cells (~5.3% of 1x1 tile)
- Phase Accumulator: ~60 cells
- Waveform Generators: ~101 cells
- Delta-Sigma DAC: ~50 cells

**Phase 2 Target:** ~3,891 cells (97.3% of 1x1 tile)

## 📚 Documentation

- [Project Datasheet](docs/info.md) - Complete project documentation
- [Full Specification](specs/i2c_waveform_generator.md) - Detailed technical spec (2800+ lines)

## 🛠️ Quick Start

### Running Tests
```bash
# Test all waveforms end-to-end
cd /Users/ronaldsardarian/Documents/git/sleepy_tapeout
iverilog -g2012 -o test/waveforms_e2e.out test/test_waveforms_e2e.v src/*.v
cd test && ./waveforms_e2e.out
```

All tests should PASS showing accurate waveform generation and DAC conversion.

## 🏗️ Project Resources

- [Tiny Tapeout](https://tinytapeout.com)
- [FAQ](https://tinytapeout.com/faq/)
- [Community Discord](https://tinytapeout.com/discord)
- [Build Locally](https://www.tinytapeout.com/guides/local-hardening/)

---

**Status**: Phase 1 Complete ✅ | **Author**: Ron Sardarian | **Technology**: Sky130 PDK
