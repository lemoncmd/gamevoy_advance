module cpu

import math.bits
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

fn (mut c Cpu) mrs_cpsr(bus &Peripherals, cond u8, rd u8) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				c.regs.write(rd, c.regs.cpsr)
				c.regs.r15 += 4
				c.ctx.step = 1
			}
			1 {
				c.fetch(bus) or { return }
				c.ctx.step = 0
				return
			}
			else {}
		}
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

fn (mut c Cpu) mrs_spsr(bus &Peripherals, cond u8, rd u8) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				c.regs.write(rd, c.regs.read_spsr())
				c.regs.r15 += 4
				c.ctx.step = 1
			}
			1 {
				c.fetch(bus) or { return }
				c.ctx.step = 0
				return
			}
			else {}
		}
	}
}

fn (mut c Cpu) msr_spsr(bus &Peripherals, cond u8, write_f bool, write_c bool, rd u8, val u32) {
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
				new_spsr := (u32(c.regs.read_spsr()) & ~mask) | (val & mask)
				if rd != 0xF {
					c.regs.write(rd, new_spsr)
				}
				c.regs.write_spsr(new_spsr)
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

fn (mut c Cpu) mla(bus &Peripherals, cond u8, s bool, rd u8, rn u8, rs u8, rm u8) {
	c.check_cond(bus, cond) or { return }
	match c.ctx.step {
		0 {
			rm_val := c.regs.read(rm)
			rs_val := c.regs.read(rs)
			rn_val := c.regs.read(rn)
			val := rm_val * rs_val + rn_val
			if s {
				c.regs.write(rd, val)
				c.regs.cpsr.set_flag(.c, false)
				c.regs.cpsr.set_flag(.z, val == 0)
				c.regs.cpsr.set_flag(.n, val >> 31 > 0)
			}
			c.ctx.val = match rs_val >> 8 {
				0xFFFFFF { 1 }
				0xFFFF00...0xFFFFFE { 2 }
				0xFF0000...0xFFFEFF { 3 }
				else { 4 }
			}
			c.regs.r15 += 4
			c.ctx.step = 1
		}
		1 {
			c.ctx.val--
			if c.ctx.val == 0 {
				c.ctx.step = 2
			}
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) bx(bus &Peripherals, cond u8, rn u8) {
	c.check_cond(bus, cond) or { return }
	rn_val := c.regs.read(rn)
	base_pc := rn_val & 0xFFFF_FFFE
	is_thumb := rn_val & 1 > 0
	size := u32(if is_thumb { 0xFFFF } else { 0xFFFF_FFFF })
	match c.ctx.step {
		0 {
			val := c.read(bus, base_pc, size) or { return }
			c.ctx.opcodes[1] = val & size
			c.ctx.step = 1
		}
		1 {
			val := c.read(bus, base_pc + u32(if is_thumb { 2 } else { 4 }), size) or { return }
			c.ctx.opcodes[2] = val & size
			c.regs.r15 = base_pc + u32(if is_thumb { 4 } else { 8 })
			c.regs.cpsr.set_flag(.t, is_thumb)
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) and(bus &Peripherals, cond u8, s bool, rn u8, rd u8, op2 u32, is_rs bool, carry ?bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				result := c.regs.read(rn) & op2
				c.regs.r15 += 4
				c.regs.write(rd, result)
				if s {
					if rd == 0xF {
						c.regs.cpsr = c.regs.read_spsr()
					} else {
						if ca := carry {
							c.regs.cpsr.set_flag(.c, ca)
						}
						c.regs.cpsr.set_flag(.z, result == 0)
						c.regs.cpsr.set_flag(.n, result >> 31 > 0)
					}
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				step := if c.regs.cpsr.get_flag(.t) { u32(2) } else { 4 }
				val := c.read(bus, c.regs.r15 + step, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += step * 2
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

fn (mut c Cpu) eor(bus &Peripherals, cond u8, s bool, rn u8, rd u8, op2 u32, is_rs bool, carry ?bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				result := c.regs.read(rn) | op2
				c.regs.r15 += 4
				c.regs.write(rd, result)
				if s {
					if rd == 0xF {
						c.regs.cpsr = c.regs.read_spsr()
					} else {
						if ca := carry {
							c.regs.cpsr.set_flag(.c, ca)
						}
						c.regs.cpsr.set_flag(.z, result == 0)
						c.regs.cpsr.set_flag(.n, result >> 31 > 0)
					}
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				step := if c.regs.cpsr.get_flag(.t) { u32(2) } else { 4 }
				val := c.read(bus, c.regs.r15 + step, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += step * 2
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

fn (mut c Cpu) sub(bus &Peripherals, cond u8, s bool, rn u8, rd u8, op2 u32, is_rs bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				rn_val := c.regs.read(rn)
				result, carry := bits.sub_32(rn_val, op2, 0)
				c.regs.r15 += 4
				c.regs.write(rd, result)
				if s {
					if rd == 0xF {
						c.regs.cpsr = c.regs.read_spsr()
					} else {
						c.regs.cpsr.set_flag(.v, ((rn_val ^ op2) & (rn_val ^ result)) >> 31 > 0)
						c.regs.cpsr.set_flag(.c, carry > 0)
						c.regs.cpsr.set_flag(.z, result == 0)
						c.regs.cpsr.set_flag(.n, result >> 31 > 0)
					}
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				step := if c.regs.cpsr.get_flag(.t) { u32(2) } else { 4 }
				val := c.read(bus, c.regs.r15 + step, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += step * 2
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

fn (mut c Cpu) rsb(bus &Peripherals, cond u8, s bool, rn u8, rd u8, op2 u32, is_rs bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				rn_val := c.regs.read(rn)
				result, carry := bits.sub_32(op2, rn_val, 0)
				c.regs.r15 += 4
				c.regs.write(rd, result)
				if s {
					if rd == 0xF {
						c.regs.cpsr = c.regs.read_spsr()
					} else {
						c.regs.cpsr.set_flag(.v, ((rn_val ^ op2) & (op2 ^ result)) >> 31 > 0)
						c.regs.cpsr.set_flag(.c, carry > 0)
						c.regs.cpsr.set_flag(.z, result == 0)
						c.regs.cpsr.set_flag(.n, result >> 31 > 0)
					}
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				step := if c.regs.cpsr.get_flag(.t) { u32(2) } else { 4 }
				val := c.read(bus, c.regs.r15 + step, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += step * 2
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

fn (mut c Cpu) add(bus &Peripherals, cond u8, s bool, rn u8, rd u8, op2 u32, is_rs bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				rn_val := c.regs.read(rn)
				result, carry := bits.add_32(rn_val, op2, 0)
				c.regs.r15 += 4
				c.regs.write(rd, result)
				if s {
					if rd == 0xF {
						c.regs.cpsr = c.regs.read_spsr()
					} else {
						c.regs.cpsr.set_flag(.v, (~(rn_val ^ op2) & (rn_val ^ result)) >> 31 > 0)
						c.regs.cpsr.set_flag(.c, carry > 0)
						c.regs.cpsr.set_flag(.z, result == 0)
						c.regs.cpsr.set_flag(.n, result >> 31 > 0)
					}
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				step := if c.regs.cpsr.get_flag(.t) { u32(2) } else { 4 }
				val := c.read(bus, c.regs.r15 + step, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += step * 2
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

fn (mut c Cpu) adc(bus &Peripherals, cond u8, s bool, rn u8, rd u8, op2 u32, is_rs bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				rn_val := c.regs.read(rn)
				carry_in := u32(c.regs.cpsr.get_flag(.c))
				result, carry := bits.add_32(rn_val, op2, carry_in)
				c.regs.r15 += 4
				c.regs.write(rd, result)
				if s {
					if rd == 0xF {
						c.regs.cpsr = c.regs.read_spsr()
					} else {
						c.regs.cpsr.set_flag(.v, (~(rn_val ^ (op2 + carry_in)) & (rn_val ^ result)) >> 31 > 0)
						c.regs.cpsr.set_flag(.c, carry > 0)
						c.regs.cpsr.set_flag(.z, result == 0)
						c.regs.cpsr.set_flag(.n, result >> 31 > 0)
					}
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				step := if c.regs.cpsr.get_flag(.t) { u32(2) } else { 4 }
				val := c.read(bus, c.regs.r15 + step, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += step * 2
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

fn (mut c Cpu) tst(bus &Peripherals, cond u8, rn u8, op2 u32, is_rs bool, carry ?bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				result := c.regs.read(rn) & op2
				if ca := carry {
					c.regs.cpsr.set_flag(.c, ca)
				}
				c.regs.cpsr.set_flag(.z, result == 0)
				c.regs.cpsr.set_flag(.n, result >> 31 > 0)
				c.ctx.step = 1
				c.regs.r15 += 4
				if is_rs {
					return
				}
			}
			1 {
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

fn (mut c Cpu) cmp(bus &Peripherals, cond u8, rn u8, op2 u32, is_rs bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				rn_val := c.regs.read(rn)
				result, carry := bits.sub_32(rn_val, op2, 0)
				c.regs.cpsr.set_flag(.v, ((rn_val ^ op2) & (rn_val ^ result)) >> 31 > 0)
				c.regs.cpsr.set_flag(.c, carry > 0)
				c.regs.cpsr.set_flag(.z, result == 0)
				c.regs.cpsr.set_flag(.n, result >> 31 > 0)
				c.ctx.step = 1
				c.regs.r15 += 4
				if is_rs {
					return
				}
			}
			1 {
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

fn (mut c Cpu) orr(bus &Peripherals, cond u8, s bool, rn u8, rd u8, op2 u32, is_rs bool, carry ?bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				result := c.regs.read(rn) | op2
				c.regs.r15 += 4
				c.regs.write(rd, result)
				if s {
					if rd == 0xF {
						c.regs.cpsr = c.regs.read_spsr()
					} else {
						if ca := carry {
							c.regs.cpsr.set_flag(.c, ca)
						}
						c.regs.cpsr.set_flag(.z, result == 0)
						c.regs.cpsr.set_flag(.n, result >> 31 > 0)
					}
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				step := if c.regs.cpsr.get_flag(.t) { u32(2) } else { 4 }
				val := c.read(bus, c.regs.r15 + step, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += step * 2
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

fn (mut c Cpu) mov(bus &Peripherals, cond u8, s bool, rd u8, op2 u32, is_rs bool, carry ?bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				c.regs.r15 += 4
				c.regs.write(rd, op2)
				if s {
					if rd == 0xF {
						c.regs.cpsr = c.regs.read_spsr()
					} else {
						if ca := carry {
							c.regs.cpsr.set_flag(.c, ca)
						}
						c.regs.cpsr.set_flag(.z, op2 == 0)
						c.regs.cpsr.set_flag(.n, op2 >> 31 > 0)
					}
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				step := if c.regs.cpsr.get_flag(.t) { u32(2) } else { 4 }
				val := c.read(bus, c.regs.r15 + step, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += step * 2
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

fn (mut c Cpu) bic(bus &Peripherals, cond u8, s bool, rn u8, rd u8, op2 u32, is_rs bool, carry ?bool) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				result := c.regs.read(rn) & ~op2
				c.regs.r15 += 4
				c.regs.write(rd, result)
				if s {
					if rd == 0xF {
						c.regs.cpsr = c.regs.read_spsr()
					} else {
						if ca := carry {
							c.regs.cpsr.set_flag(.c, ca)
						}
						c.regs.cpsr.set_flag(.z, result == 0)
						c.regs.cpsr.set_flag(.n, result >> 31 > 0)
					}
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
				if is_rs {
					return
				}
			}
			1 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.regs.cpsr.get_flag(.t) { u32(0xFFFF) } else { 0xFFFF_FFFF }
				step := if c.regs.cpsr.get_flag(.t) { u32(2) } else { 4 }
				val := c.read(bus, c.regs.r15 + step, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += step * 2
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

fn (mut c Cpu) strh(mut bus Peripherals, cond u8, is_pre bool, is_plus bool, flag bool, rn u8, rd u8, offset_ u32) {
	c.check_cond(bus, cond) or { return }
	offset := if is_plus { offset_ } else { -offset_ }
	for {
		match c.ctx.step {
			0 {
				c.ctx.addr = c.regs.read(rn)
				if is_pre {
					c.ctx.addr += offset
				}
				if is_pre && flag {
					c.regs.write(rn, c.ctx.addr)
				}
				c.regs.r15 += 4
				c.ctx.val = c.regs.read(rd)
				c.ctx.step = 1
			}
			1 {
				size := u32(0xFFFF)
				c.write(mut bus, c.ctx.addr, size & c.ctx.val, size) or { return }
				if !is_pre {
					c.ctx.addr += offset
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

fn (mut c Cpu) ldrh(bus &Peripherals, cond u8, is_pre bool, is_plus bool, flag bool, rn u8, rd u8, offset_ u32) {
	c.check_cond(bus, cond) or { return }
	offset := if is_plus { offset_ } else { -offset_ }
	match c.ctx.step {
		0 {
			c.ctx.addr = c.regs.read(rn)
			if is_pre {
				c.ctx.addr += offset
			}
			if is_pre && flag {
				c.regs.write(rn, c.ctx.addr)
			}
			c.regs.r15 += 4
			c.ctx.step = 1
		}
		1 {
			size := u32(0xFFFF)
			val := c.read(bus, c.ctx.addr, size) or { return } & size
			c.regs.write(rd, val)
			if !is_pre {
				c.ctx.addr += offset
				c.regs.write(rn, c.ctx.addr)
			}
			c.ctx.step = if rd == 0xF { 2 } else { 4 }
		}
		2 {
			val := c.read(bus, c.regs.r15, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			c.ctx.step = 3
		}
		3 {
			val := c.read(bus, c.regs.r15 + 4, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[2] = val
			c.regs.r15 += 8
			c.ctx.step = 4
		}
		4 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) ldrsh(bus &Peripherals, cond u8, is_pre bool, is_plus bool, flag bool, rn u8, rd u8, offset_ u32) {
	c.check_cond(bus, cond) or { return }
	offset := if is_plus { offset_ } else { -offset_ }
	match c.ctx.step {
		0 {
			c.ctx.addr = c.regs.read(rn)
			if is_pre {
				c.ctx.addr += offset
			}
			if is_pre && flag {
				c.regs.write(rn, c.ctx.addr)
			}
			c.regs.r15 += 4
			c.ctx.step = 1
		}
		1 {
			size := u32(0xFFFF)
			val := u32(i32(i16(c.read(bus, c.ctx.addr, size) or { return })))
			c.regs.write(rd, val)
			if !is_pre {
				c.ctx.addr += offset
				c.regs.write(rn, c.ctx.addr)
			}
			c.ctx.step = if rd == 0xF { 2 } else { 4 }
		}
		2 {
			val := c.read(bus, c.regs.r15, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			c.ctx.step = 3
		}
		3 {
			val := c.read(bus, c.regs.r15 + 4, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[2] = val
			c.regs.r15 += 8
			c.ctx.step = 4
		}
		4 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) ldr(bus &Peripherals, cond u8, is_pre bool, is_plus bool, is_8bit bool, flag bool, rn u8, rd u8, offset_ u32) {
	c.check_cond(bus, cond) or { return }
	offset := if is_plus { offset_ } else { -offset_ }
	match c.ctx.step {
		0 {
			c.ctx.addr = c.regs.read(rn)
			if is_pre {
				c.ctx.addr += offset
			}
			if is_pre && flag {
				c.regs.write(rn, c.ctx.addr)
			}
			c.regs.r15 += 4
			c.ctx.step = 1
		}
		1 {
			size := if is_8bit { u32(0xFF) } else { 0xFFFF_FFFF }
			val := c.read(bus, c.ctx.addr, size) or { return } & size
			c.regs.write(rd, val)
			if !is_pre {
				c.ctx.addr += offset
				c.regs.write(rn, c.ctx.addr)
			}
			c.ctx.step = if rd == 0xF { 2 } else { 4 }
		}
		2 {
			val := c.read(bus, c.regs.r15, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			c.ctx.step = 3
		}
		3 {
			val := c.read(bus, c.regs.r15 + 4, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[2] = val
			c.regs.r15 += 8
			c.ctx.step = 4
		}
		4 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) str_(mut bus Peripherals, cond u8, is_pre bool, is_plus bool, is_8bit bool, flag bool, rn u8, rd u8, offset_ u32) {
	c.check_cond(bus, cond) or { return }
	offset := if is_plus { offset_ } else { -offset_ }
	for {
		match c.ctx.step {
			0 {
				c.ctx.addr = c.regs.read(rn)
				if is_pre {
					c.ctx.addr += offset
				}
				if is_pre && flag {
					c.regs.write(rn, c.ctx.addr)
				}
				c.regs.r15 += 4
				c.ctx.val = c.regs.read(rd)
				c.ctx.step = 1
			}
			1 {
				size := if is_8bit { u32(0xFF) } else { 0xFFFF_FFFF }
				c.write(mut bus, c.ctx.addr, size & c.ctx.val, size) or { return }
				if !is_pre {
					c.ctx.addr += offset
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

fn (mut c Cpu) ldm(bus &Peripherals, cond u8, is_pre bool, is_up bool, s bool, write_back bool, rn u8, rlist u16) {
	c.check_cond(bus, cond) or { return }
	match c.ctx.step {
		0 {
			c.ctx.addr = c.regs.read(rn)
			if is_pre {
				if is_up {
					c.ctx.addr += 4
				} else {
					c.ctx.addr -= 4
				}
				if write_back && rlist != 0 {
					c.regs.write(rn, c.ctx.addr)
				}
			}
			c.ctx.val = rlist
			c.regs.r15 += 4
			c.ctx.step = if rlist == 0 { 4 } else { 1 }
		}
		1 {
			val := c.read(bus, c.ctx.addr, 0xFFFF_FFFF) or { return }
			reg := if is_up {
				bits.trailing_zeros_16(u16(c.ctx.val))
			} else {
				bits.len_16(u16(c.ctx.val)) - 1
			}
			if s && rlist >> 15 == 0 {
				c.regs.write_user_register(u8(reg), val)
			} else {
				c.regs.write(u8(reg), val)
			}
			c.ctx.val &= ~(1 << reg)
			if !is_pre || (is_pre && c.ctx.val != 0) {
				if is_up {
					c.ctx.addr += 4
				} else {
					c.ctx.addr -= 4
				}
				if write_back {
					c.regs.write(rn, c.ctx.addr)
				}
			}
			if c.ctx.val == 0 {
				c.ctx.step = if rlist >> 15 > 0 { 2 } else { 4 }
			}
		}
		2 {
			is_thumb := if s { c.regs.read_spsr().get_flag(.t) } else { false }
			size := if is_thumb { u32(0xFFFF) } else { 0xFFFF_FFFF }
			val := c.read(bus, c.regs.r15, size) or { return } & size
			if s {
				c.regs.cpsr = c.regs.read_spsr()
			}
			c.ctx.opcodes[1] = val
			c.ctx.step = 3
		}
		3 {
			is_thumb := if s { c.regs.cpsr.get_flag(.t) } else { false }
			size := if is_thumb { u32(0xFFFF) } else { 0xFFFF_FFFF }
			step := if is_thumb { u32(2) } else { 4 }
			val := c.read(bus, c.regs.r15 + step, size) or { return } & size
			c.ctx.opcodes[2] = val
			c.regs.r15 += step * 2
			c.ctx.step = 4
		}
		4 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) stm(mut bus Peripherals, cond u8, is_pre bool, is_up bool, s bool, write_back bool, rn u8, rlist u16) {
	c.check_cond(bus, cond) or { return }
	for {
		match c.ctx.step {
			0 {
				c.ctx.addr = c.regs.read(rn)
				if is_pre {
					if is_up {
						c.ctx.addr += 4
					} else {
						c.ctx.addr -= 4
					}
					if write_back && rlist != 0 {
						c.regs.write(rn, c.ctx.addr)
					}
				}
				c.ctx.val = rlist
				c.regs.r15 += 4
				c.ctx.step = if rlist == 0 { 2 } else { 1 }
			}
			1 {
				reg := if is_up {
					bits.trailing_zeros_16(u16(c.ctx.val))
				} else {
					bits.len_16(u16(c.ctx.val)) - 1
				}
				val := if s {
					c.regs.read_user_register(u8(reg))
				} else {
					c.regs.read(u8(reg))
				}
				c.write(mut bus, c.ctx.addr, val, 0xFFFF_FFFF) or { return }
				c.ctx.val &= ~(1 << reg)
				if !is_pre || (is_pre && c.ctx.val != 0) {
					if is_up {
						c.ctx.addr += 4
					} else {
						c.ctx.addr -= 4
					}
					if write_back {
						c.regs.write(rn, c.ctx.addr)
					}
				}
				if c.ctx.val == 0 {
					c.ctx.step = 2
				}
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
	size := u32(0xFFFF_FFFF)
	match c.ctx.step {
		0 {
			val := c.read(bus, base_pc, size) or { return } & size
			c.ctx.opcodes[1] = val
			c.ctx.step = 1
		}
		1 {
			val := c.read(bus, base_pc + 4, size) or { return } & size
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

fn (mut c Cpu) swi(bus &Peripherals, cond u8) {
	c.check_cond(bus, cond) or { return }
	vector_pc := u32(0x08)
	match c.ctx.step {
		0 {
			val := c.read(bus, vector_pc, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			old_cpsr := c.regs.cpsr
			c.regs.cpsr.set_mode(.supervisor)
			c.regs.write(0xE, c.regs.r15 - 4)
			c.regs.write_spsr(old_cpsr)
			c.regs.cpsr.set_flag(.i, true)
			c.regs.r15 = vector_pc + 8
			c.ctx.step = 1
		}
		1 {
			val := c.read(bus, vector_pc + 4, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[2] = val
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) int(bus &Peripherals) {
	vector_pc := u32(0x18)
	match c.ctx.step {
		0 {
			val := c.read(bus, vector_pc, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			old_cpsr := c.regs.cpsr
			c.regs.cpsr.set_mode(.irq)
			c.regs.write(0xE, c.regs.r15 - 8)
			c.regs.write_spsr(old_cpsr)
			c.regs.cpsr.set_flag(.t, false)
			c.regs.cpsr.set_flag(.i, true)
			c.regs.r15 = vector_pc + 8
			c.ctx.step = 1
		}
		1 {
			val := c.read(bus, vector_pc + 4, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[2] = val
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}
