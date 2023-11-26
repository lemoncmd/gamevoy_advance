module cpu

import cpu.register { Register }

struct Ctx {
mut:
	opcodes [3]u32
}

pub struct Cpu {
mut:
	ctx Ctx
	reg register.Register
}
