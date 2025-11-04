"""
Cocotb test for circular shift register drum trigger
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer
from cocotb.binary import BinaryValue


@cocotb.test()
async def test_circular_shift_register(dut):
    """Test the circular shift register with drum trigger output"""
    
    # Start clock - 50MHz (20ns period)
    clock = Clock(dut.clk, 20, units="ns")
    cocotb.start_soon(clock.start())
    
    # Initialize inputs
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 1
    
    # Hold reset for a bit
    await Timer(30, units="ns")
    dut.rst_n.value = 1
    
    dut._log.info("Test 1: Verify initial state after reset")
    # After reset (before any clock), shift_reg should be 0, output should be 0
    await Timer(1, units="ns")
    assert dut.uo_out[7].value == 0, f"After reset, expected output 0, got {dut.uo_out[7].value}"
    dut._log.info("✓ Reset state correct")
    
    dut._log.info("Test 2: First clock - shift in first '1'")
    # First rising edge shifts in a 1 at position 0
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    # shift_reg should be 0b00000001, and since clk is high, output should be high
    assert dut.uo_out[7].value == 1, f"After first clock (clk high), expected output 1, got {dut.uo_out[7].value}"
    
    # On falling edge, output should go low (even though shift_reg[0]=1)
    await FallingEdge(dut.clk)
    await Timer(1, units="ns")
    assert dut.uo_out[7].value == 0, f"After first clock (clk low), expected output 0, got {dut.uo_out[7].value}"
    dut._log.info("✓ First drum trigger pulse correct")
    
    dut._log.info("Test 3: Second clock - shift continues")
    # Second rising edge: shift_reg goes from 0b00000001 to 0b00000011
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    # shift_reg[0] should still be 1, output should pulse
    assert dut.uo_out[7].value == 1, f"After second clock, expected output 1, got {dut.uo_out[7].value}"
    dut._log.info("✓ Second drum trigger pulse correct")
    
    dut._log.info("Test 4: Continue shifting - fill the register")
    # Continue clocking to fill up the shift register
    for i in range(6):
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
        # Every clock cycle, bit 0 should be 1, so output pulses
        assert dut.uo_out[7].value == 1, f"Clock {i+3}, expected output 1, got {dut.uo_out[7].value}"
    
    dut._log.info("✓ All 8 positions filled with 1s")
    
    dut._log.info("Test 5: Verify circular behavior continues")
    # Now the register is full (0b11111111), it should keep pulsing
    for i in range(3):
        await FallingEdge(dut.clk)
        await Timer(1, units="ns")
        assert dut.uo_out[7].value == 0, f"Cycle {i}, clk low: expected output 0, got {dut.uo_out[7].value}"
        
        await RisingEdge(dut.clk)
        await Timer(1, units="ns")
        assert dut.uo_out[7].value == 1, f"Cycle {i}, clk high: expected output 1, got {dut.uo_out[7].value}"
    
    dut._log.info("✓ Circular shift register maintains pattern")
    
    dut._log.info("Test 6: Verify other outputs are 0")
    assert dut.uo_out.value & 0x7F == 0, f"Expected uo_out[6:0] to be 0, got {dut.uo_out.value & 0x7F}"
    dut._log.info("✓ Unused outputs correctly set to 0")
    
    dut._log.info("Test 7: Verify reset works again")
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    # During reset, output should be 0 even if clock is high
    assert dut.uo_out[7].value == 0, f"During reset, expected output 0, got {dut.uo_out[7].value}"
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    await Timer(1, units="ns")
    # First clock after reset should shift in a 1 and pulse
    assert dut.uo_out[7].value == 1, f"After reset and first clock, expected output 1, got {dut.uo_out[7].value}"
    dut._log.info("✓ Reset functionality verified")
    
    dut._log.info("=" * 50)
    dut._log.info("ALL TESTS PASSED! 🎉")
    dut._log.info("=" * 50)

