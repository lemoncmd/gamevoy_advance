module cpu

import cpu.register { Register }
import cpu.interrupts { Interrupts }
import peripherals.dma { DmaInfo }
import peripherals { Peripherals }

struct Ctx {
mut:
	opcodes    [3]u32
	waitstates u8
	bus_value  u32
	step       int
	dma_step   int
	addr       u32
	val        u32
	dma_val    u32
	in_int     bool
	is_thumb   bool
}

pub struct Cpu {
mut:
	ctx  Ctx
	regs register.Register
pub mut:
	interrupts interrupts.Interrupts
	dma_info   ?DmaInfo
}

pub fn Cpu.new() Cpu {
	return Cpu{}
}

pub fn (mut c Cpu) init(bus &Peripherals) {
	c.ctx.opcodes = [bus.read(0, c.interrupts), bus.read(4, c.interrupts),
		bus.read(8, c.interrupts)]!
	c.regs.r15 = 8
}

pub fn (mut c Cpu) emulate_cycle(mut bus Peripherals) {
	/*if c.ctx.step == 0 {
		println('${if c.regs.cpsr.get_flag(.t) { 't' } else { 'a' }}pc:${c.regs.r15:08x} ${c.ctx.opcodes[0]:08x} ${c.regs.read(3):08x}')
	}*/
	// if c.ctx.step == 0 { print('\r${c.interrupts.int_enable}') }
	flush_stdout()
	// println('${c.ctx.opcodes[0]:08x}, ${c.ctx.opcodes[1]:08x}, ${c.ctx.opcodes[2]:08x}')
	/*
	if c.regs.r15 == 0x2840 {
		println('${c.regs.read(0):08x} ${c.regs.read(1):08x} ${c.regs.read(2):08x} ${c.regs.read(3):08x}')
	}*/
	if dma_info := c.dma_info {
		c.dma_transfer(mut bus, dma_info)
	} else if c.ctx.in_int {
		c.int(bus)
	} else {
		c.decode(mut bus)
	}
}
