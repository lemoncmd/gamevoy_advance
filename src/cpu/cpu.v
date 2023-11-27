module cpu

import cpu.register { Register }
import peripherals { Peripherals }

struct Ctx {
mut:
	opcodes    [3]u32
	waitstates u8
	bus_value  u32
}

pub struct Cpu {
mut:
	ctx  Ctx
	regs register.Register
}

pub fn Cpu.new() Cpu {
	return Cpu{}
}

pub fn (mut c Cpu) emulate_cycle(mut bus Peripherals) {
	c.decode()
}
