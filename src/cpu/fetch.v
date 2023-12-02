module cpu

import peripherals { Peripherals }
import cpu.interrupts

fn (mut c Cpu) fetch(bus &Peripherals) ? {
	has_int := c.interrupts.get_interrupts().has(interrupts.all_flags)
	if c.interrupts.halt && !has_int {
		return none
	}
	c.interrupts.halt = false
	is_thumb := c.regs.cpsr.get_flag(.t)
	size := u32(if is_thumb { 0xFFFF } else { 0xFFFF_FFFF })
	val := c.read(bus, c.regs.r15, size) or { return none } & size
	c.ctx.opcodes = [c.ctx.opcodes[1], c.ctx.opcodes[2], val]!
	in_int := has_int && !c.regs.cpsr.get_flag(.i) && c.interrupts.ime
	c.ctx.in_int = in_int
	c.ctx.is_thumb = is_thumb
}
