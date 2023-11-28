module cpu

import peripherals { Peripherals }

fn (mut c Cpu) fetch(bus &Peripherals) ? {
	size := u32(if c.regs.cpsr.get_flag(.t) { 2 } else { 4 })
	val := c.read(bus, c.regs.r15, (1 << (size * 8)) - 1) or { return none }
	c.ctx.opcodes = [c.ctx.opcodes[1], c.ctx.opcodes[2], val]!
}
