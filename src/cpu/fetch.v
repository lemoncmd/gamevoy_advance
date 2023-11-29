module cpu

import peripherals { Peripherals }
import cpu.interrupts

fn (mut c Cpu) fetch(bus &Peripherals) ? {
	size := u32(if c.regs.cpsr.get_flag(.t) { 0xFFFF } else { 0xFFFF_FFFF })
	val := c.read(bus, c.regs.r15, size) or { return none } & size
	c.ctx.opcodes = [c.ctx.opcodes[1], c.ctx.opcodes[2], val]!
	if !c.regs.cpsr.get_flag(.i) && c.interrupts.ime
		&& c.interrupts.get_interrupts().has(interrupts.all_flags) {
		c.ctx.in_int = true
	}
}
