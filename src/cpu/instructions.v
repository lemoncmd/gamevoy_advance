module cpu

import peripherals { Peripherals }

fn (mut c Cpu) check_cond(bus &Peripherals, cond u8) ? {
	if !c.cond(cond) {
		match c.ctx.step {
			0 {
				c.regs.r15 += 4
				c.ctx.step = 1
			}
			1 {
				c.fetch(bus)
				c.ctx.step = 0
			}
			else {}
		}
		return none
	}
}

fn (mut c Cpu) msr_cpsr(bus &Peripherals, cond u8, write_f bool, write_c bool, rd u8, val u32) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				mut mask := u32(0)
				if write_f {
					mask |= 0xF000
				}
				if write_c && c.regs.cpsr.is_priviledge() {
					mask |= 0x000F
				}
				new_cpsr := (u32(c.regs.cpsr) & ~mask) | (val & mask)
				if rd != 0xF {
					c.regs.write(rd, new_cpsr)
				}
				c.regs.cpsr = new_cpsr
				c.regs.r15 += 4
				c.ctx.step = 1
			}
			1 {
				c.fetch(bus)
				c.ctx.step = 0
				return
			}
			else {}
		}
	}
}

fn (mut c Cpu) mov(bus &Peripherals, cond u8, s bool, dest u8, op2 u32, is_rs bool, carry ?bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				c.regs.r15 += 4
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

fn (mut c Cpu) str_(mut bus Peripherals, cond u8, is_pre bool, is_plus bool, is_8bit bool, flag bool, rn u8, rd u8, offset u32) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				c.ctx.addr = if is_plus {
					c.regs.read(rn) + offset
				} else {
					c.regs.read(rn) - offset
				}
				if is_pre && flag {
					c.regs.write(rn, c.ctx.addr)
				}
				c.regs.r15 += 4
				c.ctx.val = c.regs.read(rd)
				c.ctx.step = 1
			}
			1 {
				c.write(mut bus, c.ctx.addr, c.ctx.val, if is_8bit { u32(0xFF) } else { 0xFFFF_FFFF }) or {
					return
				}
				if !is_pre {
					c.regs.write(rn, c.ctx.addr)
				}
				c.ctx.step = 2
				return
			}
			2 {
				c.fetch(bus) or { return }
				c.ctx.step = 0
				return
			}
			else {}
		}
	}
}

fn (mut c Cpu) b(bus &Peripherals, cond u8, offset u32) {
	c.check_cond(bus, cond) or { return }
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
	c.check_cond(bus, cond) or { return }
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
