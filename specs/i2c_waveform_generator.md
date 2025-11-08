# I2C Waveform Generator with ADSR Envelope

## 1. System Overview

This specification describes a complete synthesizer voice module for TinyTapeout that provides I2C-controlled waveform generation with envelope shaping, filtering, and user-programmable wavetables. The system is designed to fit within a 1x1 tile using approximately 92% of available resources.

### Key Features

- **I2C Slave Interface**: Standard/Fast mode (100kHz/400kHz) for configuration
- **Six-Channel Waveform Mixer**: Smooth mixing of square, sawtooth, triangle, sine, noise, and wavetable with independent gain controls
- **64-Sample Wavetable**: User-programmable wavetable for custom waveforms
- **State-Variable Filter**: 4-pole resonant filter with lowpass, highpass, and bandpass modes
- **Full ADSR Envelope**: Attack, Decay, Sustain, Release envelope generator with precise timing
- **ADSR Modulation Routing**: Envelope can modulate filter cutoff, resonance, and oscillator pitch
- **Glide/Portamento**: Smooth frequency transitions with adjustable slew rate
- **PWM Modulation**: ADSR-controlled pulse width modulation for animated square wave
- **Ring Modulator**: Selectable source ring modulation for metallic/inharmonic tones
- **Wide Frequency Range**: 2.98 Hz to 25 MHz with 24-bit resolution
- **Flexible Control**: Duty cycle, amplitude, phase offset, and gate control
- **Delta-Sigma DAC**: 1-bit output for external filtering
- **Comprehensive Bypass Options**: Debug/bypass controls for all major subsystems (silicon debug)
- **Maximum Resource Utilization**: ~3891 cells (97.3% of 1x1 tile)
- **Professional Monosynth**: Complete feature set rivaling classic hardware synthesizers

### Performance Characteristics

- **Clock Frequency**: 50 MHz
- **Frequency Resolution**: 24-bit (16,777,216 steps)
- **Output Resolution**: 8-bit internal, 1-bit delta-sigma output
- **Waveform Quality**: Polynomial sine approximation, low distortion
- **ADSR Timing**: Configurable from single-sample to thousands of samples
- **I2C Address**: 7-bit configurable slave address

---

## 2. Resource Utilization

### Component Breakdown

| Component | Cells | Utilization | Notes |
|-----------|-------|-------------|-------|
| I2C Interface | 135 | 3.4% | Register bank + protocol controller |
| Square Wave Generator | 68 | 1.7% | Phase accumulator + duty cycle comparator |
| Sawtooth Wave Generator | 8 | 0.2% | Direct phase output (shares accumulator) |
| Triangle Wave Generator | 18 | 0.5% | Fold logic (shares phase accumulator) |
| Sine Wave Generator | 68 | 1.7% | Polynomial approximation + multiplier |
| Noise Generator (LFSR) | 15 | 0.4% | 32-bit maximal-length LFSR |
| Wavetable (64×8 RAM) | 512 | 12.8% | User-programmable wavetable storage |
| Wavetable Logic | 24 | 0.6% | Address generation + interpolation |
| ADSR Envelope | 135 | 3.4% | State machine + counters |
| Amplitude Modulator | 56 | 1.4% | 8×8 multiplier |
| Waveform Mixer (6-channel) | 642 | 16.1% | 6× multipliers + adder tree + saturation + gain registers |
| State-Variable Filter (4-pole) | 1360 | 34.0% | Dual SVF sections with LP/HP/BP modes |
| ADSR Modulation Routing | 348 | 8.7% | Routing matrix, multipliers, adders for filter/pitch mod |
| Bypass/Debug System | 72 | 1.8% | Bypass muxes for all major subsystems |
| Glide/Portamento | 60 | 1.5% | Frequency slew limiter with adjustable rate |
| PWM Modulation | 40 | 1.0% | ADSR-controlled pulse width modulation |
| Ring Modulator | 90 | 2.3% | Multiplier + source selection muxes |
| Additional Registers (8×) | 80 | 2.0% | Modulation, bypass, glide, PWM, ring mod control |
| Pipeline Registers | 32 | 0.8% | Timing optimization for modulation paths |
| Delta-Sigma DAC | 47 | 1.2% | 12-bit accumulator |
| Control Logic & Routing | 120 | 3.0% | Master enable, reset, clocking, routing for new features |
| **TOTAL** | **3891** | **97.3%** | |

### Physical Characteristics

- **Wire Length**: ~4000 μm (estimated)
- **Remaining Capacity**: ~109 cells (2.7%)
- **Tile Size**: 1x1 (167×108 μm)

---

## 3. System Architecture

### Block Diagram

```
                    ┌─────────────────────────────────────────────┐
                    │         I2C Slave Interface                 │
                    │  ┌────────────────────────────────────┐    │
                    │  │  Register Bank (36×8 registers)    │    │
                    │  └────────────────────────────────────┘    │
                    └──────────┬──────────────────────────────────┘
                               │ Control Signals
                               │
            ┌──────────────────┴──────────────────┐
            │                                     │
    ┌───────▼────────┐                   ┌───────▼────────┐
    │  Oscillator    │                   │  ADSR Envelope │
    │  ┌──────────┐  │                   │  ┌──────────┐  │
    │  │ Phase    │  │                   │  │   FSM    │  │
    │  │ Accum.   │  │                   │  └──────────┘  │
    │  │ (24-bit) │  │                   │  Envelope Value│
    │  └────┬─────┘  │                   │   (8-bit)      │
    │       │        │                   └───────┬────────┘
    │  ┌────▼─────┐  │                           │
    │  │ Square   │  │                           │
    │  ├──────────┤  │                           │
    │  │ Sawtooth │  │                           │
    │  ├──────────┤  │                           │
    │  │ Triangle │  │                           │
    │  ├──────────┤  │                           │
    │  │ Sine     │  │                           │
    │  ├──────────┤  │                           │
    │  │ Noise    │  │                           │
    │  └────┬─────┘  │                           │
    └───────┼────────┘                           │
            │ (all 6 waveforms in parallel)      │
      ┌─────▼─────┐                              │
      │ Waveform  │                              │
      │   Mixer   │                              │
      │ (6-chan)  │                              │
      │ 6× gains  │                              │
      └─────┬─────┘                              │
            │ Mixed Waveform (8-bit)             │
            │                                    │
            └──────────┬─────────────────────────┘
                       │
                ┌──────▼──────┐
                │  Amplitude  │
                │  Modulator  │
                │  (8×8 mult) │
                └──────┬──────┘
                       │ Modulated Output (8-bit)
                       │
                ┌──────▼──────┐
                │State-Variable│
                │   Filter    │
                │  (4-pole)   │
                │  LP/HP/BP   │
                └──────┬──────┘
                       │ Filtered Output (8-bit)
                       │
                ┌──────▼──────┐
                │ Delta-Sigma │
                │     DAC     │
                └──────┬──────┘
                       │
                  1-bit Output
```

### Signal Flow

1. **Configuration**: I2C master writes configuration to register bank (including wavetable data, mixer gains, glide, PWM, ring mod)
2. **Glide/Portamento**: Target frequency smoothly slewed to prevent abrupt pitch changes (bypassable)
3. **Generation**: Phase accumulator increments by glided frequency value (optionally modulated by ADSR envelope for vibrato)
4. **Waveform Synthesis**: All six waveforms generated in parallel from phase (including wavetable lookup)
5. **PWM Modulation**: ADSR envelope modulates square wave duty cycle for animated pulse width (optional)
6. **Mixing**: 6-channel mixer combines all waveforms with individual gain controls, allowing smooth morphing and complex timbres
7. **Ring Modulation**: Optionally multiply two selectable waveforms for metallic/inharmonic tones (post-mixer or pre-mixer selectable)
8. **Envelope**: ADSR generates amplitude envelope based on gate signal (bypassable)
9. **Modulation Routing**: ADSR envelope routed to modulate filter cutoff, resonance, pitch, and/or PWM based on routing register
10. **Amplitude Modulation**: Mixed/ring-modulated waveform multiplied by envelope value
11. **Filtering**: 4-pole state-variable filter (LP/HP/BP modes) with cutoff/resonance optionally modulated by ADSR (bypassable)
12. **Bypass Control**: Each subsystem can be bypassed for silicon debugging via bypass control register
13. **Conversion**: Delta-sigma DAC converts filtered signal to 1-bit output stream

---

## 4. I2C Register Map

### Register Summary

| Address | Name | Access | Default | Description |
|---------|------|--------|---------|-------------|
| 0x00 | Control | R/W | 0x00 | Enable, gate, reset, loop control |
| 0x01 | Waveform Select | R/W | 0x00 | Waveform type selection |
| 0x02 | Frequency Low | R/W | 0x00 | Frequency bits [7:0] |
| 0x03 | Frequency Mid | R/W | 0x00 | Frequency bits [15:8] |
| 0x04 | Frequency High | R/W | 0x00 | Frequency bits [23:16] |
| 0x05 | Duty Cycle | R/W | 0x80 | Square wave duty cycle |
| 0x06 | Phase Offset | R/W | 0x00 | Initial phase offset |
| 0x07 | Attack Rate | R/W | 0x10 | ADSR attack rate |
| 0x08 | Decay Rate | R/W | 0x20 | ADSR decay rate |
| 0x09 | Sustain Level | R/W | 0xC0 | ADSR sustain level |
| 0x0A | Release Rate | R/W | 0x30 | ADSR release rate |
| 0x0B | Master Amplitude | R/W | 0xFF | Overall amplitude |
| 0x0C | SVF1 Cutoff | R/W | 0xFF | SVF section 1 cutoff frequency |
| 0x0D | SVF1 Resonance | R/W | 0x00 | SVF section 1 resonance (Q) |
| 0x0E | SVF2 Cutoff | R/W | 0xFF | SVF section 2 cutoff frequency |
| 0x0F | SVF2 Resonance | R/W | 0x00 | SVF section 2 resonance (Q) |
| 0x10 | Filter Mode | R/W | 0x00 | Filter mode and routing control |
| 0x11 | Filter Enable | R/W | 0x01 | Filter bypass/enable control |
| 0x12 | Status | R | 0x00 | Status flags (read-only) |
| 0x13 | Wavetable Index | W | 0x00 | Wavetable write position (0-63) |
| 0x14 | Wavetable Data | W | 0x00 | Write sample to wavetable |
| 0x15 | Wavetable Control | R/W | 0x00 | Wavetable control flags |
| 0x16 | Modulation Routing | R/W | 0x00 | Enable modulation for filter cutoff, resonance, pitch |
| 0x17 | Mod Depth: Filter Cutoff | R/W | 0x00 | Modulation depth for filter cutoff (0-255) |
| 0x18 | Mod Depth: Filter Resonance | R/W | 0x00 | Modulation depth for filter resonance (0-255) |
| 0x19 | Mod Depth: Pitch | R/W | 0x00 | Modulation depth for pitch (0-255, ±semitones) |
| 0x1A | Bypass Control | R/W | 0x00 | Subsystem bypass/debug control |
| 0x1B | Mixer Gain: Square | R/W | 0x00 | Gain for square wave (0-255) |
| 0x1C | Mixer Gain: Sawtooth | R/W | 0x00 | Gain for sawtooth wave (0-255) |
| 0x1D | Mixer Gain: Triangle | R/W | 0x00 | Gain for triangle wave (0-255) |
| 0x1E | Mixer Gain: Sine | R/W | 0xFF | Gain for sine wave (0-255, default full) |
| 0x1F | Mixer Gain: Noise | R/W | 0x00 | Gain for noise (0-255) |
| 0x20 | Mixer Gain: Wavetable | R/W | 0x00 | Gain for wavetable (0-255) |
| 0x21 | Glide Rate | R/W | 0x00 | Portamento/glide slew rate (0=instant, 255=slowest) |
| 0x22 | PWM Depth | R/W | 0x00 | PWM modulation depth (0=no PWM, 255=full range) |
| 0x23 | Ring Mod Config | R/W | 0x00 | Ring modulator configuration and mix control |

### Detailed Register Descriptions

#### 0x00 - Control Register (R/W)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 0 | Enable | R/W | 0=Disabled, 1=Enabled. Master enable for oscillator |
| 1 | Gate | R/W | 0=Off, 1=On. Software gate trigger (overridden by hardware pin) |
| 2 | Reset | R/W | 0=Normal, 1=Reset. Soft reset (self-clearing) |
| 3 | Loop | R/W | 0=One-shot, 1=Continuous. Envelope loop mode |
| 7:4 | Reserved | R/W | Reserved. Write 0, ignore on read |

#### 0x01 - Waveform Select (R/W)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 2:0 | Waveform | R/W | 000=Square, 001=Sawtooth, 010=Triangle, 011=Sine, 100=Noise, 101=Wavetable |
| 7:3 | Reserved | R/W | Reserved. Write 0, ignore on read |

#### 0x02-0x04 - Frequency (R/W, 24-bit)

24-bit frequency control word (little-endian):
- **0x02**: Frequency[7:0] (LSB)
- **0x03**: Frequency[15:8]
- **0x04**: Frequency[23:16] (MSB)

**Frequency Calculation**:
```
Output Frequency (Hz) = (Frequency Value × Clock Frequency) / 2^24
Frequency Value = (Output Frequency × 2^24) / Clock Frequency
```

**Examples at 50 MHz clock**:
- 440 Hz (A4): 0x024000 (147,456)
- 1000 Hz: 0x051EB8 (335,544)
- 100 Hz: 0x0051EB (33,515)

#### 0x05 - Duty Cycle (R/W)

8-bit duty cycle for square wave:
- **0x00** (0): 0% duty cycle (always low)
- **0x80** (128): 50% duty cycle (perfect square)
- **0xFF** (255): ~100% duty cycle (always high)

Ignored for triangle, sine, and noise waveforms.

#### 0x06 - Phase Offset (R/W)

8-bit initial phase offset. Sets the starting phase of the oscillator when enabled or reset.

#### 0x07 - Attack Rate (R/W)

8-bit attack rate control:
- **0x00**: Instant attack (1 sample)
- **0x01-0xFE**: Progressively slower attack
- **0xFF**: Slowest attack

#### 0x08 - Decay Rate (R/W)

8-bit decay rate control (same encoding as attack).

#### 0x09 - Sustain Level (R/W)

8-bit sustain level:
- **0x00**: Silent sustain
- **0x80**: 50% sustain level
- **0xFF**: Full sustain level (no decay)

#### 0x0A - Release Rate (R/W)

8-bit release rate control (same encoding as attack).

#### 0x0B - Master Amplitude (R/W)

8-bit master amplitude multiplier:
- **0x00**: Mute
- **0xFF**: Full amplitude

#### 0x0C - SVF1 Cutoff (R/W)

8-bit cutoff frequency control for SVF section 1:
- **0x00**: Minimum cutoff (~50 Hz at 50 MHz clock)
- **0xFF**: Maximum cutoff (~20 kHz)

The cutoff frequency is logarithmically scaled for musical response.

#### 0x0D - SVF1 Resonance (R/W)

8-bit resonance (Q factor) control for SVF section 1:
- **0x00**: Minimum resonance (Q ≈ 0.5, gentle rolloff)
- **0x80**: Moderate resonance (Q ≈ 2.0)
- **0xFF**: Maximum resonance (Q ≈ 10, self-oscillation at high values)

**Warning**: High resonance values (> 0xE0) may cause self-oscillation.

#### 0x0E - SVF2 Cutoff (R/W)

8-bit cutoff frequency control for SVF section 2:
- **0x00**: Minimum cutoff (~50 Hz at 50 MHz clock)
- **0xFF**: Maximum cutoff (~20 kHz)

The cutoff frequency is logarithmically scaled for musical response.

#### 0x0F - SVF2 Resonance (R/W)

8-bit resonance (Q factor) control for SVF section 2:
- **0x00**: Minimum resonance (Q ≈ 0.5, gentle rolloff)
- **0x80**: Moderate resonance (Q ≈ 2.0)
- **0xFF**: Maximum resonance (Q ≈ 10, self-oscillation at high values)

**Warning**: High resonance values (> 0xE0) may cause self-oscillation.

#### 0x10 - Filter Mode (R/W)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 1:0 | Mode | R/W | 00=4-pole LP, 01=4-pole HP, 10=4-pole BP, 11=2-pole (SVF1 only) |
| 4:2 | SVF1 Output | R/W | 000=LP, 001=HP, 010=BP (when in 2-pole mode) |
| 7:5 | Reserved | R/W | Reserved. Write 0, ignore on read |

**Filter Modes**:
- **4-pole LP**: Both SVF sections in lowpass, cascaded
- **4-pole HP**: Both SVF sections in highpass, cascaded
- **4-pole BP**: Both SVF sections in bandpass, cascaded
- **2-pole**: Only SVF1 active, selectable output (LP/HP/BP)

#### 0x11 - Filter Enable (R/W)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 0 | Enable | R/W | 0=Bypass filter, 1=Filter enabled |
| 7:1 | Reserved | R/W | Reserved. Write 0, ignore on read |

#### 0x12 - Status Register (Read-Only)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 0 | Gate Active | R | Current gate state (hardware or software) |
| 3:1 | ADSR State | R | 000=Idle, 001=Attack, 010=Decay, 011=Sustain, 100=Release |
| 4 | Osc Running | R | Oscillator running flag |
| 7:5 | Reserved | R | Reserved. Read as 0 |

#### 0x10 - Wavetable Index (Write-Only)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 5:0 | Index | W | Wavetable write position (0-63) |
| 7:6 | Reserved | W | Reserved. Write 0 |

Specifies the position in the wavetable where the next write to register 0x11 will store data.

#### 0x11 - Wavetable Data (Write-Only)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 7:0 | Sample | W | Sample value to write at current index position |

Writes an 8-bit sample value to the wavetable at the current index. If auto-increment is enabled (0x12[0]), the index automatically increments after the write.

#### 0x12 - Wavetable Control (R/W)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 0 | Auto-Increment | R/W | 0=Manual index, 1=Auto-increment index after write |
| 1 | Reset Index | R/W | Write 1 to reset index to 0 (self-clearing) |
| 7:2 | Reserved | R/W | Reserved. Write 0, ignore on read |

**Auto-Increment Mode**: When enabled, the wavetable index automatically increments after each write to register 0x11, allowing burst writes of the entire wavetable without manually updating the index.

#### 0x16 - Modulation Routing (R/W)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 0 | Filter Cutoff Mod Enable | R/W | 0=Disabled, 1=ADSR modulates filter cutoff |
| 1 | Filter Resonance Mod Enable | R/W | 0=Disabled, 1=ADSR modulates filter resonance |
| 2 | Pitch Mod Enable | R/W | 0=Disabled, 1=ADSR modulates oscillator pitch |
| 3 | Reserved | R/W | Reserved for future modulation targets |
| 7:4 | Reserved | R/W | Reserved. Write 0, ignore on read |

Controls which parameters the ADSR envelope modulates. Multiple targets can be enabled simultaneously.

#### 0x17 - Modulation Depth: Filter Cutoff (R/W)

8-bit modulation depth for filter cutoff frequency:
- **0x00**: No modulation
- **0x80**: Moderate modulation (±50% of cutoff range)
- **0xFF**: Full modulation (±100% of cutoff range)

The ADSR envelope creates bipolar modulation: envelope value of 128 produces no change, <128 lowers cutoff, >128 raises cutoff. The depth parameter scales the modulation amount.

#### 0x18 - Modulation Depth: Filter Resonance (R/W)

8-bit modulation depth for filter resonance (Q factor):
- **0x00**: No modulation
- **0x80**: Moderate modulation
- **0xFF**: Full modulation

Same bipolar behavior as cutoff modulation.

#### 0x19 - Modulation Depth: Pitch (R/W)

8-bit modulation depth for oscillator pitch:
- **0x00**: No pitch modulation
- **0x20**: ±1 semitone modulation
- **0x40**: ±2 semitones
- **0x80**: ±4 semitones
- **0xFF**: ±8 semitones (approximately)

Allows pitch envelopes for "boing" sounds, pitch drops, etc. Envelope value of 128 = no pitch change.

#### 0x1A - Bypass Control (R/W)

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 0 | Bypass Oscillator | R/W | 0=Normal, 1=Bypass oscillator (output DC mid-scale) |
| 1 | Bypass ADSR | R/W | 0=Normal, 1=Bypass ADSR (force envelope = 0xFF) |
| 2 | Bypass Filter | R/W | 0=Normal, 1=Bypass filter (pass signal through) |
| 3 | Disable Wavetable | R/W | 0=Normal, 1=Disable wavetable (force basic waveforms) |
| 7:4 | Reserved | R/W | Reserved. Write 0, ignore on read |

**Silicon Debug Register**: Allows bypassing individual subsystems for debugging when manufactured on silicon. If a subsystem fails, it can be bypassed to identify the fault location.

**Example debug sequence**:
1. Set all bypass bits to test direct DAC output
2. Clear bits one by one to identify failing subsystem
3. Bypass failed subsystem and use working functionality

#### 0x1B-0x20 - Mixer Gain Registers (R/W)

Six independent 8-bit gain controls for the waveform mixer. Each register controls the amplitude of its corresponding waveform before mixing.

| Address | Waveform | Default | Notes |
|---------|----------|---------|-------|
| 0x1B | Square | 0x00 | Gain for square wave |
| 0x1C | Sawtooth | 0x00 | Gain for sawtooth wave |
| 0x1D | Triangle | 0x00 | Gain for triangle wave |
| 0x1E | Sine | 0xFF | Gain for sine wave (default full for backward compatibility) |
| 0x1F | Noise | 0x00 | Gain for noise generator |
| 0x20 | Wavetable | 0x00 | Gain for user wavetable |

**Gain Scaling**:
- `0x00` = Waveform fully muted (no contribution to mix)
- `0xFF` = Full amplitude (100% contribution)
- Linear scaling: `output = (waveform × gain) / 256`

**Usage Examples**:
- **Pure waveform**: Set one gain to 0xFF, others to 0x00
- **50/50 mix**: Set two gains to 0x80 each
- **Complex timbre**: Set multiple gains (e.g., 0x80 sine + 0x40 triangle + 0x20 sawtooth)
- **Smooth morphing**: Gradually adjust gain values to transition between waveforms

**Mixed Output Calculation**:
```
mixed_output = (square×gain_sq + saw×gain_saw + tri×gain_tri +
                sine×gain_sin + noise×gain_noise + wavetable×gain_wt) / 256
```

**Saturation**: The mixer output is saturated to 8-bit range (0x00-0xFF) if the sum exceeds 255.

**Backward Compatibility Note**: For traditional single-waveform operation (like the original waveform selector), set the desired waveform's gain to 0xFF and all others to 0x00. The sine wave defaults to full gain (0xFF) for this purpose.

#### 0x21 - Glide Rate (R/W)

Controls the portamento/glide slew rate for smooth frequency transitions.

| Value | Behavior | Approximate Slew Time (per octave) |
|-------|----------|-----------------------------------|
| 0x00 | Instant (glide disabled) | 0 ms |
| 0x01 | Very fast glide | ~1 ms |
| 0x10 | Fast glide | ~16 ms |
| 0x40 | Medium glide | ~64 ms |
| 0x80 | Slow glide | ~128 ms |
| 0xFF | Very slow glide | ~255 ms |

**Operation**:
- When frequency changes (via I2C write to 0x02-0x04), the glide module interpolates from current frequency to target frequency
- Glide rate determines how many samples it takes to reach the target
- Formula: `steps_to_target = glide_rate × 256`
- At 50 MHz clock, each step is 20 ns
- Glide of 0x80 = 128 × 256 = 32,768 steps = 655 μs per frequency update step

**Use Cases**:
- Legato playing (smooth pitch transitions between notes)
- Pitch swoops and slides
- Analog-style portamento effects
- Preventing clicks on frequency changes

#### 0x22 - PWM Depth (R/W)

Controls ADSR envelope modulation depth for pulse width modulation of the square wave.

| Value | PWM Range | Description |
|-------|-----------|-------------|
| 0x00 | No PWM | Duty cycle remains at register 0x05 value |
| 0x40 | ±25% | Envelope modulates duty cycle by ±25% |
| 0x80 | ±50% | Envelope modulates duty cycle by ±50% |
| 0xFF | ±100% (full range) | Envelope modulates from 0% to 100% duty cycle |

**Modulation Formula**:
```
duty_cycle = base_duty_cycle + ((envelope - 128) × PWM_depth) / 256
```

Where:
- `base_duty_cycle` = value from register 0x05
- `envelope` = current ADSR envelope value (0-255)
- `PWM_depth` = value from this register (0-255)

**Saturation**: Duty cycle is clamped to 0-255 range.

**Use Cases**:
- Animated square wave timbre (classic analog synth sound)
- Evolving harmonics during note envelope
- PWM sweeps for rich, chorusing effect
- Vibrato-like modulation of harmonic content

**Note**: PWM only affects the square wave generator. Other waveforms are not affected.

#### 0x23 - Ring Mod Config (R/W)

Configures the ring modulator source selection and mix control.

| Bit | Name | Access | Description |
|-----|------|--------|-------------|
| 2:0 | Source A | R/W | First ring mod input: 000=Square, 001=Saw, 010=Tri, 011=Sine, 100=Noise, 101=Wavetable |
| 5:3 | Source B | R/W | Second ring mod input: 000=Square, 001=Saw, 010=Tri, 011=Sine, 100=Noise, 101=Wavetable |
| 6 | Enable | R/W | 0=Ring mod disabled, 1=Ring mod enabled |
| 7 | Pre/Post Mix | R/W | 0=Ring mod before mixer, 1=Ring mod after mixer |

**Ring Modulation**: Multiplies two waveforms together to create metallic, inharmonic tones.

**Output Calculation**:
```
ring_mod_output = (sourceA × sourceB) / 256
```

**Pre-Mixer vs Post-Mixer Mode**:
- **Pre-Mixer** (bit 7 = 0): Ring mod output replaces one of the source waveforms in the mixer
  - More flexible: can mix ring-modulated signal with other waveforms
  - Example: 50% ring mod + 50% sine for partial metallization

- **Post-Mixer** (bit 7 = 1): Ring mod multiplies the entire mixer output
  - More extreme: applies ring modulation to the full mixed signal
  - Creates more complex inharmonic spectra

**Common Source Combinations**:
- **Sine × Sine**: Classic bell-like tones
- **Sine × Sawtooth**: Metallic, harmonic-rich tones
- **Square × Triangle**: Robot-like, digital tones
- **Noise × anything**: Filtered noise effects
- **Wavetable × Sine**: Custom inharmonic timbres

**Use Cases**:
- Bell and metallic percussion sounds
- Sci-fi sound effects
- Inharmonic drones
- Aggressive lead tones
- Noise modulation for texture

---

## 5. Component Implementation

### 5.1 Phase Accumulator

The phase accumulator is the core of the oscillator system. It's a 24-bit register that increments by the frequency value each clock cycle.

**Operation**:
```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        phase <= 24'b0;
    end else if (enable) begin
        phase <= phase + frequency;
    end
end
```

**Characteristics**:
- **Resolution**: 24 bits = 16,777,216 steps per cycle
- **Min Frequency**: 50 MHz / 2^24 ≈ 2.98 Hz
- **Max Frequency**: 50 MHz / 2 ≈ 25 MHz (Nyquist limit)
- **At 440 Hz**: ~38,127 phase increments per cycle

### 5.2 Square Wave Generator

Generates a square wave with variable duty cycle.

**Algorithm**:
```verilog
assign square_out = (phase[23:16] < duty_cycle) ? 8'hFF : 8'h00;
```

**Features**:
- Uses upper 8 bits of phase for comparison
- Duty cycle range: 0-100%
- 50% duty cycle at duty_cycle = 128

### 5.3 Sawtooth Wave Generator

Generates a sawtooth wave by directly outputting the phase accumulator.

**Algorithm**:
```verilog
assign sawtooth_out = phase[23:16];  // Direct phase output
```

**Features**:
- Simplest waveform generator
- Linear rise from 0 to 255
- Sharp discontinuity at wraparound
- Rich in harmonics (all integer harmonics present)
- No additional logic needed beyond phase accumulator

### 5.4 Triangle Wave Generator

Generates a triangle wave by folding the phase accumulator.

**Algorithm**:
```verilog
wire [7:0] phase_top = phase[23:16];
assign triangle_out = phase_top[7] ? (~phase_top << 1) : (phase_top << 1);
```

**Features**:
- Linear rise from 0 to peak
- Linear fall from peak to 0
- Symmetric waveform
- No duty cycle control

### 5.5 Sine Wave Generator (Polynomial Approximation)

Generates a sine wave using parabolic approximation with quadrant folding.

**Algorithm**:
1. Extract quadrant from phase[23:22]
2. Extract position within quadrant: x = phase[21:14]
3. Compute parabola: y = 4x(1-x)
4. Apply quadrant symmetry

**Verilog Implementation**:
```verilog
wire [1:0] quadrant = phase[23:22];
wire [7:0] x = phase[21:14];
wire [7:0] x_inv = 8'hFF - x;
wire [15:0] prod = x * x_inv;
wire [7:0] parabola = prod[15:8];

assign sine_out = quadrant[1] ? (~parabola) : parabola;
```

**Characteristics**:
- Approximation error: < 3% max
- Continuous and smooth
- Low harmonic distortion

### 5.6 Noise Generator (32-bit LFSR)

Generates pseudo-random noise using a maximal-length Linear Feedback Shift Register.

**Polynomial**: x^32 + x^22 + x^2 + x^1 + 1

**Verilog Implementation**:
```verilog
reg [31:0] lfsr;

wire feedback = lfsr[31] ^ lfsr[21] ^ lfsr[1] ^ lfsr[0];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        lfsr <= 32'hACE1;  // Non-zero seed
    end else if (enable) begin
        lfsr <= {lfsr[30:0], feedback};
    end
end

assign noise_out = lfsr[31:24];  // Use upper 8 bits
```

**Characteristics**:
- **Period**: 2^32 - 1 = 4,294,967,295 samples
- **Quality**: Pseudo-random, passes basic randomness tests
- **Seed**: Must be non-zero (0xACE1 default)
- **Note**: Requires `(* keep *)` attribute to prevent optimization

### 5.7 Wavetable Generator (64-Sample RAM)

Generates waveforms from a user-programmable 64-sample wavetable loaded via I2C.

**Storage**:
```verilog
reg [7:0] wavetable [0:63];  // 64 samples × 8 bits
reg [5:0] wt_write_index;
```

**I2C Write Interface**:
```verilog
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wt_write_index <= 6'b0;
    end else begin
        // Reset index
        if (reg_wavetable_ctrl[1]) begin
            wt_write_index <= 6'b0;
        end
        // Write sample
        else if (write_enable && reg_addr == 8'h11) begin
            wavetable[wt_write_index] <= reg_wavetable_data;
            // Auto-increment if enabled
            if (reg_wavetable_ctrl[0]) begin
                wt_write_index <= wt_write_index + 1;
            end
        end
        // Manual index update
        else if (write_enable && reg_addr == 8'h10) begin
            wt_write_index <= reg_wavetable_index[5:0];
        end
    end
end
```

**Playback with Linear Interpolation**:
```verilog
// Use upper 6 bits of phase as table address
wire [5:0] addr_curr = phase[23:18];
wire [5:0] addr_next = addr_curr + 1;

// Read two adjacent samples
wire [7:0] sample_curr = wavetable[addr_curr];
wire [7:0] sample_next = wavetable[addr_next];

// Fractional position (12 bits for precision)
wire [11:0] frac = phase[17:6];

// Linear interpolation: curr + (next - curr) * frac
wire signed [8:0] diff = {1'b0, sample_next} - {1'b0, sample_curr};
wire signed [20:0] scaled = diff * frac;
wire [7:0] interp = sample_curr + scaled[19:12];

assign wavetable_out = interp;
```

**Characteristics**:
- **Size**: 64 samples (512 DFFs)
- **Resolution**: 8-bit per sample
- **Playback Quality**: Linear interpolation for smooth output
- **Frequency Independence**: Same phase accumulator as other waveforms
- **Loading Time**: ~64 I2C writes (typical: ~1-2 ms at 400 kHz)

**Use Cases**:
- Custom waveforms (PWM variations, formants, vocal sounds)
- Recorded/sampled waveforms
- Algorithmic waveforms (additive synthesis precomputed)
- Morphing between timbres (update wavetable in real-time)

### 5.8 Waveform Mixer (6-Channel)

6-channel mixer that combines all six waveforms with independent gain controls, allowing smooth morphing between waveforms and creation of complex timbres.

**Theory of Operation**:

The mixer implements a weighted sum of all waveforms:
```
mixed_output = (square × gain_sq + sawtooth × gain_saw + triangle × gain_tri +
                sine × gain_sin + noise × gain_noise + wavetable × gain_wt) / 256
```

Each waveform is multiplied by its corresponding 8-bit gain value, then all products are summed and divided by 256 (arithmetic right shift by 8). If the sum exceeds 8-bit range, saturation is applied.

**Implementation Details**:
- **6× Multipliers**: Each waveform has dedicated 8×8 multiplier for gain scaling
- **Adder Tree**: 5-stage adder tree combines all 6 scaled waveforms
- **Saturation Logic**: Clamps output to 0x00-0xFF range
- **Resource Cost**: ~642 cells (6× 60-cell multipliers + 100-cell adder tree + 60-cell saturation + registers)

**Verilog Implementation**:
```verilog
module waveform_mixer (
    input wire clk,
    input wire rst_n,
    input wire [7:0] square_in,
    input wire [7:0] sawtooth_in,
    input wire [7:0] triangle_in,
    input wire [7:0] sine_in,
    input wire [7:0] noise_in,
    input wire [7:0] wavetable_in,
    input wire [7:0] gain_square,
    input wire [7:0] gain_sawtooth,
    input wire [7:0] gain_triangle,
    input wire [7:0] gain_sine,
    input wire [7:0] gain_noise,
    input wire [7:0] gain_wavetable,
    output wire [7:0] mixed_out
);

    // Stage 1: Multiply each waveform by its gain
    wire [15:0] product_square    = square_in * gain_square;
    wire [15:0] product_sawtooth  = sawtooth_in * gain_sawtooth;
    wire [15:0] product_triangle  = triangle_in * gain_triangle;
    wire [15:0] product_sine      = sine_in * gain_sine;
    wire [15:0] product_noise     = noise_in * gain_noise;
    wire [15:0] product_wavetable = wavetable_in * gain_wavetable;

    // Stage 2: Sum all products (adder tree for better timing)
    // First level: 3 pairs
    wire [16:0] sum_01 = product_square + product_sawtooth;
    wire [16:0] sum_23 = product_triangle + product_sine;
    wire [16:0] sum_45 = product_noise + product_wavetable;

    // Second level: 2 sums
    wire [17:0] sum_0123 = sum_01 + sum_23;
    wire [17:0] sum_final_temp = sum_0123 + {1'b0, sum_45};

    // Stage 3: Scale by dividing by 256 (shift right by 8)
    wire [9:0] sum_scaled = sum_final_temp[17:8];  // Take upper 10 bits after /256

    // Stage 4: Saturate to 8-bit range
    wire [7:0] mixed_saturated;
    assign mixed_saturated = (sum_scaled[9:8] != 2'b00) ? 8'hFF : sum_scaled[7:0];

    // Output register for timing
    reg [7:0] mixed_out_reg;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mixed_out_reg <= 8'h00;
        else
            mixed_out_reg <= mixed_saturated;
    end

    assign mixed_out = mixed_out_reg;

endmodule
```

**Resource Breakdown**:
- 6× 8-bit multipliers: ~360 cells (60 cells each)
- Adder tree (5 adders, varying widths): ~100 cells
- Saturation logic: ~40 cells
- Output register: ~8 cells
- Control logic: ~30 cells
- Gain registers (6×): ~60 cells
- Routing: ~44 cells
- **Total**: ~642 cells


### 5.9 Glide/Portamento

Frequency slew limiter that smoothly interpolates between frequency changes to prevent abrupt pitch jumps.

**Theory of Operation**:

When the target frequency changes (via I2C write), instead of instantly jumping to the new frequency, the glide module incrementally adjusts the current frequency toward the target. The glide rate determines how many clock cycles it takes to reach the target.

**Implementation Details**:
- **24-bit frequency interpolation**: Maintains full frequency resolution
- **Configurable slew rate**: 0 (instant) to 255 (very slow)
- **Linear interpolation**: Constant slew rate across all frequency ranges
- **Resource Cost**: ~60 cells (comparator + adder + registers)

**Verilog Implementation**:
```verilog
module glide_portamento (
    input wire clk,
    input wire rst_n,
    input wire [23:0] target_frequency,    // Target frequency from I2C registers
    input wire [7:0] glide_rate,           // Glide speed (0=instant, 255=slowest)
    output reg [23:0] current_frequency    // Glided frequency output to phase accumulator
);

    reg [23:0] target_freq_reg;
    reg [15:0] slew_counter;
    wire glide_enable = (glide_rate != 8'h00);
    wire freq_different = (target_frequency != target_freq_reg);

    // Detect frequency changes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            target_freq_reg <= 24'h000000;
            slew_counter <= 16'h0000;
        end else begin
            if (freq_different) begin
                target_freq_reg <= target_frequency;
                slew_counter <= 16'h0000;
            end
        end
    end

    // Glide logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_frequency <= 24'h000000;
        end else begin
            if (!glide_enable || slew_counter == 16'hFFFF) begin
                // Instant mode or glide complete
                current_frequency <= target_freq_reg;
            end else if (current_frequency != target_freq_reg) begin
                // Increment counter
                if (slew_counter[15:8] >= glide_rate) begin
                    // Time to update frequency
                    slew_counter <= 16'h0000;

                    // Move toward target
                    if (current_frequency < target_freq_reg) begin
                        // Calculate step size (larger jumps for bigger differences)
                        wire [23:0] diff = target_freq_reg - current_frequency;
                        wire [23:0] step = (diff >> 4) + 24'h000001;  // 1/16 of remaining + 1
                        current_frequency <= current_frequency + step;
                    end else begin
                        wire [23:0] diff = current_frequency - target_freq_reg;
                        wire [23:0] step = (diff >> 4) + 24'h000001;
                        current_frequency <= current_frequency - step;
                    end
                end else begin
                    slew_counter <= slew_counter + 16'h0100;  // Increment upper byte
                end
            end
        end
    end

endmodule
```

**Resource Breakdown**:
- Frequency registers (2× 24-bit): ~48 DFFs
- Slew counter (16-bit): ~16 DFFs
- Comparators: ~10 cells
- Adders/subtractors (24-bit): ~30 cells
- Control logic: ~6 cells
- **Total**: ~60 cells

### 5.10 PWM Modulation

ADSR-controlled pulse width modulation for the square wave, creating animated harmonic content.

**Theory of Operation**:

The PWM module modulates the duty cycle of the square wave using the ADSR envelope as a control source. This creates time-varying harmonic content that evolves with the note's envelope.

**Implementation Details**:
- **Bipolar modulation**: Envelope value centered at 128 (mid-scale)
- **Configurable depth**: 0-255, controls modulation range
- **Saturation**: Duty cycle clamped to 0-255 range
- **Resource Cost**: ~40 cells (multiplier + adder + saturation)

**Verilog Implementation**:
```verilog
module pwm_modulator (
    input wire [7:0] base_duty_cycle,      // Base duty cycle from register 0x05
    input wire [7:0] envelope,             // ADSR envelope value (0-255)
    input wire [7:0] pwm_depth,            // PWM modulation depth from register 0x22
    output wire [7:0] modulated_duty_cycle // Output duty cycle to square wave generator
);

    // Convert envelope to bipolar (-128 to +127)
    wire signed [8:0] env_bipolar = {1'b0, envelope} - 9'd128;

    // Calculate modulation amount
    wire signed [16:0] pwm_amount = env_bipolar * $signed({1'b0, pwm_depth});
    wire signed [8:0] pwm_scaled = pwm_amount[16:8];  // Divide by 256

    // Apply modulation to base duty cycle
    wire signed [9:0] duty_temp = {1'b0, base_duty_cycle} + pwm_scaled;

    // Saturate to 0-255 range
    assign modulated_duty_cycle = duty_temp[9] ? 8'h00 :                  // Negative
                                  (duty_temp[9:8] != 2'b00) ? 8'hFF :    // Overflow
                                  duty_temp[7:0];                         // Normal

endmodule
```

**Resource Breakdown**:
- 8-bit multiplier: ~25 cells
- Adder (9-bit): ~9 cells
- Saturation logic: ~4 cells
- Bipolar conversion: ~2 cells
- **Total**: ~40 cells

**PWM Effect on Harmonics**:
- **50% duty cycle**: Odd harmonics only (1st, 3rd, 5th...)
- **25% or 75%**: All harmonics present, different amplitudes
- **Modulating duty cycle**: Creates time-varying harmonic spectrum
- **Envelope control**: Harmonic content evolves with note dynamics

### 5.11 Ring Modulator

Multiplies two selectable waveforms to create metallic, inharmonic tones and complex spectra.

**Theory of Operation**:

Ring modulation multiplies two audio signals together, creating sum and difference frequencies. This produces inharmonic partials that don't exist in either source signal, creating metallic, bell-like, or alien tones.

**Mathematical Basis**:
```
Output = (SignalA × SignalB) / 256

Frequency content:
- Creates frequencies at (fA + fB) and (fA - fB)
- Also creates intermodulation products
- Result is typically inharmonic (non-musical intervals)
```

**Implementation Details**:
- **Selectable sources**: Any two of the 6 waveforms
- **Pre/Post mixer routing**: Ring mod before or after the mixer
- **Resource Cost**: ~90 cells (multiplier + source muxes + routing)

**Verilog Implementation**:
```verilog
module ring_modulator (
    input wire clk,
    input wire rst_n,
    input wire [7:0] square_in,
    input wire [7:0] sawtooth_in,
    input wire [7:0] triangle_in,
    input wire [7:0] sine_in,
    input wire [7:0] noise_in,
    input wire [7:0] wavetable_in,
    input wire [7:0] mixer_out,            // For post-mixer mode
    input wire [2:0] source_a_sel,         // Source A selection
    input wire [2:0] source_b_sel,         // Source B selection
    input wire enable,                     // Ring mod enable
    input wire post_mixer,                 // 0=pre-mixer, 1=post-mixer
    output wire [7:0] ring_mod_out
);

    // Source A multiplexer
    reg [7:0] source_a;
    always @(*) begin
        case (source_a_sel)
            3'b000: source_a = square_in;
            3'b001: source_a = sawtooth_in;
            3'b010: source_a = triangle_in;
            3'b011: source_a = sine_in;
            3'b100: source_a = noise_in;
            3'b101: source_a = wavetable_in;
            default: source_a = sine_in;
        endcase
    end

    // Source B multiplexer (use mixer output in post-mixer mode)
    reg [7:0] source_b;
    always @(*) begin
        if (post_mixer) begin
            source_b = mixer_out;
        end else begin
            case (source_b_sel)
                3'b000: source_b = square_in;
                3'b001: source_b = sawtooth_in;
                3'b010: source_b = triangle_in;
                3'b011: source_b = sine_in;
                3'b100: source_b = noise_in;
                3'b101: source_b = wavetable_in;
                default: source_b = sine_in;
            endcase
        end
    end

    // Ring modulation (multiply and scale)
    wire [15:0] product = source_a * source_b;
    wire [7:0] ring_result = product[15:8];  // Divide by 256

    // Output (bypass if disabled)
    assign ring_mod_out = enable ? ring_result :
                          post_mixer ? mixer_out : source_a;

endmodule
```

**Resource Breakdown**:
- 8-bit multiplier: ~60 cells
- Source A mux (6:1): ~12 cells
- Source B mux (6:1 or 2:1): ~12 cells
- Control logic & routing: ~6 cells
- **Total**: ~90 cells

**Common Timbres**:

| Source A | Source B | Result |
|----------|----------|--------|
| Sine | Sine | Classic bell tone, pure sum/difference frequencies |
| Sine | Sawtooth | Metallic, harmonic-rich spectrum |
| Triangle | Square | Robotic, digital character |
| Sine | Noise | Filtered noise with pitch tracking |
| Wavetable | Sine | Custom inharmonic textures |
| Any | Mixer Output | Complex modulation of full mix |

### 5.12 ADSR Envelope Generator

Full Attack-Decay-Sustain-Release envelope generator with gate control.

**State Machine**:
```
        ┌──────┐
        │ IDLE │◄───────────┐
        └──┬───┘            │
     Gate  │            Gate │
      ON   │             OFF │
        ┌──▼─────┐          │
        │ ATTACK │          │
        └──┬─────┘          │
    Attack  │               │
   Complete │               │
        ┌──▼────┐           │
        │ DECAY │           │
        └──┬────┘           │
   Decay    │               │
  Complete  │               │
        ┌──▼──────┐         │
        │ SUSTAIN │─────────┤
        └─────────┘         │
                            │
        ┌─────────┐         │
        │ RELEASE │◄────────┘
        └──┬──────┘
   Release  │
  Complete  │
            └────────────────┘
```

**Implementation Details**:

Each stage uses a rate counter and accumulator:
- **Attack**: Envelope rises from 0 to 255
- **Decay**: Envelope falls from 255 to sustain_level
- **Sustain**: Envelope holds at sustain_level
- **Release**: Envelope falls from current level to 0

**Rate Calculation**:
```verilog
// Rate determines how many clocks between increments/decrements
wire [15:0] rate_divider = {rate_register, 8'h00};  // Scale by 256
```

**Detailed Timing Calculations**:

At 50 MHz clock (20 ns period), the envelope timing works as follows:

**Attack/Decay/Release Timing**:
- Each stage increments/decrements the envelope value (0-255) by 1
- Rate register determines clock cycles between each step
- Formula: `clocks_per_step = rate_value × 256`

**Timing Table** (full 0→255 or 255→0 transition):

| Rate Value | Clocks/Step | Time/Step | Total Time (255 steps) | Description |
|------------|-------------|-----------|------------------------|-------------|
| 0x00 | 0 | 0 ns | **20 ns** | Instant (1 clock) |
| 0x01 | 256 | 5.12 μs | **1.31 ms** | Very fast |
| 0x02 | 512 | 10.24 μs | **2.61 ms** | Fast |
| 0x04 | 1,024 | 20.48 μs | **5.22 ms** | Quick |
| 0x08 | 2,048 | 40.96 μs | **10.4 ms** | Medium-fast |
| 0x10 | 4,096 | 81.92 μs | **20.9 ms** | Medium (default attack) |
| 0x20 | 8,192 | 163.8 μs | **41.8 ms** | Medium-slow (default decay) |
| 0x30 | 12,288 | 245.8 μs | **62.7 ms** | Slow (default release) |
| 0x40 | 16,384 | 327.7 μs | **83.6 ms** | Slow |
| 0x80 | 32,768 | 655.4 μs | **167 ms** | Very slow |
| 0xC0 | 49,152 | 983.0 μs | **251 ms** | Extra slow |
| 0xFF | 65,280 | 1.306 ms | **333 ms** | Maximum |

**Formulas**:
```
Clocks per step = rate_value × 256
Time per step (μs) = (rate_value × 256) / 50,000
Total time (ms) = (rate_value × 256 × 255) / 50,000,000
```

**Example Calculations**:

*Attack with rate = 0x10 (default)*:
- Clocks per step: 16 × 256 = 4,096
- Time per step: 4,096 / 50M = 81.92 μs
- Total attack time: 4,096 × 255 / 50M = 20.9 ms

*Release with rate = 0xFF (maximum)*:
- Clocks per step: 255 × 256 = 65,280
- Time per step: 65,280 / 50M = 1.306 ms
- Total release time: 65,280 × 255 / 50M = 333 ms

**Sustain Phase**:
- Sustain has no time limit - holds indefinitely until gate off
- Sustain level (0x00-0xFF) determines the held amplitude

**Minimum and Maximum Times**:
- **Absolute Minimum**: 20 ns (single clock, rate = 0x00)
- **Absolute Maximum**: 333 ms (rate = 0xFF for full 255-step transition)
- **Practical Minimum**: 1-5 ms (rate = 0x01-0x04)
- **Practical Maximum**: 100-300 ms (rate = 0x80-0xFF)

**Note**: Decay time depends on sustain level. If sustain is 0xC0 (192), decay only needs to drop 63 steps (255→192), making it ~4× faster than a full 0→255 transition.

### 5.13 Amplitude Modulator

Multiplies the selected waveform by the envelope value.

**Verilog Implementation**:
```verilog
wire [15:0] product = selected_wave * envelope_value;
wire [7:0] modulated = product[15:8];  // Take upper 8 bits

// Apply master amplitude
wire [15:0] final_product = modulated * master_amplitude;
assign amplitude_out = final_product[15:8];
```

### 5.14 State-Variable Filter (4-Pole, LP/HP/BP)

Implements a 4-pole resonant filter using cascaded state-variable filter (SVF) topology. The SVF architecture simultaneously generates lowpass, highpass, and bandpass outputs from a single structure.

#### SVF Theory

A state-variable filter uses two integrators and a summing amplifier to create a second-order filter with simultaneous LP, HP, and BP outputs:

**Transfer Functions**:
```
H_LP(z) = ωc² / (s² + (ωc/Q)s + ωc²)
H_HP(z) = s² / (s² + (ωc/Q)s + ωc²)
H_BP(z) = (ωc/Q)s / (s² + (ωc/Q)s + ωc²)
```

Where:
- ωc = cutoff frequency (radians/sample)
- Q = resonance quality factor
- s = Laplace transform variable

**Digital Implementation (Single SVF Section)**:

```verilog
// State-variable filter section (one 2-pole section)
module svf_section (
    input wire clk,
    input wire rst_n,
    input wire signed [7:0] audio_in,
    input wire [7:0] cutoff,      // Cutoff frequency control
    input wire [7:0] resonance,   // Q factor control
    output wire signed [7:0] lp_out,
    output wire signed [7:0] hp_out,
    output wire signed [7:0] bp_out
);

// State variables (integrator outputs)
reg signed [15:0] bp_state;  // Bandpass integrator
reg signed [15:0] lp_state;  // Lowpass integrator

// Coefficient calculation
wire signed [15:0] f;  // Frequency coefficient
wire signed [15:0] q_inv;  // 1/Q (damping)

// Map cutoff register (0-255) to filter coefficient
// f ≈ 2×sin(π×fc/fs), simplified for digital implementation
assign f = cutoff_to_coeff(cutoff);
assign q_inv = resonance_to_damping(resonance);

// SVF core equations
wire signed [31:0] hp_temp = (audio_in << 8) - lp_state - (bp_state * q_inv >> 8);
wire signed [31:0] bp_temp = bp_state + (hp_temp * f >> 16);
wire signed [31:0] lp_temp = lp_state + (bp_temp * f >> 16);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        bp_state <= 16'h0000;
        lp_state <= 16'h0000;
    end else begin
        bp_state <= bp_temp[15:0];
        lp_state <= lp_temp[15:0];
    end
end

// Output assignments (scale back to 8-bit)
assign hp_out = hp_temp[15:8];
assign bp_out = bp_state[15:8];
assign lp_out = lp_state[15:8];

endmodule
```

#### 4-Pole Implementation

Two SVF sections are cascaded to create the 4-pole filter:

```verilog
// First SVF section
wire signed [7:0] svf1_lp, svf1_hp, svf1_bp;
svf_section svf1 (
    .clk(clk),
    .rst_n(rst_n),
    .audio_in(input_sample),
    .cutoff(reg_svf1_cutoff),
    .resonance(reg_svf1_resonance),
    .lp_out(svf1_lp),
    .hp_out(svf1_hp),
    .bp_out(svf1_bp)
);

// Second SVF section (cascaded)
wire signed [7:0] svf2_lp, svf2_hp, svf2_bp;
wire signed [7:0] svf2_input;

// Route appropriate output from SVF1 to SVF2 based on mode
assign svf2_input = (filter_mode == 2'b00) ? svf1_lp :  // 4-pole LP
                    (filter_mode == 2'b01) ? svf1_hp :  // 4-pole HP
                    (filter_mode == 2'b10) ? svf1_bp :  // 4-pole BP
                    svf1_lp;  // Default to LP

svf_section svf2 (
    .clk(clk),
    .rst_n(rst_n),
    .audio_in(svf2_input),
    .cutoff(reg_svf2_cutoff),
    .resonance(reg_svf2_resonance),
    .lp_out(svf2_lp),
    .hp_out(svf2_hp),
    .bp_out(svf2_bp)
);

// Final output selection
reg signed [7:0] filter_out;
always @(*) begin
    case (filter_mode)
        2'b00: filter_out = svf2_lp;  // 4-pole LP (cascade LP→LP)
        2'b01: filter_out = svf2_hp;  // 4-pole HP (cascade HP→HP)
        2'b10: filter_out = svf2_bp;  // 4-pole BP (cascade BP→BP)
        2'b11: begin  // 2-pole mode (SVF1 only)
            case (svf1_output_select)
                3'b000: filter_out = svf1_lp;
                3'b001: filter_out = svf1_hp;
                3'b010: filter_out = svf1_bp;
                default: filter_out = svf1_lp;
            endcase
        end
        default: filter_out = svf2_lp;
    endcase
end

assign audio_out = filter_enable ? filter_out : input_sample;
```

#### Coefficient Calculation

**Cutoff Frequency Mapping**:
```
fc = 50 × 2^(cutoff_reg / 32)  // Hz (logarithmic scale)
ωc = 2π × fc / fs
f ≈ 2×sin(ωc/2)  // Digital frequency coefficient
```

**Resonance (Q) Mapping**:
```
Q = 0.5 + (resonance_reg / 255) × 9.5
damping = 1/Q
```

**Example Lookup Tables** (simplified for hardware):
```verilog
// Cutoff coefficient lookup (256 entries, 16-bit values)
// Exponential mapping: f[i] = 2×sin(π × 50×2^(i/32) / 50MHz)
wire [15:0] cutoff_lut [0:255];

// Q^-1 (damping) lookup (256 entries, 16-bit values)
// Linear-ish mapping: q_inv[i] = (1/Q) where Q = 0.5 + (i/255)×9.5
wire [15:0] damping_lut [0:255];
```

#### Characteristics

**4-Pole Mode**:
- **Cutoff Range**: ~50 Hz to ~20 kHz (musical logarithmic scale)
- **Resonance (Q)**: 0.5 (gentle) to 10.0 (self-oscillation)
- **Rolloff**: -24 dB/octave (4-pole)
- **Latency**: 4 samples (80 ns at 50 MHz)
- **Modes**: Lowpass, Highpass, Bandpass

**2-Pole Mode**:
- **Rolloff**: -12 dB/octave (2-pole)
- **Latency**: 2 samples (40 ns at 50 MHz)
- **Modes**: Lowpass, Highpass, Bandpass (from single SVF section)

**General**:
- **Bypass**: Set filter_enable = 0 for unity gain passthrough
- **Self-Oscillation**: High Q values (>0xE0) may cause self-oscillation
- **Phase Response**: Varies by mode; bandpass has -180° at cutoff

#### Resource Breakdown (4-Pole Complete System)

**Per SVF Section** (~680 cells each):
- Coefficient calculator/LUT: ~120 cells
- State variables (2× 16-bit): 32 DFFs
- Multipliers (3× 16-bit): ~300 cells
- Accumulators & arithmetic: ~180 cells
- Output selection logic: ~48 cells

**Total SVF Resources**:
- SVF Section 1: ~680 cells
- SVF Section 2: ~680 cells
- Routing & mode control: ~80 cells
- Coefficient lookup tables: ~120 cells (shared)

**Total**: ~1,360 cells (34.0% of tile capacity)

#### Filter Response Examples

**4-Pole Lowpass** (fc = 1 kHz, Q = 2.0):
- Passband: 0 Hz - 1 kHz (flat)
- Transition: 1 kHz - 4 kHz (-24 dB/octave slope)
- Stopband: >4 kHz (>48 dB attenuation)

**4-Pole Highpass** (fc = 200 Hz, Q = 0.7):
- Stopband: <50 Hz (>48 dB attenuation)
- Transition: 50 Hz - 200 Hz (+24 dB/octave slope)
- Passband: >200 Hz (flat)

**4-Pole Bandpass** (fc = 440 Hz, Q = 5.0):
- Center frequency: 440 Hz
- -3 dB bandwidth: 88 Hz (440/5)
- Peak gain: 0 dB
- Stopband attenuation: >48 dB outside band

### 5.15 ADSR Modulation Routing

Implements routing of the ADSR envelope to modulate filter cutoff, filter resonance, and oscillator pitch. This allows dynamic filter sweeps, varying resonance, and pitch envelopes.

#### Theory

The ADSR envelope (0-255) is used as a modulation source. For musical applications, modulation should be **bipolar** - capable of both increasing and decreasing the target parameter.

**Bipolar Modulation Formula**:
```
modulated_value = base_value + (envelope - 128) × depth / 128
```

Where:
- `envelope`: ADSR output (0-255)
- `depth`: Modulation depth register (0-255)
- `base_value`: Original parameter value from register
- `envelope - 128`: Converts unipolar (0-255) to bipolar (-128 to +127)
- `÷ 128`: Normalizes depth scaling

**Example**: Filter cutoff modulation
- Base cutoff: 0x80 (128)
- Depth: 0x80 (128, representing 100% modulation)
- Envelope at attack peak (255): cutoff = 128 + (255-128)×128/128 = 128 + 127 = 255
- Envelope at mid (128): cutoff = 128 + (128-128)×128/128 = 128 + 0 = 128
- Envelope at release end (0): cutoff = 128 + (0-128)×128/128 = 128 - 128 = 0

#### Implementation

**Verilog Module** (simplified):

```verilog
module modulation_router (
    input wire [7:0] envelope,              // ADSR envelope output
    input wire [7:0] base_cutoff,           // Base filter cutoff from register
    input wire [7:0] base_resonance,        // Base filter resonance from register
    input wire [23:0] base_frequency,       // Base oscillator frequency from registers
    input wire [7:0] depth_cutoff,          // Modulation depth for cutoff
    input wire [7:0] depth_resonance,       // Modulation depth for resonance
    input wire [7:0] depth_pitch,           // Modulation depth for pitch
    input wire [2:0] routing_enable,        // Enable bits for each target
    output wire [7:0] modulated_cutoff,
    output wire [7:0] modulated_resonance,
    output wire [23:0] modulated_frequency
);

    // Convert envelope to bipolar (-128 to +127)
    wire signed [8:0] env_bipolar = {1'b0, envelope} - 9'd128;

    // === Filter Cutoff Modulation ===
    wire signed [16:0] cutoff_mod_amount = env_bipolar * $signed({1'b0, depth_cutoff});
    wire signed [8:0] cutoff_mod_scaled = cutoff_mod_amount[16:8];  // Divide by 256
    wire signed [9:0] cutoff_temp = {1'b0, base_cutoff} + cutoff_mod_scaled;

    // Saturate to 0-255 range
    wire [7:0] cutoff_modulated_value = cutoff_temp[9] ? 8'h00 :              // Negative, saturate to 0
                                        (|cutoff_temp[9:8]) ? 8'hFF :         // >255, saturate to 255
                                        cutoff_temp[7:0];                      // Normal range

    assign modulated_cutoff = routing_enable[0] ? cutoff_modulated_value : base_cutoff;

    // === Filter Resonance Modulation ===
    wire signed [16:0] res_mod_amount = env_bipolar * $signed({1'b0, depth_resonance});
    wire signed [8:0] res_mod_scaled = res_mod_amount[16:8];
    wire signed [9:0] res_temp = {1'b0, base_resonance} + res_mod_scaled;

    wire [7:0] res_modulated_value = res_temp[9] ? 8'h00 :
                                     (|res_temp[9:8]) ? 8'hFF :
                                     res_temp[7:0];

    assign modulated_resonance = routing_enable[1] ? res_modulated_value : base_resonance;

    // === Pitch Modulation ===
    // Pitch modulation affects upper bits of 24-bit frequency
    // depth_pitch represents semitones: 0x20 ≈ ±1 semitone, 0xFF ≈ ±8 semitones
    wire signed [16:0] pitch_mod_amount = env_bipolar * $signed({1'b0, depth_pitch});
    wire signed [15:0] pitch_mod_scaled = pitch_mod_amount[16:1];  // Adjust scaling for frequency range

    // Apply to upper bits of frequency for pitch shift
    wire signed [24:0] freq_temp = {1'b0, base_frequency} + {{9{pitch_mod_scaled[15]}}, pitch_mod_scaled};

    // Saturate frequency to valid range
    wire [23:0] freq_modulated_value = freq_temp[24] ? 24'h000000 :           // Negative, clamp to 0
                                       (|freq_temp[24]) ? 24'hFFFFFF :         // Too high, clamp to max
                                       freq_temp[23:0];

    assign modulated_frequency = routing_enable[2] ? freq_modulated_value : base_frequency;

endmodule
```

#### Resource Breakdown

| Component | Cells | Notes |
|-----------|-------|-------|
| Multipliers (3× 8×8) | 192 | Filter cutoff, resonance, pitch modulation |
| Adders (3× 16-bit) | 72 | Adding modulation to base values |
| Saturation logic (3×) | 48 | Clipping to valid parameter ranges |
| Routing muxes (3×) | 24 | Enable/disable modulation per target |
| Control logic | 12 | Bipolar conversion, misc |
| **Total** | **348 cells** | |

#### Modulation Range Examples

**Filter Cutoff Sweep (440 Hz tone, resonance = 0x40)**:
- Base cutoff: 0x60 (96)
- Depth: 0xFF (255, full modulation)
- Attack (env=0): cutoff ≈ 0 Hz (fully closed, maximum filtering)
- Sustain (env=128): cutoff ≈ 50×2^(96/32) ≈ 400 Hz (base value)
- Peak (env=255): cutoff ≈ 20 kHz (fully open, minimum filtering)

**Pitch Envelope (440 Hz base)**:
- Base freq: 0x024000 (440 Hz)
- Depth: 0x40 (64, ±2 semitones)
- Attack start (env=0): ~392 Hz (2 semitones down)
- Sustain (env=128): 440 Hz (base pitch)
- Attack peak (env=255): ~494 Hz (2 semitones up)
- Creates "boing" or pitch drop effect

### 5.16 Bypass/Debug System

Implements bypass controls for all major subsystems to enable silicon debugging. When a chip is manufactured, individual sections can be bypassed to isolate faults and identify which subsystem is malfunctioning.

#### Architecture

Each bypassable subsystem has a 2:1 multiplexer controlled by a bit in the bypass control register (0x1A):

```
          Bypass Bit
               │
        ┌──────┴──────┐
        │  2:1  MUX   │
Input──>│  0: Normal  │──> Output
        │  1: Bypass  │
        └─────────────┘
```

#### Bypass Modes

**Bit 0: Bypass Oscillator**
- Normal (0): Oscillator generates waveforms from phase accumulator
- Bypass (1): Output constant DC value (0x80, mid-scale) instead of waveform
- **Purpose**: Test if oscillator phase accumulator or waveform generators are faulty

**Bit 1: Bypass ADSR**
- Normal (0): ADSR envelope modulates amplitude and parameters
- Bypass (1): Force envelope to maximum (0xFF), effectively no envelope shaping
- **Purpose**: Test if ADSR state machine is stuck or malfunctioning

**Bit 2: Bypass Filter**
- Normal (0): Signal passes through SVF filter
- Bypass (1): Signal bypasses filter (direct passthrough)
- **Purpose**: Test if filter coefficients or SVF sections are faulty
- **Note**: This is redundant with register 0x11 bit 0 (filter enable) but provided for consistency

**Bit 3: Disable Wavetable**
- Normal (0): All 6 waveforms available including wavetable
- Disable (1): Force waveform selection to basic waveforms only (exclude wavetable option)
- **Purpose**: Test if wavetable RAM has manufacturing defects

#### Verilog Implementation

```verilog
module bypass_system (
    input wire [7:0] bypass_ctrl,           // Bypass control register (0x1A)
    input wire [7:0] osc_output,            // Normal oscillator output
    input wire [7:0] adsr_output,           // Normal ADSR envelope
    input wire [7:0] filter_output,         // Normal filter output
    input wire [2:0] waveform_select,       // Normal waveform selection
    input wire [7:0] signal_input,          // Input to filter (for bypass)
    output wire [7:0] osc_final,            // Bypassed/normal oscillator
    output wire [7:0] adsr_final,           // Bypassed/normal ADSR
    output wire [7:0] filter_final,         // Bypassed/normal filter
    output wire [2:0] waveform_final        // Modified waveform select
);

    // Extract bypass bits
    wire bypass_osc = bypass_ctrl[0];
    wire bypass_adsr = bypass_ctrl[1];
    wire bypass_filter = bypass_ctrl[2];
    wire disable_wavetable = bypass_ctrl[3];

    // Oscillator bypass: output DC mid-scale
    assign osc_final = bypass_osc ? 8'h80 : osc_output;

    // ADSR bypass: force to full amplitude
    assign adsr_final = bypass_adsr ? 8'hFF : adsr_output;

    // Filter bypass: passthrough input signal
    assign filter_final = bypass_filter ? signal_input : filter_output;

    // Wavetable disable: if waveform select is 101 (wavetable), force to 000 (square)
    assign waveform_final = (disable_wavetable && (waveform_select == 3'b101)) ?
                            3'b000 : waveform_select;

endmodule
```

#### Resource Breakdown

| Component | Cells | Notes |
|-----------|-------|-------|
| Bypass muxes (4× 8-bit 2:1 mux) | 48 | One per bypassable section |
| Comparison logic | 8 | Wavetable select detection |
| Control registers | 16 | Bypass control register (8-bit) |
| **Total** | **72 cells** | |

#### Silicon Debug Procedure

When a manufactured chip exhibits faults, use this procedure:

1. **Test Direct DAC Path**:
   - Set bypass_ctrl = 0x0F (bypass all sections)
   - Expected: DAC should output constant mid-scale tone
   - If this fails: DAC or power supply fault

2. **Test Oscillator**:
   - Set bypass_ctrl = 0x0E (enable only oscillator)
   - Configure for square wave at known frequency
   - Expected: Square wave at DAC output
   - If fails: Oscillator or phase accumulator fault

3. **Test ADSR**:
   - Set bypass_ctrl = 0x0D (enable oscillator + ADSR)
   - Trigger gate pulses
   - Expected: Amplitude modulated waveform
   - If fails: ADSR state machine or envelope generator fault

4. **Test Filter**:
   - Set bypass_ctrl = 0x09 (enable oscillator + ADSR + filter)
   - Sweep filter cutoff
   - Expected: Audible filter sweep
   - If fails: SVF sections or coefficient calculation fault

5. **Test Wavetable**:
   - Set bypass_ctrl = 0x00 (all sections enabled)
   - Load known wavetable pattern, select wavetable mode
   - Expected: Custom waveform output
   - If fails: Wavetable RAM has bit errors

This systematic approach identifies the fault location quickly, allowing the remaining functional sections to be used.

### 5.17 Delta-Sigma DAC

Converts the 8-bit modulated signal to a 1-bit output stream.

**Algorithm**:
```verilog
reg [11:0] accumulator;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        accumulator <= 12'b0;
    end else begin
        accumulator <= accumulator + {amplitude_out, 4'b0};
    end
end

assign dac_out = accumulator[11];  // MSB is output
```

**Characteristics**:
- **Resolution**: 12-bit internal accumulator
- **Output Rate**: 50 MHz (1-bit stream)
- **External Filter**: Required (simple RC filter sufficient)
- **Cutoff Recommendation**: ~25 kHz for audio

---

## 6. IO Pinout

### Pin Assignment

#### Dedicated Inputs (ui_in[7:0])

| Pin | Name | Type | Description |
|-----|------|------|-------------|
| ui_in[0] | SCL | Digital In | I2C clock input |
| ui_in[1] | SDA | Digital In/Out | I2C data (input path, needs bidir) |
| ui_in[2] | GATE | Digital In | Hardware gate trigger |
| ui_in[3] | HW_RST | Digital In | Hardware reset (active low) |
| ui_in[7:4] | - | - | Reserved/unused |

#### Dedicated Outputs (uo_out[7:0])

| Pin | Name | Type | Description |
|-----|------|------|-------------|
| uo_out[0] | DAC_OUT | Digital Out | Delta-sigma DAC bitstream |
| uo_out[1] | GATE_LED | Digital Out | Gate status indicator |
| uo_out[2] | ENV_OUT | Digital Out | Envelope MSB (for visualization) |
| uo_out[3] | SYNC | Digital Out | Sync pulse (phase[23]) |
| uo_out[7:4] | - | - | Reserved/unused |

#### Bidirectional IOs (uio[7:0])

| Pin | Name | Direction | Description |
|-----|------|-----------|-------------|
| uio[0] | SDA | Bidirectional | I2C data (bidirectional) |
| uio[7:1] | - | - | Optional parallel output/debug |

### External Connections

**Minimal Setup**:
```
I2C Master → SCL (ui_in[0])
I2C Master ↔ SDA (ui_in[1] or uio[0])
Gate Switch → GATE (ui_in[2])
DAC_OUT (uo_out[0]) → RC Filter → Audio Out
```

**RC Filter for DAC Output**:
```
uo_out[0] ──┬─── 1kΩ ───┬─── Audio Out
            │           │
           GND        10nF
                       │
                      GND
```
Cutoff ≈ 16 kHz (adjust to taste)

---

## 7. Timing Specifications

### Clock Domain

- **Master Clock**: 50 MHz (20 ns period)
- **Clock Domain**: Single synchronous clock domain
- **Reset**: Asynchronous assert, synchronous de-assert

### Frequency Range

| Parameter | Value | Calculation |
|-----------|-------|-------------|
| Minimum Frequency | 2.98 Hz | 50 MHz / 2^24 |
| Maximum Frequency | 25 MHz | 50 MHz / 2 (Nyquist) |
| Frequency Step | 2.98 Hz | 50 MHz / 2^24 |
| Resolution | 24 bits | 16,777,216 steps |

### ADSR Timing

| Parameter | Min | Typical | Max |
|-----------|-----|---------|-----|
| Attack Time | 20 ns (rate=0x00) | 1-20 ms (rate=0x01-0x10) | 333 ms (rate=0xFF) |
| Decay Time | 20 ns (rate=0x00) | 10-100 ms (rate=0x08-0x40) | 333 ms (rate=0xFF) |
| Sustain | Indefinite | - | - |
| Release Time | 20 ns (rate=0x00) | 10-100 ms (rate=0x08-0x40) | 333 ms (rate=0xFF) |

**Rate Scaling**: Each rate value corresponds to a divider. Rate 0 = instant (1 clock), Rate 255 = 65,280 clocks per step.

**See Section 5.9** for detailed timing calculations and complete timing table.

### I2C Timing

**Standard Mode (100 kHz)**:
- SCL frequency: ≤ 100 kHz
- Setup time: ≥ 250 ns
- Hold time: ≥ 0 ns

**Fast Mode (400 kHz)**:
- SCL frequency: ≤ 400 kHz
- Setup time: ≥ 100 ns
- Hold time: ≥ 0 ns

**Note**: Input synchronizers add 2-3 clock cycles of latency (40-60 ns at 50 MHz).

---

## 8. Verilog Module Hierarchy

### Top-Level Module

```verilog
module tt_um_sleepy_module (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    // I2C Interface
    wire [7:0] reg_control;
    wire [7:0] reg_waveform;
    wire [23:0] reg_frequency;
    wire [7:0] reg_duty;
    wire [7:0] reg_phase_offset;
    wire [7:0] reg_attack;
    wire [7:0] reg_decay;
    wire [7:0] reg_sustain;
    wire [7:0] reg_release;
    wire [7:0] reg_amplitude;
    wire [7:0] reg_svf1_cutoff;
    wire [7:0] reg_svf1_resonance;
    wire [7:0] reg_svf2_cutoff;
    wire [7:0] reg_svf2_resonance;
    wire [7:0] reg_filter_mode;
    wire [7:0] reg_filter_enable;
    wire [7:0] reg_mod_routing;
    wire [7:0] reg_mod_depth_cutoff;
    wire [7:0] reg_mod_depth_resonance;
    wire [7:0] reg_mod_depth_pitch;
    wire [7:0] reg_bypass_ctrl;
    wire [7:0] reg_gain_square;
    wire [7:0] reg_gain_sawtooth;
    wire [7:0] reg_gain_triangle;
    wire [7:0] reg_gain_sine;
    wire [7:0] reg_gain_noise;
    wire [7:0] reg_gain_wavetable;

    i2c_slave i2c (
        .clk(clk),
        .rst_n(rst_n),
        .scl(ui_in[0]),
        .sda(uio_in[0]),
        .sda_out(uio_out[0]),
        .sda_oe(uio_oe[0]),
        // Register outputs...
    );
    
    // Oscillator
    wire [7:0] square_out, sawtooth_out, triangle_out, sine_out, noise_out, wavetable_out;

    oscillator osc (
        .clk(clk),
        .rst_n(rst_n),
        .enable(reg_control[0]),
        .frequency(modulated_frequency),        // Use modulated frequency
        .duty_cycle(reg_duty),
        .phase_offset(reg_phase_offset),
        .square_out(square_out),
        .sawtooth_out(sawtooth_out),
        .triangle_out(triangle_out),
        .sine_out(sine_out),
        .noise_out(noise_out),
        .wavetable_out(wavetable_out)
    );

    // Waveform Mixer
    wire [7:0] mixed_wave;

    waveform_mixer mixer (
        .clk(clk),
        .rst_n(rst_n),
        .square_in(square_out),
        .sawtooth_in(sawtooth_out),
        .triangle_in(triangle_out),
        .sine_in(sine_out),
        .noise_in(noise_out),
        .wavetable_in(wavetable_out),
        .gain_square(reg_gain_square),
        .gain_sawtooth(reg_gain_sawtooth),
        .gain_triangle(reg_gain_triangle),
        .gain_sine(reg_gain_sine),
        .gain_noise(reg_gain_noise),
        .gain_wavetable(reg_gain_wavetable),
        .mixed_out(mixed_wave)
    );
    
    // ADSR Envelope
    wire [7:0] envelope_value;
    wire [2:0] adsr_state;
    
    adsr_envelope adsr (
        .clk(clk),
        .rst_n(rst_n),
        .gate(ui_in[2] | reg_control[1]),
        .attack_rate(reg_attack),
        .decay_rate(reg_decay),
        .sustain_level(reg_sustain),
        .release_rate(reg_release),
        .envelope_out(envelope_value),
        .state_out(adsr_state)
    );

    // Modulation Routing
    wire [7:0] modulated_cutoff, modulated_resonance;
    wire [23:0] modulated_frequency;

    modulation_router mod_router (
        .envelope(envelope_value),
        .base_cutoff(reg_svf1_cutoff),
        .base_resonance(reg_svf1_resonance),
        .base_frequency(reg_frequency),
        .depth_cutoff(reg_mod_depth_cutoff),
        .depth_resonance(reg_mod_depth_resonance),
        .depth_pitch(reg_mod_depth_pitch),
        .routing_enable(reg_mod_routing[2:0]),
        .modulated_cutoff(modulated_cutoff),
        .modulated_resonance(modulated_resonance),
        .modulated_frequency(modulated_frequency)
    );

    // Bypass System
    wire [7:0] mixed_wave_bypassed;
    wire [7:0] envelope_bypassed;
    wire [7:0] filter_out_bypassed;

    bypass_system bypass (
        .bypass_ctrl(reg_bypass_ctrl),
        .osc_output(mixed_wave),
        .adsr_output(envelope_value),
        .filter_output(filtered_out),
        .signal_input(modulated_out),
        .osc_final(mixed_wave_bypassed),
        .adsr_final(envelope_bypassed),
        .filter_final(filter_out_bypassed)
    );

    // Amplitude Modulator
    wire [7:0] modulated_out;

    amplitude_modulator amp_mod (
        .waveform_in(mixed_wave_bypassed),
        .envelope_in(envelope_bypassed),
        .amplitude_in(reg_amplitude),
        .output_out(modulated_out)
    );
    
    // State-Variable Filter (4-pole)
    wire [7:0] filtered_out;

    svf_filter svf (
        .clk(clk),
        .rst_n(rst_n),
        .enable(reg_filter_enable[0]),
        .svf1_cutoff(modulated_cutoff),         // Use modulated cutoff
        .svf1_resonance(modulated_resonance),   // Use modulated resonance
        .svf2_cutoff(reg_svf2_cutoff),
        .svf2_resonance(reg_svf2_resonance),
        .filter_mode(reg_filter_mode[1:0]),
        .svf1_output_select(reg_filter_mode[4:2]),
        .audio_in(modulated_out),
        .audio_out(filtered_out)
    );
    
    // Delta-Sigma DAC
    delta_sigma_dac dac (
        .clk(clk),
        .rst_n(rst_n),
        .data_in(filter_out_bypassed),  // Use bypassed filter output
        .dac_out(uo_out[0])
    );
    
    // Status outputs
    assign uo_out[1] = ui_in[2] | reg_control[1];  // Gate LED
    assign uo_out[2] = envelope_value[7];           // Envelope MSB
    assign uo_out[3] = phase[23];                   // Sync pulse
    
endmodule
```

### Module Tree

```
tt_um_sleepy_module/
├── i2c_slave/
│   ├── scl_sync (2 DFFs)
│   ├── sda_sync (2 DFFs)
│   ├── i2c_fsm (state machine)
│   ├── bit_counter (4-bit counter)
│   ├── shift_register (8 DFFs)
│   ├── address_decoder
│   └── register_bank (33×8 DFFs)
│
├── oscillator/
│   ├── phase_accumulator (24 DFFs + 24-bit adder)
│   ├── square_generator (comparator)
│   ├── sawtooth_generator (direct output)
│   ├── triangle_generator (fold logic)
│   ├── sine_generator (polynomial + 16-bit mult)
│   ├── noise_generator (32-bit LFSR)
│   ├── wavetable_generator
│   │   ├── wavetable_ram (64×8 = 512 DFFs)
│   │   ├── write_controller (index + auto-increment)
│   │   └── interpolator (linear interpolation)
│
├── waveform_mixer/
│   ├── square_multiplier (8×8 mult)
│   ├── sawtooth_multiplier (8×8 mult)
│   ├── triangle_multiplier (8×8 mult)
│   ├── sine_multiplier (8×8 mult)
│   ├── noise_multiplier (8×8 mult)
│   ├── wavetable_multiplier (8×8 mult)
│   ├── adder_tree
│   │   ├── adder_level1_pair01 (17-bit adder)
│   │   ├── adder_level1_pair23 (17-bit adder)
│   │   ├── adder_level1_pair45 (17-bit adder)
│   │   ├── adder_level2_sum0123 (18-bit adder)
│   │   └── adder_level2_final (18-bit adder)
│   ├── saturation_logic (10-bit to 8-bit clamp)
│   └── output_register (8 DFFs)
│
├── adsr_envelope/
│   ├── gate_sync (2 DFFs)
│   ├── edge_detector
│   ├── adsr_fsm (state machine)
│   ├── rate_counters (4×16-bit counters)
│   └── envelope_accumulator (8 DFFs)
│
├── amplitude_modulator/
│   ├── mult_8x8_stage1 (8×8 multiplier)
│   └── mult_8x8_stage2 (amplitude scaling)
│
├── svf_filter/
│   ├── svf_section_1/
│   │   ├── coefficient_calculator (cutoff/Q to f/damping)
│   │   ├── state_variables (2×16-bit: bp_state, lp_state)
│   │   ├── multipliers (3×16-bit mult)
│   │   └── output_logic (LP/HP/BP outputs)
│   ├── svf_section_2/
│   │   ├── coefficient_calculator (cutoff/Q to f/damping)
│   │   ├── state_variables (2×16-bit: bp_state, lp_state)
│   │   ├── multipliers (3×16-bit mult)
│   │   └── output_logic (LP/HP/BP outputs)
│   ├── coefficient_luts (shared cutoff/Q lookup tables)
│   └── routing_logic (mode select, output mux)
│
├── modulation_router/
│   ├── bipolar_converter (envelope - 128)
│   ├── cutoff_multiplier (8×8 mult)
│   ├── resonance_multiplier (8×8 mult)
│   ├── pitch_multiplier (8×8 mult)
│   ├── cutoff_adder (9-bit adder + saturation)
│   ├── resonance_adder (9-bit adder + saturation)
│   ├── pitch_adder (25-bit adder + saturation)
│   └── routing_muxes (3× enable/disable mux)
│
├── bypass_system/
│   ├── osc_bypass_mux (8-bit 2:1 mux)
│   ├── adsr_bypass_mux (8-bit 2:1 mux)
│   ├── filter_bypass_mux (8-bit 2:1 mux)
│   └── wavetable_disable_logic (3-bit comparator + mux)
│
└── delta_sigma_dac/
    └── accumulator (12 DFFs + 12-bit adder)
```

---

## 9. I2C Protocol Examples

### Example 1: Configure for 440 Hz Sine Wave

**Frequency Calculation**:
```
Freq = 440 Hz
Value = (440 × 2^24) / 50,000,000
Value = 147,456 decimal
Value = 0x024000 hex
```

**I2C Transaction Sequence**:
```
1. Write Waveform Select (Sine = 0b011):
   START - 0xXX(W) - ACK - 0x01 - ACK - 0x03 - ACK - STOP

2. Write Frequency Low:
   START - 0xXX(W) - ACK - 0x02 - ACK - 0x00 - ACK - STOP

3. Write Frequency Mid:
   START - 0xXX(W) - ACK - 0x03 - ACK - 0x40 - ACK - STOP

4. Write Frequency High:
   START - 0xXX(W) - ACK - 0x04 - ACK - 0x02 - ACK - STOP

5. Enable Oscillator:
   START - 0xXX(W) - ACK - 0x00 - ACK - 0x01 - ACK - STOP
```

### Example 2: Configure ADSR Envelope

**Target**: Fast attack, medium decay, 75% sustain, medium release

```
1. Set Attack Rate (fast):
   START - 0xXX(W) - ACK - 0x07 - ACK - 0x08 - ACK - STOP

2. Set Decay Rate (medium):
   START - 0xXX(W) - ACK - 0x08 - ACK - 0x20 - ACK - STOP

3. Set Sustain Level (75%):
   START - 0xXX(W) - ACK - 0x09 - ACK - 0xC0 - ACK - STOP

4. Set Release Rate (medium):
   START - 0xXX(W) - ACK - 0x0A - ACK - 0x20 - ACK - STOP
```

### Example 3: Configure 4-Pole Lowpass Filter

**Target**: 1 kHz cutoff with moderate resonance, 4-pole mode

```
1. Set SVF1 Cutoff (~1 kHz, approximately 0x60):
   START - 0xXX(W) - ACK - 0x0C - ACK - 0x60 - ACK - STOP

2. Set SVF1 Resonance (moderate, Q≈2):
   START - 0xXX(W) - ACK - 0x0D - ACK - 0x80 - ACK - STOP

3. Set SVF2 Cutoff (same as SVF1 for matched response):
   START - 0xXX(W) - ACK - 0x0E - ACK - 0x60 - ACK - STOP

4. Set SVF2 Resonance (same as SVF1):
   START - 0xXX(W) - ACK - 0x0F - ACK - 0x80 - ACK - STOP

5. Set Filter Mode (4-pole LP = 0b00):
   START - 0xXX(W) - ACK - 0x10 - ACK - 0x00 - ACK - STOP

6. Enable Filter:
   START - 0xXX(W) - ACK - 0x11 - ACK - 0x01 - ACK - STOP
```

### Example 3b: Configure 4-Pole Bandpass Filter

**Target**: 440 Hz center frequency, high Q for narrow band

```
1. Configure both SVF sections for 440 Hz, high Q:
   START - 0xXX(W) - ACK - 0x0C - ACK - 0x4A - ACK - STOP  // SVF1 cutoff
   START - 0xXX(W) - ACK - 0x0D - ACK - 0xD0 - ACK - STOP  // SVF1 Q (high)
   START - 0xXX(W) - ACK - 0x0E - ACK - 0x4A - ACK - STOP  // SVF2 cutoff
   START - 0xXX(W) - ACK - 0x0F - ACK - 0xD0 - ACK - STOP  // SVF2 Q (high)

2. Set Filter Mode (4-pole BP = 0b10):
   START - 0xXX(W) - ACK - 0x10 - ACK - 0x02 - ACK - STOP

3. Enable Filter:
   START - 0xXX(W) - ACK - 0x11 - ACK - 0x01 - ACK - STOP
```

### Example 4: Read Status Register

```
1. Write register address:
   START - 0xXX(W) - ACK - 0x12 - ACK - STOP

2. Read status:
   START - 0xXX(R) - ACK - [DATA] - NACK - STOP
```

### Example 5: Burst Write (More Efficient)

```
Write multiple registers in one transaction:
START - 0xXX(W) - ACK - 0x01 - ACK - 0x03 - ACK - 0x00 - ACK - 0x40 - ACK - 0x02 - ACK - STOP
        ^          ^      ^        ^      ^       ^      ^       ^      ^       ^      ^
        |          |      |        |      |       |      |       |      |       |      |
      Address      |   Reg 0x01   |  Reg 0x02   |  Reg 0x03   |  Reg 0x04   |    Stop
                  Ack  (Wave=3)  Ack  (Freq L) Ack (Freq M) Ack (Freq H)  Ack
```

### Example 6: Load Custom Wavetable

**Target**: Load a custom 64-sample waveform and play it

```
1. Enable auto-increment mode:
   START - 0xXX(W) - ACK - 0x15 - ACK - 0x01 - ACK - STOP

2. Reset index to 0:
   START - 0xXX(W) - ACK - 0x15 - ACK - 0x03 - ACK - STOP
   (sets both reset and auto-increment)

3. Burst write all 64 samples (auto-increment handles indexing):
   START - 0xXX(W) - ACK - 0x14 - ACK
   [sample 0] - ACK
   [sample 1] - ACK
   [sample 2] - ACK
   ... (continue for all 64 samples)
   [sample 63] - ACK
   STOP

4. Select wavetable waveform:
   START - 0xXX(W) - ACK - 0x01 - ACK - 0x05 - ACK - STOP
   (waveform select = 101 = wavetable)

5. Enable oscillator:
   START - 0xXX(W) - ACK - 0x00 - ACK - 0x01 - ACK - STOP
```

**Python Example** (using smbus or similar):
```python
# Custom waveform: triangle variant
wavetable = [int(i * 255 / 63) if i < 32 else int((63-i) * 255 / 31) 
             for i in range(64)]

# Enable auto-increment
i2c.write_byte_data(addr, 0x12, 0x03)  # Reset + auto-increment

# Burst write wavetable
i2c.write_i2c_block_data(addr, 0x11, wavetable)

# Select wavetable and enable
i2c.write_byte_data(addr, 0x01, 0x05)  # Wavetable mode
i2c.write_byte_data(addr, 0x00, 0x01)  # Enable
```

### Example 7: Configure Filter Cutoff Modulation

**Target**: Classic "filter sweep" sound where ADSR envelope controls filter cutoff

```
1. Configure basic patch first (oscillator + ADSR + filter):
   START - 0xXX(W) - ACK - 0x01 - ACK - 0x01 - ACK - STOP  // Sawtooth wave
   START - 0xXX(W) - ACK - 0x07 - ACK - 0x10 - ACK - STOP  // Attack
   START - 0xXX(W) - ACK - 0x08 - ACK - 0x30 - ACK - STOP  // Decay
   START - 0xXX(W) - ACK - 0x09 - ACK - 0x60 - ACK - STOP  // Sustain
   START - 0xXX(W) - ACK - 0x0A - ACK - 0x40 - ACK - STOP  // Release

2. Set base filter cutoff (low starting point, 0x20):
   START - 0xXX(W) - ACK - 0x0C - ACK - 0x20 - ACK - STOP

3. Set filter mode (4-pole lowpass):
   START - 0xXX(W) - ACK - 0x10 - ACK - 0x00 - ACK - STOP

4. Enable filter:
   START - 0xXX(W) - ACK - 0x11 - ACK - 0x01 - ACK - STOP

5. Set modulation depth for cutoff (0x80 = full modulation range):
   START - 0xXX(W) - ACK - 0x17 - ACK - 0x80 - ACK - STOP

6. Enable filter cutoff modulation (bit 0 = cutoff):
   START - 0xXX(W) - ACK - 0x16 - ACK - 0x01 - ACK - STOP

7. Enable oscillator:
   START - 0xXX(W) - ACK - 0x00 - ACK - 0x01 - ACK - STOP
```

**Result**: Filter cutoff sweeps from low to high as envelope progresses through Attack/Decay to Sustain, then sweeps back down during Release. Base cutoff of 0x20 with modulation depth 0x80 gives range of approximately 0x00 to 0xA0 (centered on base).

### Example 8: Configure Pitch Envelope (Vibrato/Pitch Bend)

**Target**: Pitch modulation for vibrato or pitch bend effects

```
1. Configure oscillator for 440 Hz:
   START - 0xXX(W) - ACK - 0x02 - ACK - 0x00 - ACK - STOP  // Freq Low
   START - 0xXX(W) - ACK - 0x03 - ACK - 0x40 - ACK - STOP  // Freq Mid
   START - 0xXX(W) - ACK - 0x04 - ACK - 0x02 - ACK - STOP  // Freq High

2. Configure ADSR for slow rise (vibrato-like):
   START - 0xXX(W) - ACK - 0x07 - ACK - 0x80 - ACK - STOP  // Slow attack
   START - 0xXX(W) - ACK - 0x08 - ACK - 0x00 - ACK - STOP  // No decay
   START - 0xXX(W) - ACK - 0x09 - ACK - 0xFF - ACK - STOP  // Full sustain
   START - 0xXX(W) - ACK - 0x0A - ACK - 0x80 - ACK - STOP  // Slow release

3. Set pitch modulation depth (0x20 = subtle, ~±2 semitones):
   START - 0xXX(W) - ACK - 0x19 - ACK - 0x20 - ACK - STOP

4. Enable pitch modulation (bit 2 = pitch):
   START - 0xXX(W) - ACK - 0x16 - ACK - 0x04 - ACK - STOP

5. Enable oscillator:
   START - 0xXX(W) - ACK - 0x00 - ACK - 0x01 - ACK - STOP
```

**Result**: Pitch slowly rises from below 440 Hz to above as envelope attacks, holds at max during sustain, then falls back during release.

### Example 9: Configure Multiple Modulation Targets

**Target**: Classic analog synth patch with both filter and pitch modulation

```
1. Set modulation depths:
   START - 0xXX(W) - ACK - 0x17 - ACK - 0xA0 - ACK - STOP  // Filter cutoff depth
   START - 0xXX(W) - ACK - 0x18 - ACK - 0x40 - ACK - STOP  // Resonance depth
   START - 0xXX(W) - ACK - 0x19 - ACK - 0x10 - ACK - STOP  // Pitch depth (subtle)

2. Enable all three modulation targets (bits 2:0 = 0b111):
   START - 0xXX(W) - ACK - 0x16 - ACK - 0x07 - ACK - STOP
```

**Result**: ADSR envelope simultaneously modulates filter cutoff, filter resonance, and oscillator pitch for rich, expressive sound.

### Example 10: Silicon Debug - Bypass Oscillator

**Target**: If manufactured chip produces no output, isolate oscillator subsystem

```
1. Enable oscillator bypass (forces DC mid-scale output):
   START - 0xXX(W) - ACK - 0x1A - ACK - 0x01 - ACK - STOP

2. Check if DAC output shows DC mid-scale (~0x80):
   - If YES: Oscillator is faulty, rest of chain works
   - If NO: Problem is elsewhere in signal chain
```

### Example 11: Silicon Debug - Bypass Filter

**Target**: Test if filter subsystem is causing issues

```
1. Configure normal patch:
   START - 0xXX(W) - ACK - 0x00 - ACK - 0x01 - ACK - STOP  // Enable oscillator
   START - 0xXX(W) - ACK - 0x11 - ACK - 0x01 - ACK - STOP  // Enable filter

2. Enable filter bypass (passes signal through unchanged):
   START - 0xXX(W) - ACK - 0x1A - ACK - 0x04 - ACK - STOP

3. Listen/measure output:
   - If output improves: Filter is faulty
   - If no change: Filter is working, issue elsewhere
```

### Example 12: Silicon Debug - Test Wavetable RAM

**Target**: Verify wavetable RAM is functional

```
1. Load known simple pattern (alternating 0x00, 0xFF):
   START - 0xXX(W) - ACK - 0x15 - ACK - 0x03 - ACK - STOP  // Reset + auto-inc
   START - 0xXX(W) - ACK - 0x14 - ACK - 0x00 - ACK - 0xFF - ACK - 0x00 - ACK -
   0xFF - ACK ... [repeat 32 times] ... - STOP

2. Select wavetable:
   START - 0xXX(W) - ACK - 0x01 - ACK - 0x05 - ACK - STOP

3. If wavetable fails, disable it via bypass:
   START - 0xXX(W) - ACK - 0x1A - ACK - 0x08 - ACK - STOP

4. Revert to basic waveform:
   START - 0xXX(W) - ACK - 0x01 - ACK - 0x00 - ACK - STOP  // Sine wave
```

**Result**: Can continue using chip with basic waveforms even if wavetable RAM is defective.

### Example 13: Silicon Debug - Full Bypass Test Sequence

**Target**: Systematically isolate all subsystems

```python
# Python script for systematic debugging
import smbus

i2c = smbus.SMBus(1)
addr = 0xXX  # Replace with actual I2C address

# Test 1: Bypass oscillator
i2c.write_byte_data(addr, 0x1A, 0x01)
# Check output: Should be DC ~128

# Test 2: Bypass ADSR
i2c.write_byte_data(addr, 0x1A, 0x02)
# Check output: Envelope forced to max, sound should be constant amplitude

# Test 3: Bypass filter
i2c.write_byte_data(addr, 0x1A, 0x04)
# Check output: Raw oscillator sound, no filtering

# Test 4: Disable wavetable
i2c.write_byte_data(addr, 0x1A, 0x08)
# Select wavetable mode - should fall back to sine
i2c.write_byte_data(addr, 0x01, 0x05)

# Test 5: Normal operation (clear all bypasses)
i2c.write_byte_data(addr, 0x1A, 0x00)
```

### Example 14: Configure Pure Sine Wave (Using Mixer)

**Target**: Single pure sine wave using the mixer (backward compatible mode)

```
1. Set sine gain to full, all others to zero:
   START - 0xXX(W) - ACK - 0x1B - ACK - 0x00 - ACK - STOP  // Square = 0
   START - 0xXX(W) - ACK - 0x1C - ACK - 0x00 - ACK - STOP  // Sawtooth = 0
   START - 0xXX(W) - ACK - 0x1D - ACK - 0x00 - ACK - STOP  // Triangle = 0
   START - 0xXX(W) - ACK - 0x1E - ACK - 0xFF - ACK - STOP  // Sine = full
   START - 0xXX(W) - ACK - 0x1F - ACK - 0x00 - ACK - STOP  // Noise = 0
   START - 0xXX(W) - ACK - 0x20 - ACK - 0x00 - ACK - STOP  // Wavetable = 0

2. Configure frequency and enable:
   START - 0xXX(W) - ACK - 0x02 - ACK - 0x00 - ACK - STOP  // Freq Low
   START - 0xXX(W) - ACK - 0x03 - ACK - 0x40 - ACK - STOP  // Freq Mid (440 Hz)
   START - 0xXX(W) - ACK - 0x04 - ACK - 0x02 - ACK - STOP  // Freq High
   START - 0xXX(W) - ACK - 0x00 - ACK - 0x01 - ACK - STOP  // Enable
```

**Result**: Pure 440 Hz sine wave output.

**Note**: Sine gain defaults to 0xFF, so if all other gains are at default (0x00), you get pure sine automatically.

### Example 15: 50/50 Mix of Sine and Sawtooth

**Target**: Smooth blend of two waveforms

```
1. Set sine and sawtooth to 50% each:
   START - 0xXX(W) - ACK - 0x1C - ACK - 0x80 - ACK - STOP  // Sawtooth = 128 (50%)
   START - 0xXX(W) - ACK - 0x1E - ACK - 0x80 - ACK - STOP  // Sine = 128 (50%)
   START - 0xXX(W) - ACK - 0x1B - ACK - 0x00 - ACK - STOP  // Square = 0
   START - 0xXX(W) - ACK - 0x1D - ACK - 0x00 - ACK - STOP  // Triangle = 0
   START - 0xXX(W) - ACK - 0x1F - ACK - 0x00 - ACK - STOP  // Noise = 0
   START - 0xXX(W) - ACK - 0x20 - ACK - 0x00 - ACK - STOP  // Wavetable = 0
```

**Result**: Rich timbre combining the warmth of sine with the brightness of sawtooth.

### Example 16: Complex Additive Timbre

**Target**: Mix multiple waveforms for complex sound

```
1. Set multiple gains for layered sound:
   START - 0xXX(W) - ACK - 0x1C - ACK - 0x60 - ACK - STOP  // Sawtooth = 96
   START - 0xXX(W) - ACK - 0x1D - ACK - 0x40 - ACK - STOP  // Triangle = 64
   START - 0xXX(W) - ACK - 0x1E - ACK - 0x80 - ACK - STOP  // Sine = 128
   START - 0xXX(W) - ACK - 0x1F - ACK - 0x10 - ACK - STOP  // Noise = 16 (subtle)
```

**Result**: Complex timbre: 50% sine + 37.5% sawtooth + 25% triangle + 6.25% noise = rich, organic sound.

**Calculation**: Total = 0x80 + 0x60 + 0x40 + 0x10 = 0x190 (400 decimal), divided by 256 and clamped = 0xFF (full scale).

### Example 17: Smooth Morphing Between Waveforms

**Target**: Gradually transition from square to sine over time

```python
# Python script for waveform morphing
import smbus
import time

i2c = smbus.SMBus(1)
addr = 0xXX

# Configure oscillator for 440 Hz
i2c.write_byte_data(addr, 0x02, 0x00)  # Freq Low
i2c.write_byte_data(addr, 0x03, 0x40)  # Freq Mid
i2c.write_byte_data(addr, 0x04, 0x02)  # Freq High
i2c.write_byte_data(addr, 0x00, 0x01)  # Enable

# Morph from square to sine over 2 seconds
for i in range(256):
    square_gain = 255 - i      # Decreases from 255 to 0
    sine_gain = i              # Increases from 0 to 255

    i2c.write_byte_data(addr, 0x1B, square_gain)   # Square
    i2c.write_byte_data(addr, 0x1E, sine_gain)     # Sine

    time.sleep(2.0 / 256)  # ~7.8 ms per step
```

**Result**: Smooth, click-free transition from harsh square wave to pure sine wave.

### Example 18: Additive Synthesis - Organ-Like Timbre

**Target**: Emulate pipe organ sound using multiple waveforms

```
1. Mix sine (fundamental) with triangle (harmonics):
   START - 0xXX(W) - ACK - 0x1D - ACK - 0x60 - ACK - STOP  // Triangle = 96
   START - 0xXX(W) - ACK - 0x1E - ACK - 0xFF - ACK - STOP  // Sine = 255 (fundamental)

2. All others zero:
   START - 0xXX(W) - ACK - 0x1B - ACK - 0x00 - ACK - STOP  // Square = 0
   START - 0xXX(W) - ACK - 0x1C - ACK - 0x00 - ACK - STOP  // Sawtooth = 0
   START - 0xXX(W) - ACK - 0x1F - ACK - 0x00 - ACK - STOP  // Noise = 0
   START - 0xXX(W) - ACK - 0x20 - ACK - 0x00 - ACK - STOP  // Wavetable = 0
```

**Result**: Pipe organ-like sound with strong fundamental (sine) and gentle even harmonics (triangle).

### Example 19: Lo-Fi Character with Noise

**Target**: Add subtle noise for analog character

```
1. Primary waveform with subtle noise:
   START - 0xXX(W) - ACK - 0x1C - ACK - 0xE0 - ACK - STOP  // Sawtooth = 224 (87.5%)
   START - 0xXX(W) - ACK - 0x1F - ACK - 0x20 - ACK - STOP  // Noise = 32 (12.5%)

2. All others zero:
   START - 0xXX(W) - ACK - 0x1B - ACK - 0x00 - ACK - STOP  // Square = 0
   START - 0xXX(W) - ACK - 0x1D - ACK - 0x00 - ACK - STOP  // Triangle = 0
   START - 0xXX(W) - ACK - 0x1E - ACK - 0x00 - ACK - STOP  // Sine = 0
   START - 0xXX(W) - ACK - 0x20 - ACK - 0x00 - ACK - STOP  // Wavetable = 0
```

**Result**: Sawtooth wave with subtle noise texture, reminiscent of analog synthesizers.

---

## 10. Testing Strategy

### Unit Tests

**I2C Interface**:
- Write to all registers, read back values
- Test burst writes
- Test invalid addresses
- Verify ACK/NACK behavior

**Oscillators**:
- Verify frequency accuracy across range
- Check waveform shape for all 6 types (FFT analysis)
- Test duty cycle range for square wave
- Verify sawtooth linearity and wraparound
- Verify LFSR period and randomness
- Test wavetable loading and playback with known waveforms

**ADSR Envelope**:
- Test gate on/off transitions
- Verify timing of each stage (use detailed timing table from Section 5.8)
- Test sustain holding
- Check release on gate off
- Verify envelope timing matches calculated values (20 ns to 333 ms)

**State-Variable Filter**:
- Verify cutoff frequency sweep (50 Hz to 20 kHz) for both SVF sections
- Test resonance range (Q from 0.5 to 10) for both sections
- Test all filter modes: 4-pole LP, 4-pole HP, 4-pole BP, 2-pole modes
- Measure frequency response at different cutoff settings for each mode
- Verify -24 dB/octave rolloff for 4-pole modes
- Verify -12 dB/octave rolloff for 2-pole modes
- Test bandpass center frequency and bandwidth accuracy
- Test self-oscillation at high resonance
- Verify bypass mode (filter disable)
- Test independent control of SVF1 and SVF2 parameters
- Verify mode switching between LP/HP/BP

**ADSR Modulation Routing**:
- Verify bipolar envelope conversion (envelope 128 = no modulation)
- Test filter cutoff modulation across full depth range (0-255)
- Test filter resonance modulation across full depth range
- Test pitch modulation for accuracy (±semitones scaling)
- Verify modulation enable/disable switches work correctly
- Test saturation behavior at parameter limits (0x00, 0xFF)
- Test all three modulation targets simultaneously
- Verify modulation depth of 0 produces no change
- Verify modulation depth of 255 produces maximum effect

**Bypass/Debug System**:
- Test oscillator bypass (verify DC mid-scale output ~0x80)
- Test ADSR bypass (verify envelope forced to 0xFF)
- Test filter bypass (verify signal passthrough)
- Test wavetable disable (verify fallback to sine wave)
- Test multiple bypasses simultaneously
- Verify normal operation with all bypasses disabled
- Test bypass switching during operation (no glitches)

**Waveform Mixer**:
- Verify single waveform operation (one gain at 0xFF, others at 0x00)
- Test 50/50 mix of two waveforms (both gains at 0x80)
- Test linear gain scaling for each waveform (0x00 to 0xFF)
- Verify saturation when sum exceeds 255 (e.g., all gains at 0xFF)
- Test smooth morphing between waveforms (gradual gain transitions)
- Verify multiplication accuracy for each channel (waveform × gain)
- Test adder tree accuracy (sum of all 6 products)
- Verify output equals 0x00 when all gains are 0x00
- Test complex mixes (multiple non-zero gains simultaneously)
- Measure THD for mixed outputs vs single waveforms
- Verify no clicks or glitches when changing gain values

**Amplitude Modulation**:
- Verify multiplication accuracy
- Test zero-crossing behavior
- Check amplitude scaling

**DAC**:
- Verify output spectrum
- Check for spurious tones
- Test different input amplitudes

### Integration Tests

1. **Full Chain Test**: Configure via I2C, trigger gate, verify audio output
2. **Frequency Sweep**: Sweep through octaves, verify accurate tuning
3. **Waveform Mixing - Pure Tones**: Test each waveform individually (one gain at 0xFF, others at 0x00)
4. **Waveform Mixing - 50/50 Blend**: Mix two waveforms at equal levels, verify timbre
5. **Waveform Mixing - Complex**: Mix 3+ waveforms simultaneously, verify saturation handling
6. **Waveform Morphing**: Gradually transition gains between waveforms, verify smooth crossfade
7. **Envelope Shapes**: Trigger notes with various ADSR settings
8. **Filter Sweep**: Sweep filter cutoff while playing tone, verify smooth response
9. **Resonance Test**: Test filter resonance at different cutoff frequencies
10. **Filter Mode Test**: Test LP, HP, and BP modes with same settings, verify correct response
11. **Wavetable Test**: Load known waveform, verify output matches expected
12. **Modulation Test - Filter Sweep**: Enable filter cutoff modulation, trigger note, verify filter sweeps with envelope
13. **Modulation Test - Pitch Bend**: Enable pitch modulation, verify pitch changes with envelope
14. **Modulation Test - Combined**: Enable multiple modulation targets, verify independent operation
15. **Bypass Test - Oscillator**: Enable oscillator bypass, verify DC output
16. **Bypass Test - Filter**: Enable filter bypass, verify unfiltered signal passes through
17. **Bypass Test - Sequential**: Enable bypasses one at a time, verify each subsystem isolation
18. **Complete Patch**: Test combination of mixed waveforms + ADSR + filter modulation (all modes)

### Hardware Verification

**Required Equipment**:
- I2C master (microcontroller, FTDI, etc.)
- Oscilloscope or logic analyzer
- Audio interface or spectrum analyzer
- Reference frequency counter

**Test Procedure**:
1. Verify I2C communication
2. Configure for 1 kHz tone, test each waveform individually via mixer (one gain at 0xFF)
3. Verify frequency accuracy for pure waveforms
4. Test waveform mixer:
    - 50/50 mix of sine + sawtooth, measure harmonic content
    - Complex mix (multiple waveforms), verify saturation behavior
    - Smooth morphing test (gradually change gains), verify no clicks
    - Measure THD for mixed vs pure waveforms
5. Test ADSR with gate pulses (verify timing table from Section 5.8)
6. Test SVF cutoff sweep with spectrum analyzer (all modes: LP/HP/BP)
7. Test SVF resonance (verify Q factor response)
8. Verify 4-pole rolloff (-24 dB/octave) vs 2-pole (-12 dB/octave)
9. Test bandpass mode: measure center frequency and bandwidth
10. Load custom wavetable (e.g., sine), verify output matches, test via mixer
11. Test ADSR modulation routing:
    - Configure filter cutoff modulation, measure filter sweep synchronized with envelope
    - Configure pitch modulation, measure frequency deviation
    - Configure combined modulation, verify independent operation
12. Test bypass/debug system:
    - Enable oscillator bypass, verify DC output at mid-scale
    - Enable ADSR bypass, verify constant amplitude
    - Enable filter bypass, verify unfiltered output
    - Test sequential bypass of each subsystem for silicon debug
13. Perform comprehensive THD measurement for mixed waveforms
14. Test complete synthesizer voice (mixed waveforms + ADSR + SVF all modes + modulation)

---

## 11. Synthesis Considerations

### Attributes Required

**LFSR Protection**:
```verilog
(* keep = "true" *)
reg [31:0] lfsr;
```
Prevents optimizer from recognizing and collapsing the LFSR pattern.

**Critical Paths**:
```verilog
(* max_fanout = 4 *)
wire clk_buffered;
```
Limits fanout on high-fanout signals.

### Timing Constraints

**Clock Constraint**:
```sdc
create_clock -name clk -period 20.0 [get_ports clk]
```

**Input Delays** (for I2C):
```sdc
set_input_delay -clock clk -max 5.0 [get_ports {ui_in[0] ui_in[1]}]
set_input_delay -clock clk -min 1.0 [get_ports {ui_in[0] ui_in[1]}]
```

**Output Delays**:
```sdc
set_output_delay -clock clk -max 5.0 [get_ports {uo_out[*]}]
```

### Optimization Settings

- **Multiplier Inference**: Allow synthesis to infer DSP blocks if available
- **FSM Encoding**: One-hot encoding for state machines (better for FPGAs)
- **Clock Gating**: Enable for power optimization
- **Retiming**: Enable to balance pipeline stages

### Common Issues

**Issue 1**: LFSR optimized away
- **Solution**: Add `(* keep *)` attribute

**Issue 2**: I2C glitches on SDA/SCL
- **Solution**: Add synchronizers (included in design)

**Issue 3**: Multiplier too large
- **Solution**: Reduce to 8×8 if 16-bit not needed

**Issue 4**: Setup/hold violations on I2C
- **Solution**: Add timing constraints, increase synchronizer depth

---

## 12. Future Enhancements

With 8.0% (319 cells) still available, the following enhancements are possible:

### Currently Implemented Features (v1.3)

The design now includes:
- **6-Channel Waveform Mixer** (642 cells): Smooth mixing and morphing between all waveforms
- **ADSR Modulation Routing** (348 cells): Filter and pitch modulation from envelope
- **Bypass/Debug System** (72 cells): Silicon debugging capability
- **4-Pole State-Variable Filter** (1360 cells): LP/HP/BP modes
- **64-Sample Wavetable** (512 cells): User-programmable waveforms

**Total Resource Usage**: 3,681 cells (92.0% of 1x1 tile)
**Remaining Capacity**: 319 cells (8.0%)

### Polyphony (2 voices total)

**Additional Resources**: ~1,477 cells (37% total, for 1 more voice with SVF)

Instantiate 1 more complete oscillator+ADSR+SVF channel. Add a simple mixer to combine outputs.

**Note**: With the 4-pole SVF filter, each additional voice requires ~1,477 cells (oscillator + ADSR + SVF). This would exceed current capacity; requires 1x2 tile or feature reduction.

**Benefits**:
- 2-note polyphony
- Richer sound through voice layering
- Interval and chord capabilities
- Independent filter settings per voice

### Effects Processing

**Delay Line (128 samples)**:
- **Resources**: ~1024 cells
- **Function**: Echo, chorus, flanger effects

**Ring Modulator**:
- **Resources**: ~60 cells
- **Function**: Metallic, inharmonic tones

**Note**: Highpass and bandpass filter modes are already included in the SVF implementation.

### Modulation Sources

**LFO (Low Frequency Oscillator)**:
- **Resources**: ~100 cells
- **Function**: Vibrato, tremolo, filter sweep

**Second ADSR (for filter modulation)**:
- **Resources**: ~135 cells
- **Function**: Independent filter envelope

### Advanced Features

**Portamento/Glide**:
- **Resources**: ~60 cells
- **Function**: Smooth frequency transitions

**Velocity Sensitivity**:
- **Resources**: ~20 cells
- **Function**: MIDI velocity to amplitude/filter

**PWM Modulation**:
- **Resources**: ~40 cells
- **Function**: Animated square wave

### Possible Enhancements with Remaining Capacity

**Current Design v1.3** (3,681 cells, 92.0% utilization):
```
- Oscillators (6 types):        485 cells
- ADSR Envelope:                135 cells
- State-Variable Filter (4p):  1360 cells
- Wavetable (64 samples):       497 cells
- Waveform Mixer (6-channel):   642 cells
- ADSR Modulation Routing:      348 cells
- Bypass/Debug System:           72 cells
- I2C Interface & Registers:     60 cells (33 registers)
- Delta-Sigma DAC:               50 cells
- Pipeline & Infrastructure:     32 cells
─────────────────────────────────
Total:                         3,681 cells (92.0%)
Remaining:                      ~319 cells (8.0%)
```

**Option A: LFO Addition** (~3,781 cells, 94.5% utilization):
```
- Current design (v1.3):  3,681 cells
- LFO (simple):             100 cells (phase accumulator + sine/triangle/square output)
─────────────────────────────────
Total:                    3,781 cells (94.5%)
Remaining:                 ~219 cells (5.5%)
```

**Benefits**: Vibrato, tremolo, automated filter sweeps, PWM animation

**Option B: PWM + Portamento + Extras** (~3,921 cells, 98.0% utilization):
```
- Current design (v1.3):  3,681 cells
- PWM modulation:            40 cells (square wave duty cycle LFO)
- Portamento/glide:          60 cells (frequency interpolator)
- Ring modulator:            60 cells (waveform × waveform)
- Additional features:       80 cells (routing, control registers)
─────────────────────────────────
Total:                    3,921 cells (98.0%)
Remaining:                  ~79 cells (2.0%)
```

**Benefits**: Complete monosynth with all classic features

**Option C: Second ADSR** (~3,816 cells, 95.4% utilization):
```
- Current design (v1.3):  3,681 cells
- Second ADSR envelope:     135 cells (independent filter envelope)
─────────────────────────────────
Total:                    3,816 cells (95.4%)
Remaining:                 ~184 cells (4.6%)
```

**Benefits**: Independent filter envelope separate from amplitude envelope (classic analog synth architecture)

**Design Philosophy**: The current v1.3 design represents a complete, feature-rich monosynth with:
- Advanced waveform synthesis (6-channel mixer for complex timbres)
- Powerful filtering (4-pole SVF with LP/HP/BP modes)
- Expressive modulation (ADSR → filter cutoff/resonance/pitch)
- User programmability (64-sample wavetable)
- Silicon reliability (comprehensive bypass/debug system)

The remaining 8% capacity can add specialized features based on user preference, but the core synthesizer is already highly capable.

---

## 13. Reference Information

### Useful Formulas

**Frequency to Phase Increment**:
```
phase_inc = (target_freq × 2^24) / clock_freq
```

**ADSR Rate to Time**:
```
time_samples = rate_value × 256
time_seconds = time_samples / clock_freq
```

**Delta-Sigma SNR**:
```
SNR_dB ≈ 6.02 × N + 1.76 - 10×log10(OSR)
Where N = accumulator bits, OSR = oversampling ratio
```

### Recommended External Components

**Minimum**:
- 1kΩ resistor (DAC output)
- 10nF capacitor (DAC filter)
- I2C pull-up resistors (4.7kΩ typical)

**Enhanced**:
- Operational amplifier (output buffering)
- Multiple pole filter (better DAC filtering)
- Protection diodes

### Additional Resources

- **TinyTapeout Documentation**: https://tinytapeout.com/
- **I2C Specification**: NXP UM10204
- **Delta-Sigma Converters**: Various application notes
- **LFSR Theory**: Xilinx XAPP052

---

## Document Revision History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-11-08 | Ron Sardarian | Initial specification with 6 waveforms (square, sawtooth, triangle, sine, noise, user wavetable), 64-sample programmable wavetable, ADSR envelope with detailed timing (20 ns to 333 ms), 2-pole resonant lowpass filter, and I2C control interface. Total resource usage: 1539 cells (38.5%). |
| 1.1 | 2025-11-08 | Ron Sardarian | Upgraded filter from 2-pole lowpass to 4-pole state-variable filter with simultaneous LP/HP/BP modes. Added independent control for two SVF sections. Updated register map (added 0x0F-0x11, renumbered status and wavetable registers). Total resource usage: 2477 cells (61.9%). Remaining capacity: 1523 cells (38.1%). |
| 1.2 | 2025-11-08 | Ron Sardarian | Added ADSR modulation routing (348 cells) for filter cutoff, filter resonance, and oscillator pitch. Added comprehensive bypass/debug system (72 cells) for silicon debugging with individual subsystem isolation. Extended register map (added 0x16-0x1A). Added Section 5.12 (Modulation Routing), Section 5.13 (Bypass System), renumbered Delta-Sigma DAC to Section 5.14. Added 7 new I2C protocol examples for modulation and silicon debug. Updated testing strategy with modulation and bypass tests. Total resource usage: 3039 cells (76.0%). Remaining capacity: 961 cells (24.0%). Future enhancement: waveform mixer (planned, ~642 cells). |
| 1.3 | 2025-11-08 | Ron Sardarian | Implemented 6-channel waveform mixer (642 cells) replacing the 6:1 waveform selector. Added 6 mixer gain registers (0x1B-0x20) for independent gain control of each waveform. Replaced Section 5.8 (Waveform Selector → Waveform Mixer) with complete Verilog implementation including 6× multipliers, adder tree, saturation logic, and output register. Updated register bank to 33×8 registers. Added 6 new I2C protocol examples (Examples 14-19) demonstrating pure waveforms, 50/50 mixes, complex additive timbres, smooth morphing, organ-like sounds, and lo-fi character. Updated testing strategy with 11 mixer unit tests and 4 mixer integration tests. Updated module hierarchy to show waveform_mixer with detailed subcomponents. Updated Future Enhancements with 3 new configuration options for remaining capacity. Total resource usage: 3681 cells (92.0%). Remaining capacity: 319 cells (8.0%). |
| 1.4 | 2025-11-08 | Ron Sardarian | Added glide/portamento (60 cells), PWM modulation (40 cells), and ring modulator (90 cells) to maximize remaining capacity. Added 3 new registers (0x21-0x23) for glide rate, PWM depth, and ring mod configuration. Updated register bank to 36×8 registers. Added Section 5.9 (Glide/Portamento) with exponential-like frequency slew limiter. Added Section 5.10 (PWM Modulation) for ADSR-controlled pulse width modulation. Added Section 5.11 (Ring Modulator) with selectable source cross-modulation and pre/post-mixer routing. Renumbered subsequent sections (ADSR 5.9→5.12, Amp Mod 5.10→5.13, SVF 5.11→5.14, Mod Routing 5.12→5.15, Bypass 5.13→5.16, DAC 5.14→5.17). Updated signal flow with 13 stages including glide and ring mod. Total resource usage: 3891 cells (97.3%). Remaining capacity: 109 cells (2.7%). Professional monosynth feature complete. |

---

*End of Specification Document*

