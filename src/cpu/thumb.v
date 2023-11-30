module cpu

import math.bits
import peripherals { Peripherals }

fn (mut c Cpu) thumb_shift(bus &Peripherals, op u8, offset u8, rs u8, rd u8) {
	for {
		match c.ctx.step {
			0 {
				rs_val := c.regs.read(rs)
				offset2 := if offset == 0 { 32 } else { offset }
				val, carry := match op {
					0 { rs_val << offset, (rs_val >> (32 - offset)) & 1 > 0 }
					1 { rs_val >> offset2, (rs_val >> (offset2 - 1)) & 1 > 0 }
					2 { u32(i32(rs_val) >> offset2), (rs_val >> (offset2 - 1)) & 1 > 0 }
					else { panic('unreachable') }
				}
				c.regs.write(rs, val)
				if op != 0 || offset != 0 {
					c.regs.cpsr.set_flag(.c, carry)
				}
				c.regs.cpsr.set_flag(.z, val == 0)
				c.regs.cpsr.set_flag(.n, val >> 31 > 0)
				c.regs.r15 += 2
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

fn (mut c Cpu) thumb_add(bus &Peripherals, op u8, rn_or_imm u8, rs u8, rd u8) {
	for {
		match c.ctx.step {
			0 {
				rs_val := c.regs.read(rs)
				op2 := if op & 2 > 0 { u32(rn_or_imm) } else { c.regs.read(rn_or_imm) }
				rev_op2 := if op & 1 > 0 { -op2 } else { op2 }
				result, carry := bits.add_32(rs_val, rev_op2, 0)
				c.regs.write(rs, result)
				c.regs.cpsr.set_flag(.v, (~(rs_val ^ rev_op2) & (rs_val ^ result)) >> 31 > 0)
				c.regs.cpsr.set_flag(.c, if op & 1 > 0 { carry == 0 } else { carry > 0 })
				c.regs.cpsr.set_flag(.z, result == 0)
				c.regs.cpsr.set_flag(.n, result >> 31 > 0)
				c.regs.r15 += 2
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

fn (mut c Cpu) thumb_arith_imm(bus &Peripherals, op u8, rd u8, imm u8) {
	for {
		match c.ctx.step {
			0 {
				rd_val := c.regs.read(rd)
				rev_op2 := if op & 1 > 0 { -imm } else { imm }
				result, carry := bits.add_32(rd_val, rev_op2, 0)
				match op {
					0 { c.regs.write(rd, imm) }
					1 {}
					else { c.regs.write(rd, result) }
				}
				if op == 0 {
					c.regs.cpsr.set_flag(.z, imm == 0)
					c.regs.cpsr.set_flag(.n, false)
				} else {
					c.regs.cpsr.set_flag(.v, (~(rd_val ^ rev_op2) & (rd_val ^ result)) >> 31 > 0)
					c.regs.cpsr.set_flag(.c, if op & 1 > 0 { carry == 0 } else { carry > 0 })
					c.regs.cpsr.set_flag(.z, result == 0)
					c.regs.cpsr.set_flag(.n, result >> 31 > 0)
				}
				c.regs.r15 += 2
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

fn (mut c Cpu) thumb_arith_logic(bus &Peripherals, op u8, rs u8, rd u8) {
	for {
		match c.ctx.step {
			0 {
				rd_val := c.regs.read(rd)
				rs_val := c.regs.read(rs)
				val := match op {
					0x0, 0x8 { rd_val & rs_val }
					0x1 { rd_val ^ rs_val }
					0xC { rd_val | rs_val }
					0xE { rd_val & ~rs_val }
					0xF { ~rs_val }
					else { panic('unreachable') }
				}
				if op != 8 {
					c.regs.write(rd, val)
				}
				c.regs.cpsr.set_flag(.z, val == 0)
				c.regs.cpsr.set_flag(.n, val >> 31 > 0)
				c.regs.r15 += 2
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

fn (mut c Cpu) thumb_arith_shift(bus &Peripherals, op u8, rs u8, rd u8) {
	match c.ctx.step {
		0 {
			rd_val := c.regs.read(rd)
			rs_val := c.regs.read(rs) & 0xFF
			val := match op {
				2 { rd_val << rs_val }
				3 { rd_val >> rs_val }
				4 { u32(i32(rd_val) >> rs_val) }
				7 { rd_val >> (rs_val & 0x1F) | rd_val << (32 - (rs_val & 0x1F)) }
				else { panic('unreachable') }
			}
			carry := match op {
				2 { (rd_val >> (32 - rs_val)) & 1 > 0 }
				3 { (rd_val >> (1 - rs_val)) & 1 > 0 }
				4 { (rd_val >> (1 - rs_val)) & 1 > 0 }
				7 { val >> 31 > 0 }
				else { panic('unreachable') }
			}
			c.regs.write(rd, val)
			if rs_val != 0 {
				c.regs.cpsr.set_flag(.c, carry)
			}
			c.regs.cpsr.set_flag(.z, val == 0)
			c.regs.cpsr.set_flag(.n, val >> 31 > 0)
			c.regs.r15 += 2
			c.ctx.step = 1
		}
		1 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) thumb_mul(bus &Peripherals, op u8, rs u8, rd u8) {
	match c.ctx.step {
		0 {
			rd_val := c.regs.read(rd)
			rs_val := c.regs.read(rs)
			val := rd_val * rs_val
			c.regs.write(rd, val)
			c.regs.cpsr.set_flag(.c, false)
			c.regs.cpsr.set_flag(.z, val == 0)
			c.regs.cpsr.set_flag(.n, val >> 31 > 0)
			c.ctx.val = match rd_val >> 8 {
				0xFFFFFF { 1 }
				0xFFFF00...0xFFFFFE { 2 }
				0xFF0000...0xFFFEFF { 3 }
				else { 4 }
			}
			c.regs.r15 += 2
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

fn (mut c Cpu) thumb_arith_add(bus &Peripherals, op u8, rs u8, rd u8) {
	for {
		match c.ctx.step {
			0 {
				rd_val := if op != 9 { c.regs.read(rd) } else { 0 }
				rs_val := c.regs.read(rs)
				op2 := if op in [0x5, 0xB] { rs_val } else { -rs_val }
				carry_in := u32(match op {
					5 { c.regs.cpsr.get_flag(.c) }
					6 { !c.regs.cpsr.get_flag(.c) }
					else { false }
				})
				result, carry := bits.add_32(rd_val, op2, carry_in)
				if op !in [0xA, 0xB] {
					c.regs.write(rd, result)
				}
				c.regs.cpsr.set_flag(.v, (~(rd_val ^ op2) & (rd_val ^ result)) >> 31 > 0)
				c.regs.cpsr.set_flag(.c, if op in [0x5, 0xB] { carry > 0 } else { carry == 0 })
				c.regs.cpsr.set_flag(.z, result == 0)
				c.regs.cpsr.set_flag(.n, result >> 31 > 0)
				c.regs.r15 += 2
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
