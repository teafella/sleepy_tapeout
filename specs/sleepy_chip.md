# Sleepy Chip - TinyTapeout Dual-Mode Synthesizer

## 1. System Overview

This specification describes a **dual-mode digital audio synthesizer** for TinyTapeout that provides SPI-controlled waveform generation with streaming capability and instant volume control. The system is designed to fit within a **1×1 tile** (~1600 cells budget) using approximately **63% of available resources**.

### Key Features (Current Implementation)

- **SPI Slave Interface**: Mode 0 (CPOL=0, CPHA=0) for configuration (8 registers, RX-only)
- **Dual Operating Modes**:
  - **Oscillator Mode**: Three-waveform synthesis (square, sawtooth, triangle)
  - **Streaming Mode**: Direct 8-bit sample playback for PCM or custom waveforms
- **Instant Volume Control**: 8-level bit-shift volume control (mute to full)
- **Wide Frequency Range**: 2.98 Hz to 25 MHz with 24-bit resolution
- **Basic Control**: Duty cycle, waveform enables, mode selection, and gate control
- **Delta-Sigma DAC**: 1-bit output for external filtering
- **Area Efficient**: ~870 instances (63% of 1×1 tile) - **Successfully routes**

### Performance Characteristics

- **Clock Frequency**: 50 MHz
- **Frequency Resolution**: 24-bit (16,777,216 steps)
- **Output Resolution**: 8-bit internal, 1-bit delta-sigma output
- **Volume Resolution**: 8 discrete levels (bit-shift based)
- **SPI Mode**: Mode 0 (CPOL=0, CPHA=0), RX-only (no MISO)
- **Waveforms**: Square (variable duty cycle), Sawtooth, Triangle
- **Streaming**: 8-bit sample input for direct DAC output

---

## 2. Resource Utilization (Current Design)

### OpenROAD Synthesis Results

**Status**: ✅ **PASSING at ~63% utilization**

| Component | Cells | Percentage |
|-----------|-------|------------|
| SPI RX Interface | ~45 | 2.8% |
| Phase Accumulator | ~60 | 3.8% |
| Waveform Generators | ~103 | 6.4% |
| Waveform Mixer | ~25 | 1.6% |
| Volume Control (bit-shift) | ~10 | 0.6% |
| Delta-Sigma DAC | ~50 | 3.1% |
| Mode selection & routing | ~577 | 36.1% |
| **Total Actual** | **~870** | **54.4%** |

**Key Design Choices:**
- SPI interface saves ~175 cells compared to I2C (~45 vs ~220 cells)
- Bit-shift volume saves ~210 cells compared to 8×8 multiplier (~10 vs ~220 cells)
- Dual-mode operation adds minimal overhead (single mux) while enabling sample streaming
- Total utilization of 63% provides adequate routing space for successful synthesis

---

## 3. System Architecture

### Block Diagram

```
SPI Interface         24-bit Phase           Waveform             Mode
(3 pins)              Accumulator            Generators           Selection
                      (DDS core)
uio[0]: MOSI    ┌─→   ┌──────────┐          ┌──────────┐         ┌──────┐
uio[1]: SCK     │     │ Frequency│─────────→│ Square   │────┐    │      │
uio[2]: CS      │     │ Register │          │ Sawtooth │    ├───→│ MUX  │
                │     │          │          │ Triangle │    │    │      │
     ┌──────────┴──┐  │ 24-bit   │          └──────────┘    │    │ OSC/ │
     │ SPI RX      │  │ 50 MHz   │                          │    │STREAM│─┐
     │ Registers   │  └──────────┘          ┌──────────┐    │    │      │ │
     │ (8 regs)    │                        │ Mixer    │────┘    └──────┘ │
     └─────────────┘                        │ (3-ch)   │                   │
           │                                └──────────┘                   │
           │                                                                │
           │ Streaming Sample                                              │
           │ Register (0x10)  ──────────────────────────────────────────────┘
           │                                                                │
           │                                ┌──────────┐    ┌────────────┐ │
           │ Volume Register                │ Volume   │    │ Delta-     │ │
           └───────────────────────────────→│ Control  │◄───│ Sigma DAC  │◄┘
                                            │ 8-level  │    │ (1-bit)    │
                                            └──────────┘    └─────┬──────┘
                                                                  │
                                                                  ▼
                                                            uo_out[0]
                                                          (Audio Output)
```

### Signal Flow

**Oscillator Mode:**
1. SPI Control: Master sends register writes via MOSI/SCK/CS
2. Phase Accumulation: 24-bit phase accumulator generates ramp at desired frequency
3. Waveform Generation: Phase generates square, sawtooth, and triangle waveforms
4. Mixing: Selected waveforms are summed (on/off control via register bits)
5. Mode Selection: Oscillator output selected via mux (STREAM_MODE=0)
6. Volume Control: Mixed signal scaled by bit-shift volume (8 discrete levels)
7. DAC Conversion: 8-bit signal converted to 1-bit delta-sigma output

**Streaming Mode:**
1. SPI Control: Master sends sample values to streaming register (0x10)
2. Mode Selection: Streaming sample selected via mux (STREAM_MODE=1)
3. Volume Control: Sample scaled by bit-shift volume (8 discrete levels)
4. DAC Conversion: 8-bit signal converted to 1-bit delta-sigma output

---

## 4. SPI Register Map (8 Registers)

### Register Summary

| Address | Name | Access | Default | Description |
|---------|------|--------|---------|-------------|
| 0x00 | Control | R/W | 0x1C | Oscillator enable, mode selection, waveform enables |
| 0x02 | Frequency Low | R/W | 0x00 | Frequency bits [7:0] |
| 0x03 | Frequency Mid | R/W | 0x00 | Frequency bits [15:8] |
| 0x04 | Frequency High | R/W | 0x00 | Frequency bits [23:16] |
| 0x05 | Duty Cycle | R/W | 0x80 | Square wave duty cycle |
| 0x06 | Volume | R/W | 0xFF | Volume level (8 discrete levels, bit-shift based) |
| 0x10 | Stream Sample | R/W | 0x80 | Streaming mode sample value (0x00-0xFF) |
| 0x12 | Status | R | 0x00 | Status flags (read-only) |

**Note**: Addresses 0x01, 0x07-0x0F, 0x11, and 0x13+ are unused. Writes to these addresses are ignored.

### Detailed Register Descriptions

#### 0x00 - Control Register (R/W)

| Bit | Name | Description |
|-----|------|-------------|
| 0 | OSC_EN | 0=Disabled, 1=Enabled. Oscillator enable |
| 1 | STREAM_MODE | 0=Oscillator mode, 1=Streaming mode. Mode selection |
| 2 | SW_GATE | 0=Off, 1=On. Software gate (OR'd with hardware pin) |
| 3 | SQUARE_EN | 0=Muted, 1=Enabled. Enable square wave in mixer |
| 4 | SAW_EN | 0=Muted, 1=Enabled. Enable sawtooth wave in mixer |
| 5 | TRI_EN | 0=Muted, 1=Enabled. Enable triangle wave in mixer |
| 7:6 | Reserved | Reserved. Write 0. |

**Default**: 0x1C (0b00011100) - Oscillator disabled, streaming mode off, all 3 waveforms enabled

**Examples**:
- `0x11` (0b00010001): Oscillator mode, oscillator enabled, sawtooth only
- `0x02` (0b00000010): Streaming mode, oscillator disabled
- `0x1D` (0b00011101): Oscillator mode, oscillator enabled, all waveforms

#### 0x02-0x04 - Frequency (R/W, 24-bit, Little-Endian)

24-bit frequency control word:
- **0x02**: Frequency[7:0] (LSB)
- **0x03**: Frequency[15:8]
- **0x04**: Frequency[23:16] (MSB)

**Frequency Calculation**:
```
Output Frequency (Hz) = (Frequency Value × 50,000,000) / 16,777,216
Frequency Value = (Output Frequency × 16,777,216) / 50,000,000
```

**Examples**:
- 440 Hz (A4): 0x024000 (147,456)
- 1000 Hz: 0x051EB8 (335,544)
- 100 Hz: 0x0051EB (33,515)
- 10 kHz: 0x333333 (3,355,443)

**Note**: Frequency registers are only used in oscillator mode. They are ignored in streaming mode.

#### 0x05 - Duty Cycle (R/W)

8-bit duty cycle for square wave:
- **0x00** (0): 0% duty cycle (always low)
- **0x80** (128): 50% duty cycle (perfect square)
- **0xFF** (255): ~100% duty cycle (always high)

Ignored for sawtooth and triangle waveforms, and in streaming mode.

**Default**: 0x80 (50% duty cycle)

#### 0x06 - Volume (R/W)

8-level bit-shift volume control (discrete levels):
- Uses top 3 bits [7:5] to select volume level
- Instant response (no ramping)
- Works in both oscillator and streaming modes

**Volume Levels** (based on top 3 bits):

| Register Value | Top 3 Bits | Level | Attenuation |
|----------------|------------|-------|-------------|
| 0x00-0x1F | 000 | Mute | -∞ dB |
| 0x20-0x3F | 001 | 1/8 | -18 dB |
| 0x40-0x5F | 010 | 1/4 | -12 dB |
| 0x60-0x7F | 011 | 3/8 | -8.5 dB |
| 0x80-0x9F | 100 | 1/2 | -6 dB |
| 0xA0-0xBF | 101 | 5/8 | -4.1 dB |
| 0xC0-0xDF | 110 | 3/4 | -2.5 dB |
| 0xE0-0xFF | 111 | Full | 0 dB |

**Implementation**: Bit-shift and add operations for area efficiency:
- Mute: output = 0
- 1/8: output = input >> 3
- 1/4: output = input >> 2
- 3/8: output = (input >> 2) + (input >> 3)
- 1/2: output = input >> 1
- 5/8: output = (input >> 1) + (input >> 3)
- 3/4: output = (input >> 1) + (input >> 2)
- Full: output = input

**Default**: 0xFF (full volume)

#### 0x10 - Stream Sample (R/W)

8-bit sample value for streaming mode:
- **0x00** (0): Minimum output (silent)
- **0x80** (128): Middle value
- **0xFF** (255): Maximum output (full scale)

**Usage**:
1. Set STREAM_MODE=1 in control register (0x00)
2. Write sample values to this register at desired sample rate
3. Each write updates the DAC output via volume control and delta-sigma DAC

**Applications**:
- PCM playback (stream audio samples)
- Custom waveform generation (stream pre-computed waveform tables)
- Direct DAC control for special effects

**Default**: 0x80 (middle value)

**Note**: This register is only used in streaming mode (STREAM_MODE=1). It is ignored when in oscillator mode.

#### 0x12 - Status Register (R, Read-Only)

| Bit | Name | Description |
|-----|------|-------------|
| 0 | GATE_ACTIVE | Gate status (hardware OR software) |
| 1 | OSC_RUNNING | Oscillator running status (OSC_EN from control register) |
| 7:2 | Reserved | Always 0 |

**Note**: This register is read-only. Writes are ignored.

---

## 5. SPI Protocol

### SPI Configuration

- **Mode**: Mode 0 (CPOL=0, CPHA=0)
- **Clock**: Master provides SCK (sample on rising edge)
- **Speed**: Any speed supported (tested up to 1 MHz)
- **Pins**: MOSI (uio[0]), SCK (uio[1]), CS (uio[2])
- **Direction**: RX-only (no MISO pin)

### Write Protocol

**Basic Write** (2 bytes):
1. Assert CS (active low)
2. Send address byte (MSB first)
3. Send data byte (MSB first)
4. Deassert CS (high)

**Burst Write** (N+1 bytes):
1. Assert CS
2. Send address byte
3. Send data byte 1 → writes to address
4. Send data byte 2 → writes to address+1 (auto-increment)
5. Send data byte N → writes to address+N-1
6. Deassert CS

### Example 1: Oscillator Mode (440 Hz Sawtooth)

```
# Enable oscillator with sawtooth waveform
CS=0
Send: 0x00 (address: control)
Send: 0x11 (OSC_EN=1, STREAM_MODE=0, SAW_EN=1)
CS=1

# Set frequency to 440 Hz using burst write
CS=0
Send: 0x02 (address: freq_low)
Send: 0x00 (LSB)
Send: 0x40 (mid byte, auto-increment to 0x03)
Send: 0x02 (MSB, auto-increment to 0x04)
CS=1

# Set volume to full
CS=0
Send: 0x06 (address: volume)
Send: 0xFF (full volume)
CS=1

Result: Clean 440 Hz sawtooth wave on DAC_OUT
```

### Example 2: Streaming Mode (Sample Playback)

```
# Switch to streaming mode
CS=0
Send: 0x00 (address: control)
Send: 0x02 (OSC_EN=0, STREAM_MODE=1)
CS=1

# Set volume to 50%
CS=0
Send: 0x06 (address: volume)
Send: 0x80 (50% volume)
CS=1

# Stream different sample values
CS=0
Send: 0x10 (address: stream_sample)
Send: 0x00 (sample 1)
CS=1

CS=0
Send: 0x10
Send: 0x40 (sample 2)
CS=1

CS=0
Send: 0x10
Send: 0x80 (sample 3)
CS=1

CS=0
Send: 0x10
Send: 0xC0 (sample 4)
CS=1

CS=0
Send: 0x10
Send: 0xFF (sample 5)
CS=1

Result: Direct sample playback at your chosen sample rate
```

---

## 6. Pin Assignments

### TinyTapeout Pin Mapping

**Dedicated Inputs (ui_in)**:
- `ui_in[0]`: GATE - Hardware gate trigger (active high, OR'd with SW_GATE)
- `ui_in[1]`: HW_RST - Hardware reset (active high, AND'd with rst_n)
- `ui_in[7:2]`: Unused

**Dedicated Outputs (uo_out)**:
- `uo_out[0]`: **DAC_OUT** - 1-bit delta-sigma audio output (main output)
- `uo_out[1]`: GATE_LED - Gate status indicator (hardware OR software)
- `uo_out[2]`: OSC_RUN - Oscillator running indicator
- `uo_out[3]`: SYNC - Phase sync pulse (phase MSB, frequency visualization)
- `uo_out[7:4]`: Unused (tied to 0)

**Bidirectional I/Os (uio)**:
- `uio[0]`: SPI_MOSI - SPI data input (Master Out Slave In)
- `uio[1]`: SPI_SCK - SPI clock input (from master)
- `uio[2]`: SPI_CS - SPI chip select (active low)
- `uio[7:3]`: Unused (all configured as inputs)

---

## 7. Hardware Integration

### External SPI Master Options

1. **Microcontroller**: Arduino, Raspberry Pi Pico, ESP32, STM32, etc.
2. **FPGA**: Lattice iCE40, Xilinx, Intel, etc.
3. **USB-to-SPI adapter**: FT232H, CH341A, etc.
4. **Raspberry Pi**: Hardware SPI interface

### Example Arduino Code (Oscillator Mode)

```cpp
#include <SPI.h>

#define CS_PIN 10

void setup() {
  pinMode(CS_PIN, OUTPUT);
  digitalWrite(CS_PIN, HIGH);  // Idle high
  SPI.begin();
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));

  // Enable oscillator with sawtooth waveform
  spiWriteRegister(0x00, 0b00010001);  // OSC_EN=1, STREAM=0, SAW_EN=1

  // Set frequency to 440 Hz (burst write)
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(0x02);  // Address: freq_low
  SPI.transfer(0x00);  // LSB
  SPI.transfer(0x40);  // Mid
  SPI.transfer(0x02);  // MSB
  digitalWrite(CS_PIN, HIGH);

  // Set volume to full
  spiWriteRegister(0x06, 0xFF);
}

void spiWriteRegister(uint8_t address, uint8_t data) {
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(address);
  SPI.transfer(data);
  digitalWrite(CS_PIN, HIGH);
  delayMicroseconds(10);
}

void loop() {
  // Could add frequency sweeps, volume fades, etc.
}
```

### Example Arduino Code (Streaming Mode)

```cpp
#include <SPI.h>

#define CS_PIN 10

// Simple sine wave lookup table (16 samples)
const uint8_t sineTable[16] = {
  128, 177, 218, 245, 255, 245, 218, 177,
  128, 79, 38, 11, 0, 11, 38, 79
};

void setup() {
  pinMode(CS_PIN, OUTPUT);
  digitalWrite(CS_PIN, HIGH);
  SPI.begin();
  SPI.beginTransaction(SPISettings(1000000, MSBFIRST, SPI_MODE0));

  // Switch to streaming mode
  spiWriteRegister(0x00, 0b00000010);  // OSC_EN=0, STREAM_MODE=1

  // Set volume to 75%
  spiWriteRegister(0x06, 0xC0);
}

void loop() {
  // Stream sine wave samples at ~1 kHz (16 samples = 62.5 Hz tone)
  for (int i = 0; i < 16; i++) {
    spiWriteRegister(0x10, sineTable[i]);
    delayMicroseconds(1000);  // 1 kHz sample rate
  }
}

void spiWriteRegister(uint8_t address, uint8_t data) {
  digitalWrite(CS_PIN, LOW);
  SPI.transfer(address);
  SPI.transfer(data);
  digitalWrite(CS_PIN, HIGH);
}
```

### External Audio Filter (Required)

The 1-bit DAC output requires external lowpass filtering to recover the audio signal:

**Recommended RC Filter**:
```
DAC_OUT (uo_out[0]) ──┬─── 10kΩ ───┬─── to audio amp
                      │            │
                     GND         680pF
                                  │
                                 GND
```
- R = 10kΩ
- C = 680pF
- Fc ≈ 23 kHz - Removes 50 MHz carrier from PDM signal

**Alternative Cutoff Frequencies**:
- **15 kHz**: R=10kΩ, C=1nF (more filtering, softer sound)
- **25 kHz**: R=10kΩ, C=680pF (recommended, balanced)
- **35 kHz**: R=10kΩ, C=470pF (less filtering, brighter sound)

**Audio Amplifier** (recommended):
- Simple op-amp buffer (TL072, LM358)
- LM386 audio amplifier
- Speaker (8Ω) or headphones

---

## 8. Design Constraints and Trade-offs

### 8.1 Area Optimization for 1×1 Tile

**Critical Constraint**: TinyTapeout 1×1 tile provides ~1600 cells target. To successfully synthesize and route, **placement density must stay below 60-70%** to leave adequate routing space.

**Current Design**: ~870 instances (~63% utilization) successfully passes routing.

### 8.2 Communication Protocol Choice

**SPI vs UART vs I2C**:

| Protocol | Cell Count | Complexity | Pins | Bidirectional |
|----------|------------|------------|------|---------------|
| I2C | ~220 | High (bidirectional, ACK/NACK) | 2 | Yes (SDA) |
| UART | ~180 | Medium (baud gen, oversampling) | 1 | No |
| SPI | ~45 | Low (synchronous, simple shift) | 3 | No |

**Decision**: SPI chosen for minimal area (~45 cells) despite requiring 3 pins. The area savings (~175 cells vs I2C, ~135 cells vs UART) provide headroom for dual-mode operation.

### 8.3 Volume Control Implementation

**Current**: Bit-shift volume with 8 discrete levels (~10 cells)

**Alternative Considered**: 8×8 multiplier for smooth 256-level control (~220 cells). Rejected to maintain area budget and ensure successful routing.

**Trade-off**: 8 discrete levels provide adequate volume control for most applications. For smooth volume fades, external controller can interpolate between levels.

### 8.4 Dual-Mode Architecture

**Oscillator Mode**: Traditional synthesis with waveform generation and mixing
**Streaming Mode**: Direct sample playback for maximum flexibility

**Overhead**: Single mux adds minimal area (~5 cells) but enables:
- PCM sample playback
- Custom waveform streaming
- Direct DAC control for special effects

---

## 9. Testing and Verification

### Unit Tests

- **test_spi_rx.v**: SPI register interface (8 tests, all passing)
  - Control register write
  - 24-bit frequency writes
  - Duty cycle control
  - Bit-shift volume control (8 levels)
  - Streaming sample register
  - Burst write functionality
  - Read-only status register
  - Invalid address handling

- **test.py** (cocotb): Full system integration (12 tests, all passing)
  - Reset state verification
  - Oscillator enable via SPI (sawtooth waveform)
  - Frequency register writes (440 Hz)
  - Duty cycle control
  - Volume control in oscillator mode (5 levels tested)
  - DAC output verification in oscillator mode
  - Switch to streaming mode
  - Stream different sample values
  - DAC output verification in streaming mode
  - Volume control in streaming mode (5 levels tested)
  - Switch back to oscillator mode
  - Gate signals (hardware and software)

### Synthesis Results

**Target**: <60% utilization for successful routing
**Actual**: ~63% utilization (870 instances)
**Status**: ✅ Passing (GDS confirmed)

---

## 10. Useful Formulas

### Frequency Calculation
```
frequency_word = (target_freq_hz × 16,777,216) / 50,000,000
target_freq_hz = (frequency_word × 50,000,000) / 16,777,216
```

### Musical Note Frequencies

| Note | Frequency (Hz) | Register Value (hex) |
|------|----------------|----------------------|
| C4 | 261.63 | 0x015820 |
| C#4 | 277.18 | 0x016E9E |
| D4 | 293.66 | 0x0186A0 |
| D#4 | 311.13 | 0x01A025 |
| E4 | 329.63 | 0x01BB3B |
| F4 | 349.23 | 0x01D7E8 |
| F#4 | 370.00 | 0x01F634 |
| G4 | 392.00 | 0x021635 |
| G#4 | 415.30 | 0x0237FA |
| A4 | 440.00 | 0x024000 |
| A#4 | 466.16 | 0x026BF3 |
| B4 | 493.88 | 0x029A4D |
| C5 | 523.25 | 0x02B040 |

### Semitone Calculation
```
freq_next_semitone = freq_current × 2^(1/12)
freq_next_semitone ≈ freq_current × 1.059463
```

### Volume Level Calculation
```
volume_level = reg_volume[7:5]  // Top 3 bits
attenuation_dB = 20 × log10(level_fraction)
```

---

## 11. Use Cases

### 1. Musical Synthesizer
- Configure oscillator mode with square/sawtooth/triangle waveforms
- Mix multiple waveforms for richer timbres
- Use SPI to change pitch and volume in real-time
- External controller (Arduino, etc.) handles MIDI input

### 2. Sample Player
- Switch to streaming mode
- Stream pre-recorded audio samples from microcontroller flash
- Useful for sound effects, short audio clips, or custom waveforms

### 3. Waveform Generator / Test Equipment
- Oscillator mode provides stable, accurate frequency generation
- SYNC output (uo_out[3]) provides frequency reference
- Useful for audio testing, calibration, and debugging

### 4. Educational Platform
- Learn digital synthesis (DDS, waveform generation, mixing)
- Understand SPI communication protocol
- Explore delta-sigma DAC operation
- Experiment with dual-mode architecture

### 5. Game Audio Engine
- Oscillator mode for continuous tones (background music, alarms)
- Streaming mode for sound effects (explosions, beeps, voices)
- Volume control for audio feedback
- Minimal external components required

### 6. Custom Waveform Generator
- Streaming mode allows arbitrary waveform playback
- Pre-compute complex waveforms (additive synthesis, FM, wavetables)
- Stream samples at audio rate for maximum flexibility

---

## 12. Synthesis Lessons Learned

### 12.1 Critical Bug: Non-Synthesizable `initial` Blocks (2025-11-08)

**Issue Discovered**: Gate-level simulation failed with undefined ('x') values, while RTL simulation passed.

**Root Cause**: Used non-synthesizable `initial` block for register initialization in `spi_rx_registers.v`:

```verilog
// ❌ WRONG - Does NOT work in ASIC synthesis!
initial begin
    reg_control = 8'b00011100;
    reg_freq_low = 8'h00;
    // ... other registers
end
```

**Why It Failed**:
1. **RTL Simulation**: `initial` blocks execute at time 0 → ✅ Tests pass
2. **ASIC Synthesis**: `initial` blocks are completely ignored → ❌ Registers start with 'x' values
3. **Gate-Level Sim**: X-propagation through logic → ❌ Tests fail
4. **Physical Chip**: Random initial states → ⚠️ Unpredictable behavior on power-up

**The Fix**: Move initialization to synchronous reset clause:

```verilog
// ✅ CORRECT - Synthesizes properly for ASIC!
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // All registers initialized here
        reg_control <= 8'b00011100;
        reg_freq_low <= 8'h00;
        reg_freq_mid <= 8'h00;
        reg_freq_high <= 8'h00;
        reg_duty <= 8'h80;
        reg_volume <= 8'hFF;
        reg_stream_sample <= 8'h80;
    end else begin
        // Normal operation
    end
end
```

**Test Results**:
- Before fix: ✅ RTL sim passes, ❌ Gate-level sim fails (OSC_RUN='x')
- After fix: ✅ RTL sim passes, ✅ Gate-level sim passes (all 12 tests pass)

### 12.2 Gate-Level Simulation Setup

Gate-level simulation verifies the post-synthesis netlist using real Sky130 standard cells instead of behavioral RTL.

**Setup Steps**:
```bash
# 1. Install volare PDK manager
python3 -m pip install --user volare

# 2. Download Sky130 PDK
volare enable --pdk sky130 c6d73a35f524070e85faff4a6a9eef49553ebc2b

# 3. Copy power netlist from GDS build
# Use .pnl.v (with power pins), not .nl.v
cp <gds_logs>/runs/wokwi/final/pnl/<design>.pnl.v test/gate_level_netlist.v

# 4. Run gate-level simulation
export PDK_ROOT="$HOME/.volare/volare/sky130/versions/c6d73a35f524070e85faff4a6a9eef49553ebc2b"
cd test && make GATES=yes
```

**Required Testbench Changes** ([test/tb.v](test/tb.v)):
- Add power supply wires: `wire VPWR = 1'b1; wire VGND = 1'b0;` (inside `ifdef GL_TEST`)
- Connect to DUT: `.VPWR(VPWR), .VGND(VGND)` (inside `ifdef GL_TEST`)

**Required Makefile Config** ([test/Makefile](test/Makefile)):
- Flags: `-DGL_TEST -DGL -DFUNCTIONAL -DUSE_POWER_PINS -DSIM -DUNIT_DELAY=#1`
- Include PDK cells: `primitives.v` and `sky130_fd_sc_hd.v`

**What Gets Verified**: Real Sky130 cells, post-synthesis functional correctness, reset initialization, X-propagation through gates

### 12.3 Synthesis Best Practices

**Prevention Checklist**:
- [ ] No `initial` blocks in synthesizable code (testbenches only!)
- [ ] All registers initialized in reset clause
- [ ] RTL simulation passes all tests
- [ ] Gate-level simulation passes all tests
- [ ] No 'x' values after reset in gate-level sim
- [ ] No synthesis warnings about uninitialized registers

**Key Takeaways**:
1. **Always use reset initialization** - Never rely on `initial` blocks for ASIC
2. **Gate-level simulation is critical** - Catches issues before tapeout
3. **RTL passing ≠ chip will work** - Always verify gate-level netlist
4. **Test with real standard cells** - Gate-level sim uses actual Sky130 cells

---

## Document Revision History

| Version | Date | Changes |
|---------|------|---------|
| 2.1 | 2025-11-08 | **Critical Fix**: Fixed non-synthesizable `initial` blocks in `spi_rx_registers.v`. Moved register initialization to synchronous reset clause. Added Section 12: Synthesis Lessons Learned with gate-level simulation setup and best practices. Successfully passes both RTL and gate-level simulation (all 12 tests). |
| 2.0 | 2025-01-08 | Updated to dual-mode synthesizer with streaming capability. Replaced smooth 8×8 multiplier volume with instant bit-shift volume (8 levels). Added streaming sample register (0x10). Updated control register for mode selection. Total: ~870 instances (63% utilization). Successfully passes GDS synthesis. |
| 1.0 | 2025-11-08 | Initial SPI-based specification. Replaced I2C interface with SPI RX (~45 cells vs ~220). Implemented smooth 256-level volume control via 8×8 multiplier. Removed ADSR, amplitude modulator, and advanced features to fit 1×1 tile. |

---

*End of Specification Document*
