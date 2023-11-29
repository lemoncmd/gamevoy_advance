module cpu

import cpu.register { Register }
import cpu.interrupts { Interrupts }
import peripherals { Peripherals }

struct Ctx {
mut:
	opcodes    [3]u32
	waitstates u8
	bus_value  u32
	step       int
	addr       u32
	val        u32
	in_int     bool
}

pub struct Cpu {
mut:
	ctx  Ctx
	regs register.Register
pub mut:
	interrupts interrupts.Interrupts
}

pub fn Cpu.new() Cpu {
	return Cpu{}
}

pub fn (mut c Cpu) init(bus &Peripherals) {
	c.ctx.opcodes = [bus.read(0), bus.read(4), bus.read(8)]!
	c.regs.r15 = 8
}

pub fn (mut c Cpu) emulate_cycle(mut bus Peripherals) {
	// println('${c.regs.r15:08x} ${c.regs.read(0):08x}')
	// println('${c.ctx.opcodes[0]:08x}, ${c.ctx.opcodes[1]:08x}, ${c.ctx.opcodes[2]:08x}')
	if c.ctx.in_int {
		c.int(bus)
	} else {
		c.decode(mut bus)
	}
}
