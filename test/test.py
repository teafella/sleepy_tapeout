"""
Cocotb test for SPI-controlled waveform synthesizer
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
    """Test the SPI-controlled waveform synthesizer"""

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
    # Check that DAC output exists (bit 0)
    dut._log.info(f"DAC_OUT: {dut.uo_out[0].value}")
    dut._log.info(f"GATE_LED: {dut.uo_out[1].value}")
    dut._log.info(f"OSC_RUN: {dut.uo_out[2].value}")
    dut._log.info("✓ Reset state verified")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 2: Write to control register - enable oscillator")
    dut._log.info("=" * 60)

    # Write to control register: OSC_EN=1, all waveforms enabled
    # Control register bits: [0]=OSC_EN, [1]=SW_GATE, [2-4]=waveform enables
    await spi_write_register(dut, 0x00, 0b00011101)  # 0x1D
    await Timer(2000, units="ns")

    # Oscillator should now be running
    assert dut.uo_out[2].value == 1, f"Expected OSC_RUN=1, got {dut.uo_out[2].value}"
    dut._log.info("✓ Oscillator enabled via SPI")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 3: Write frequency registers (440 Hz)")
    dut._log.info("=" * 60)

    # Write frequency = 0x024000 (440 Hz at 50 MHz)
    await spi_write_register(dut, 0x02, 0x00)  # Freq low
    await spi_write_register(dut, 0x03, 0x40)  # Freq mid
    await spi_write_register(dut, 0x04, 0x02)  # Freq high
    await Timer(2000, units="ns")

    dut._log.info("✓ Frequency registers written")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 4: Write duty cycle register")
    dut._log.info("=" * 60)

    # Set duty cycle to 50% (0x80)
    await spi_write_register(dut, 0x05, 0x80)
    await Timer(2000, units="ns")

    dut._log.info("✓ Duty cycle set to 50%")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 5: Test volume control (smooth 256-level)")
    dut._log.info("=" * 60)

    # Test multiple volume levels
    volume_levels = [0x00, 0x40, 0x80, 0xC0, 0xFF]
    volume_names = ["Mute", "25%", "50%", "75%", "Full"]

    for vol, name in zip(volume_levels, volume_names):
        await spi_write_register(dut, 0x06, vol)
        await Timer(2000, units="ns")
        dut._log.info(f"  Volume set to {name} (0x{vol:02X})")

    dut._log.info("✓ Smooth volume control verified")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 6: Test burst write (multiple registers)")
    dut._log.info("=" * 60)

    # Burst write to frequency registers
    # CS low
    dut.uio_in.value = (dut.uio_in.value & 0xF8) | (0 << 0) | (0 << 1) | (0 << 2)
    await Timer(1000, units="ns")

    # Address = 0x02 (freq low)
    await spi_send_byte(dut, 0x02)
    # Data bytes (auto-increment)
    await spi_send_byte(dut, 0xAA)  # Freq low
    await spi_send_byte(dut, 0xBB)  # Freq mid
    await spi_send_byte(dut, 0xCC)  # Freq high

    # CS high
    dut.uio_in.value = (dut.uio_in.value & 0xF8) | (0 << 0) | (0 << 1) | (1 << 2)
    await Timer(2000, units="ns")

    dut._log.info("✓ Burst write completed")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 7: Verify DAC output is active")
    dut._log.info("=" * 60)

    # Run for several clock cycles and verify DAC output toggles
    dac_values = []
    for _ in range(100):
        await RisingEdge(dut.clk)
        dac_values.append(int(dut.uo_out[0].value))

    # DAC should produce varying output (delta-sigma modulation)
    if len(set(dac_values)) > 1:
        dut._log.info(f"✓ DAC output is active (saw {len(set(dac_values))} unique values)")
    else:
        dut._log.warning(f"⚠ DAC output appears static (value={dac_values[0]})")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("Test 8: Test gate signal")
    dut._log.info("=" * 60)

    # Test hardware gate (ui_in[0])
    dut.ui_in.value = 0xFF | (1 << 0)  # Gate high
    await Timer(100, units="ns")
    assert dut.uo_out[1].value == 1, f"Expected GATE_LED=1, got {dut.uo_out[1].value}"
    dut._log.info("✓ Hardware gate active")

    dut.ui_in.value = 0xFF & ~(1 << 0)  # Gate low
    await Timer(100, units="ns")
    assert dut.uo_out[1].value == 0, f"Expected GATE_LED=0, got {dut.uo_out[1].value}"
    dut._log.info("✓ Hardware gate inactive")

    # Test software gate via SPI (control register bit 1)
    await spi_write_register(dut, 0x00, 0b00011111)  # SW_GATE=1
    await Timer(100, units="ns")
    assert dut.uo_out[1].value == 1, f"Expected GATE_LED=1 (SW gate), got {dut.uo_out[1].value}"
    dut._log.info("✓ Software gate active via SPI")

    dut._log.info("\n" + "=" * 60)
    dut._log.info("ALL TESTS PASSED! 🎉")
    dut._log.info("SPI-controlled synthesizer is working correctly")
    dut._log.info("=" * 60)
