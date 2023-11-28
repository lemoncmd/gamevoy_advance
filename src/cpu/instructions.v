module cpu

import peripherals { Peripherals }

fn (c &Cpu) cond(cond u8) bool {
	cpsr := c.regs.cpsr
	return match cond {
		0x0 { cpsr.get_flag(.z) }
		0x1 { !cpsr.get_flag(.z) }
		0x2 { cpsr.get_flag(.c) }
		0x3 { !cpsr.get_flag(.c) }
		0x4 { cpsr.get_flag(.n) }
		0x5 { !cpsr.get_flag(.n) }
		0x6 { cpsr.get_flag(.v) }
		0x7 { !cpsr.get_flag(.v) }
		0x8 { cpsr.get_flag(.c) && !cpsr.get_flag(.z) }
		0x9 { !cpsr.get_flag(.c) || cpsr.get_flag(.z) }
		0xA { cpsr.get_flag(.n) == cpsr.get_flag(.v) }
		0xB { cpsr.get_flag(.n) != cpsr.get_flag(.v) }
		0xC { !cpsr.get_flag(.z) && cpsr.get_flag(.n) == cpsr.get_flag(.v) }
		0xD { cpsr.get_flag(.z) || cpsr.get_flag(.n) != cpsr.get_flag(.v) }
		0xE { true }
		else { false }
	}
}

fn (mut c Cpu) mov(bus &Peripherals, cond u8, s bool, dest u8, op2 u32, is_rs bool, carry ?bool) {
	if !c.cond(cond) {
		c.fetch(bus)
		return
	}
	for {
		match c.ctx.step {
			0 {
				c.regs.write(dest, op2)
				if s {
					if dest == 0xF {
						c.regs.cpsr = c.regs.get_spsr()
					} else {
						if ca := carry {
							c.regs.cpsr.set_flag(.c, ca)
						}
						c.regs.cpsr.set_flag(.z, op2 == 0)
						c.regs.cpsr.set_flag(.n, op2 >> 31 > 0)
					}
				}
				c.ctx.step = if dest == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				val := c.read(bus, c.regs.r15, 0xFFFF_FFFF) or { return }
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				val := c.read(bus, c.regs.r15 + 4, 0xFFFF_FFFF) or { return }
				c.ctx.opcodes[2] = val
				c.regs.r15 += 8
				c.ctx.step = 3
				return
			}
			3 {
				c.fetch(bus) or { return }
				c.ctx.step = 0
				return
			}
			else {
				return
			}
		}
	}
}

fn (mut c Cpu) b(bus &Peripherals, cond u8, offset u32) {
	if !c.cond(cond) {
		c.fetch(bus)
		return
	}
	base_pc := c.regs.r15 + offset
	match c.ctx.step {
		0 {
			val := c.read(bus, base_pc, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			c.ctx.step = 1
		}
		1 {
			val := c.read(bus, base_pc + 4, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[2] = val
			c.regs.r15 = base_pc + 8
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) bl(bus &Peripherals, cond u8, offset u32) {
	if !c.cond(cond) {
		c.fetch(bus)
		return
	}
	base_pc := c.regs.r15 + offset
	match c.ctx.step {
		0 {
			val := c.read(bus, base_pc, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			c.ctx.step = 1
		}
		1 {
			val := c.read(bus, base_pc + 4, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[2] = val
			c.regs.write(14, c.regs.r15 - 4)
			c.regs.r15 = base_pc + 8
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}
