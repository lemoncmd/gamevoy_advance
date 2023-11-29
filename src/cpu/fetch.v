module cpu

import peripherals { Peripherals }

fn (mut c Cpu) fetch(bus &Peripherals) ? {
	size := u32(if c.regs.cpsr.get_flag(.t) { 0xFFFF } else { 0xFFFF_FFFF })
	val := c.read(bus, c.regs.r15, size) or { return none } & size
	c.ctx.opcodes = [c.ctx.opcodes[1], c.ctx.opcodes[2], val]!
}
