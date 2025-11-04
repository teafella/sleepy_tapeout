"""
Cocotb test for user_module
"""
import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.binary import BinaryValue


@cocotb.test()
async def test_user_module(dut):
    """Test the user_module design"""
    
    # Start clock
    clock = Clock(dut.clk, 20, units="ns")  # 50MHz clock (20ns period)
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    
    await Timer(30, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: A=0, B=0 -> OUT should be 0
    dut.ui_in.value = 0b00000000
    await RisingEdge(dut.clk)
    await Timer(10, units="ns")
    assert dut.uo_out[0].value == 0, f"Test 1 failed: Expected 0, got {dut.uo_out[0].value}"
    
    # Test case 2: A=0, B=1 -> OUT should be 0
    dut.ui_in.value = 0b00000010  # ui[1] = 1
    await RisingEdge(dut.clk)
    await Timer(10, units="ns")
    assert dut.uo_out[0].value == 0, f"Test 2 failed: Expected 0, got {dut.uo_out[0].value}"
    
    # Test case 3: A=1, B=0 -> OUT should be 0
    dut.ui_in.value = 0b00000001  # ui[0] = 1
    await RisingEdge(dut.clk)
    await Timer(10, units="ns")
    assert dut.uo_out[0].value == 0, f"Test 3 failed: Expected 0, got {dut.uo_out[0].value}"
    
    # Test case 4: A=1, B=1 -> OUT should be 1
    dut.ui_in.value = 0b00000011  # ui[0] = 1, ui[1] = 1
    await RisingEdge(dut.clk)
    await Timer(10, units="ns")
    assert dut.uo_out[0].value == 1, f"Test 4 failed: Expected 1, got {dut.uo_out[0].value}"
    
    dut._log.info("All tests passed!")

