module cpu

import cpu.register { Register }

struct Ctx {
mut:
	opcodes    [3]u32
	waitstates u8
}

pub struct Cpu {
mut:
	ctx Ctx
	reg register.Register
}

pub fn Cpu.new() Cpu {
	return Cpu{}
}

pub fn (mut c Cpu) emulate_cycle() {
	if c.ctx.waitstates > 0 {
		c.ctx.waitstates--
		return
	}
}
