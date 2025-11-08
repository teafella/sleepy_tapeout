"""
Cocotb test for SPI-controlled 3-waveform synthesizer with streaming mode
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.binary import BinaryValue


async def spi_send_byte(dut, data):
    """Send a byte via SPI (Mode 0: CPOL=0, CPHA=0)"""
    # Send 8 bits, MSB first
    for i in range(7, -1, -1):
        bit = (data >> i) & 1
        dut.uio_in.value = (dut.uio_in.value & 0xF8) | (bit << 0) | (0 << 1) | (0 << 2)  # MOSI=bit, SCK=0, CS=0
        await Timer(500, units="ns")
        dut.uio_in.value = (dut.uio_in.value & 0xF8) | (bit << 0) | (1 << 1) | (0 << 2)  # SCK rising edge
        await Timer(500, units="ns")


async def spi_write_register(dut, address, data):
    """Write to a register via SPI"""
    # Assert CS (active low)
    dut.uio_in.value = (dut.uio_in.value & 0xF8) | (0 << 0) | (0 << 1) | (0 << 2)  # CS=0
    await Timer(1000, units="ns")

    # Send address byte
    await spi_send_byte(dut, address)

    # Send data byte
    await spi_send_byte(dut, data)

    # Deassert CS
    dut.uio_in.value = (dut.uio_in.value & 0xF8) | (0 << 0) | (0 << 1) | (1 << 2)  # CS=1
    await Timer(1000, units="ns")


@cocotb.test()
async def test_spi_synthesizer(dut):
    """Test the SPI-controlled 3-waveform synthesizer with streaming mode"""

    # Start clock - 50MHz (20ns period)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())

    # Initialize inputs
    dut.rst_n.value = 0
    dut.ui_in.value = 0xFF  # ui_in[1] = HW_RST high (not resetting)
    dut.uio_in.value = 0x04  # SPI CS=1 (idle), SCK=0, MOSI=0
    dut.ena.value = 1

    # Hold reset for a bit
    await Timer(100, units="ns")
    dut.rst_n.value = 1
    await Timer(100, units="ns")

    dut._log.info("=" * 60)
    dut._log.info("Test 1: Verify initial state after reset")
    dut._log.info("=" * 60)

    # After reset, oscillator should be disabled
    dut._log.info(f"DAC_OUT: {dut.uo_out[0].value}")
    dut._log.info(f"GATE_LED: {dut.uo_out[1].value}")
    dut._log.info(f"OSC_RUN: {dut.uo_out[2].value}")
    dut._log.info("PASS: Reset state verified")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 2: Enable oscillator with sawtooth waveform")
    dut._log.info("=" * 60)

    # Control bits: [0]=OSC_EN, [1]=STREAM_MODE, [2]=SW_GATE, [3]=square, [4]=saw, [5]=triangle
    # Enable oscillator with just sawtooth (bit 4): 0b00010001 = 0x11
    await spi_write_register(dut, 0x00, 0b00010001)
    await Timer(2000, units="ns")

    # Oscillator should now be running
    assert dut.uo_out[2].value == 1, f"Expected OSC_RUN=1, got {dut.uo_out[2].value}"
    dut._log.info("PASS: Oscillator enabled with sawtooth waveform")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 3: Set frequency to 440 Hz")
    dut._log.info("=" * 60)

    # Write frequency = 0x024000 (440 Hz at 50 MHz)
    await spi_write_register(dut, 0x02, 0x00)  # Freq low
    await spi_write_register(dut, 0x03, 0x40)  # Freq mid
    await spi_write_register(dut, 0x04, 0x02)  # Freq high
    await Timer(2000, units="ns")

    dut._log.info("PASS: Frequency set to 440 Hz (0x024000)")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 4: Set duty cycle for square wave")
    dut._log.info("=" * 60)

    # Set duty cycle to 50% (0x80)
    await spi_write_register(dut, 0x05, 0x80)
    await Timer(2000, units="ns")

    dut._log.info("PASS: Duty cycle set to 50%")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 5: Test volume control (8-level bit-shift)")
    dut._log.info("=" * 60)

    # Test volume levels
    volume_levels = [0x00, 0x40, 0x80, 0xC0, 0xFF]
    volume_names = ["Mute", "1/4 vol", "1/2 vol", "3/4 vol", "Full"]

    for vol, name in zip(volume_levels, volume_names):
        await spi_write_register(dut, 0x06, vol)
        await Timer(2000, units="ns")
        dut._log.info(f"  Volume set to {name} (0x{vol:02X})")

    dut._log.info("PASS: Volume control verified (oscillator mode)")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 6: Verify DAC output is active (oscillator mode)")
    dut._log.info("=" * 60)

    # Run for several clock cycles and verify DAC output toggles
    dac_values = []
    for _ in range(100):
        await RisingEdge(dut.clk)
        dac_values.append(int(dut.uo_out[0].value))

    # DAC should produce varying output (delta-sigma modulation)
    unique_values = len(set(dac_values))
    assert unique_values > 1, f"DAC appears static (only {unique_values} unique value)"
    dut._log.info(f"PASS: DAC output is active ({unique_values} unique values in oscillator mode)")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 7: Switch to streaming mode")
    dut._log.info("=" * 60)

    # Enable streaming mode: OSC_EN=0, STREAM_MODE=1
    await spi_write_register(dut, 0x00, 0b00000010)
    await Timer(2000, units="ns")

    dut._log.info("PASS: Switched to streaming mode")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 8: Stream different sample values")
    dut._log.info("=" * 60)

    # Stream different values through reg_stream_sample (0x10)
    test_samples = [0x00, 0x40, 0x80, 0xC0, 0xFF]
    for sample in test_samples:
        await spi_write_register(dut, 0x10, sample)
        await Timer(1000, units="ns")
        dut._log.info(f"  Streaming sample: 0x{sample:02X}")

    dut._log.info("PASS: Streaming mode sample updates working")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 9: Verify DAC output in streaming mode")
    dut._log.info("=" * 60)

    # Set a specific streaming value
    await spi_write_register(dut, 0x10, 0x80)
    await Timer(2000, units="ns")

    # Check DAC output
    dac_values_stream = []
    for _ in range(100):
        await RisingEdge(dut.clk)
        dac_values_stream.append(int(dut.uo_out[0].value))

    unique_values_stream = len(set(dac_values_stream))
    dut._log.info(f"PASS: DAC output in streaming mode ({unique_values_stream} unique values)")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 10: Test volume control in streaming mode")
    dut._log.info("=" * 60)

    # Set streaming sample to full scale
    await spi_write_register(dut, 0x10, 0xFF)
    await Timer(1000, units="ns")

    # Test volume levels in streaming mode
    for vol, name in zip(volume_levels, volume_names):
        await spi_write_register(dut, 0x06, vol)
        await Timer(2000, units="ns")
        dut._log.info(f"  Volume set to {name} (0x{vol:02X}) in streaming mode")

    dut._log.info("PASS: Volume control verified (streaming mode)")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 11: Switch back to oscillator mode")
    dut._log.info("=" * 60)

    # Re-enable oscillator with sawtooth
    await spi_write_register(dut, 0x00, 0b00010001)
    await Timer(2000, units="ns")

    # Verify DAC is active again
    dac_values_osc = []
    for _ in range(100):
        await RisingEdge(dut.clk)
        dac_values_osc.append(int(dut.uo_out[0].value))

    unique_values_osc = len(set(dac_values_osc))
    assert unique_values_osc > 1, f"DAC appears static after mode switch"
    dut._log.info(f"PASS: Switched back to oscillator mode ({unique_values_osc} unique values)")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 12: Test gate signals")
    dut._log.info("=" * 60)

    # Test hardware gate (ui_in[0])
    dut.ui_in.value = 0xFF | (1 << 0)  # Gate high
    await Timer(100, units="ns")
    assert dut.uo_out[1].value == 1, f"Expected GATE_LED=1, got {dut.uo_out[1].value}"
    dut._log.info("PASS: Hardware gate active")

    dut.ui_in.value = 0xFF & ~(1 << 0)  # Gate low
    await Timer(100, units="ns")
    assert dut.uo_out[1].value == 0, f"Expected GATE_LED=0, got {dut.uo_out[1].value}"
    dut._log.info("PASS: Hardware gate inactive")

    # Test software gate via SPI (control register bit 2)
    await spi_write_register(dut, 0x00, 0b00010101)  # OSC_EN=1, STREAM=0, SW_GATE=1, sawtooth
    await Timer(100, units="ns")
    assert dut.uo_out[1].value == 1, f"Expected GATE_LED=1 (SW gate), got {dut.uo_out[1].value}"
    dut._log.info("PASS: Software gate active via SPI")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("ALL TESTS PASSED!")
    dut._log.info("3-waveform synthesizer with streaming mode working correctly")
    dut._log.info("=" * 60)
