module cpu

import cpu.register { Register }
import peripherals { Peripherals }

struct Ctx {
mut:
	opcodes    [3]u32
	waitstates u8
}

pub struct Cpu {
mut:
	ctx  Ctx
	regs register.Register
}

pub fn Cpu.new() Cpu {
	return Cpu{}
}

pub fn (mut c Cpu) emulate_cycle(mut p Peripherals) {
	if c.ctx.waitstates > 0 {
		c.ctx.waitstates--
		return
	}
	c.decode()
}
