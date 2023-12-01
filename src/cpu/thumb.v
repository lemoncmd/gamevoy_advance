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

fn (mut c Cpu) thumb_hi_reg(bus &Peripherals, op u8, msbd bool, msbs bool, rs_ u8, rd_ u8) {
	for {
		match c.ctx.step {
			0 {
				rd := if op == 3 { u8(0xF) } else { u8(msbd) << 3 | rd_ }
				rs := u8(msbs) << 3 | rs_
				c.regs.r15 += 2
				if op == 2 && rd == 8 && rs == 8 {
					c.ctx.step = 3
					continue
				}
				c.ctx.val = 2
				if op == 1 {
					rd_val := c.regs.read(rd)
					rs_val := c.regs.read(rs)
					result, carry := bits.sub_32(rd_val, rs_val, 0)
					c.regs.cpsr.set_flag(.v, ((rd_val ^ rs_val) & (rd_val ^ result)) >> 31 > 0)
					c.regs.cpsr.set_flag(.c, carry > 0)
					c.regs.cpsr.set_flag(.z, result == 0)
					c.regs.cpsr.set_flag(.n, result >> 31 > 0)
				} else if op == 3 {
					rs_val := c.regs.read(rs)
					is_thumb := rs_val & 1 > 0
					val := rs_val & u32(if is_thumb { ~1 } else { ~3 })
					c.regs.write(rd, val)
					c.ctx.val = u32(if is_thumb { 2 } else { 4 })
					if !is_thumb {
						c.regs.cpsr.set_flag(.t, false)
					}
				} else {
					val := c.regs.read(rs) + if op == 0 { c.regs.read(rd) } else { 0 }
					c.regs.write(rd, val)
				}
				c.ctx.step = if rd == 0xF { 1 } else { 3 }
			}
			1 {
				size := if c.ctx.val == 2 { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15, size) or { return } & size
				c.ctx.opcodes[1] = val
				c.ctx.step = 2
				return
			}
			2 {
				size := if c.ctx.val == 2 { u32(0xFFFF) } else { 0xFFFF_FFFF }
				val := c.read(bus, c.regs.r15 + c.ctx.val, size) or { return } & size
				c.ctx.opcodes[2] = val
				c.regs.r15 += c.ctx.val << 1
				c.ctx.step = 3
				return
			}
			3 {
				c.fetch(bus) or { return }
				c.ctx.step = 0
				return
			}
			else {}
		}
	}
}

fn (mut c Cpu) thumb_ldr(bus &Peripherals, rd u8, offset_ u8) {
	offset := u16(offset_) << 2
	match c.ctx.step {
		0 {
			c.ctx.addr = (c.regs.r15 & ~2) + offset
			c.regs.r15 += 2
			c.ctx.step = 1
		}
		1 {
			val := c.read(bus, c.ctx.addr, 0xFFFF_FFFF) or { return }
			c.regs.write(rd, val)
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) thumb_str_reg_offset(mut bus Peripherals, size u32, ro u8, rb u8, rd u8) {
	for {
		match c.ctx.step {
			0 {
				c.ctx.addr = c.regs.read(rb) + c.regs.read(ro)
				c.regs.r15 += 2
				c.ctx.step = 1
			}
			1 {
				c.write(mut bus, c.ctx.addr, size & c.regs.read(rd), size) or { return }
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

fn (mut c Cpu) thumb_ldr_reg_offset(bus &Peripherals, size u32, signed bool, ro u8, rb u8, rd u8) {
	match c.ctx.step {
		0 {
			c.ctx.addr = c.regs.read(rb) + c.regs.read(ro)
			c.regs.r15 += 2
			c.ctx.step = 1
		}
		1 {
			mut val := c.read(bus, c.ctx.addr, size) or { return } & size
			if signed {
				if size == 0xFF {
					val = u32(i32(i8(val)))
				} else {
					val = u32(i32(i16(val)))
				}
			}
			c.regs.write(rd, val)
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) thumb_str_imm_offset(mut bus Peripherals, size u32, imm u8, rb u8, rd u8) {
	for {
		match c.ctx.step {
			0 {
				c.ctx.addr = c.regs.read(rb) + imm
				c.regs.r15 += 2
				c.ctx.step = 1
			}
			1 {
				c.write(mut bus, c.ctx.addr, size & c.regs.read(rd), size) or { return }
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

fn (mut c Cpu) thumb_ldr_imm_offset(bus &Peripherals, size u32, imm u8, rb u8, rd u8) {
	match c.ctx.step {
		0 {
			c.ctx.addr = c.regs.read(rb) + imm
			c.regs.r15 += 2
			c.ctx.step = 1
		}
		1 {
			mut val := c.read(bus, c.ctx.addr, size) or { return } & size
			c.regs.write(rd, val)
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) thumb_str_sp_relative(mut bus Peripherals, rd u8, imm u16) {
	for {
		match c.ctx.step {
			0 {
				c.ctx.addr = c.regs.read(13) + imm
				c.regs.r15 += 2
				c.ctx.step = 1
			}
			1 {
				c.write(mut bus, c.ctx.addr, c.regs.read(rd), 0xFFFF_FFFF) or { return }
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

fn (mut c Cpu) thumb_ldr_sp_relative(bus &Peripherals, rd u8, imm u16) {
	match c.ctx.step {
		0 {
			c.ctx.addr = c.regs.read(13) + imm
			c.regs.r15 += 2
			c.ctx.step = 1
		}
		1 {
			mut val := c.read(bus, c.ctx.addr, 0xFFFF_FFFF) or { return }
			c.regs.write(rd, val)
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) thumb_load_pc_address(bus &Peripherals, rd u8, imm u16) {
	for {
		match c.ctx.step {
			0 {
				c.regs.write(rd, (c.regs.r15 & ~2) + imm)
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

fn (mut c Cpu) thumb_load_sp_address(bus &Peripherals, rd u8, imm u16) {
	for {
		match c.ctx.step {
			0 {
				c.regs.write(rd, c.regs.read(13) + imm)
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

fn (mut c Cpu) thumb_add_sp(bus &Peripherals, op bool, imm_ u16) {
	for {
		match c.ctx.step {
			0 {
				imm := if op { -imm_ } else { imm_ }
				c.regs.write(13, c.regs.read(13) + imm)
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

fn (mut c Cpu) thumb_pop(bus &Peripherals, pop_pc bool, rlist_ u8) {
	rlist := u16(rlist_) | u16(if pop_pc { 0x8000 } else { 0 })
	match c.ctx.step {
		0 {
			c.ctx.addr = c.regs.read(13)
			c.ctx.val = rlist
			c.regs.r15 += 2
			c.ctx.step = if rlist == 0 { 4 } else { 1 }
		}
		1 {
			val := c.read(bus, c.ctx.addr, 0xFFFF_FFFF) or { return }
			reg := bits.trailing_zeros_16(u16(c.ctx.val))
			c.regs.write(u8(reg), val)
			c.ctx.val &= ~(1 << reg)
			c.ctx.addr += 4
			c.regs.write(13, c.ctx.addr)
			if c.ctx.val == 0 {
				c.ctx.step = if rlist >> 15 > 0 { 2 } else { 4 }
			}
		}
		2 {
			val := c.read(bus, c.regs.r15, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			c.ctx.step = 3
		}
		3 {
			val := c.read(bus, c.regs.r15 + 2, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[2] = val
			c.regs.r15 += 2
			c.ctx.step = 4
		}
		4 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}

fn (mut c Cpu) thumb_push(mut bus Peripherals, push_lr bool, rlist_ u8) {
	rlist := u16(rlist_) | u16(if push_lr { 0x4000 } else { 0 })
	for {
		match c.ctx.step {
			0 {
				c.ctx.addr = c.regs.read(13)
				c.ctx.addr -= 4
				if rlist != 0 {
					c.regs.write(13, c.ctx.addr)
				}
				c.ctx.val = rlist
				c.regs.r15 += 2
				c.ctx.step = if rlist == 0 { 2 } else { 1 }
			}
			1 {
				reg := bits.len_16(u16(c.ctx.val)) - 1
				val := c.regs.read(u8(reg))
				c.write(mut bus, c.ctx.addr, val, 0xFFFF_FFFF) or { return }
				c.ctx.val &= ~(1 << reg)
				if c.ctx.val != 0 {
					c.ctx.addr -= 4
					c.regs.write(13, c.ctx.addr)
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

fn (mut c Cpu) thumb_ldmia(bus &Peripherals, rd u8, rlist u8) {
	match c.ctx.step {
		0 {
			c.ctx.addr = c.regs.read(rd)
			c.ctx.val = rlist
			c.regs.r15 += 2
			c.ctx.step = if rlist == 0 { 2 } else { 1 }
		}
		1 {
			val := c.read(bus, c.ctx.addr, 0xFFFF_FFFF) or { return }
			reg := bits.trailing_zeros_8(u8(c.ctx.val))
			c.regs.write(u8(reg), val)
			c.ctx.val &= ~(1 << reg)
			c.ctx.addr += 4
			c.regs.write(rd, c.ctx.addr)
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

fn (mut c Cpu) thumb_stmia(mut bus Peripherals, rd u8, rlist u8) {
	for {
		match c.ctx.step {
			0 {
				c.ctx.addr = c.regs.read(rd)
				c.ctx.val = rlist
				c.regs.r15 += 2
				c.ctx.step = if rlist == 0 { 2 } else { 1 }
			}
			1 {
				reg := bits.trailing_zeros_8(u8(c.ctx.val))
				val := c.regs.read(u8(reg))
				c.write(mut bus, c.ctx.addr, val, 0xFFFF_FFFF) or { return }
				c.ctx.val &= ~(1 << reg)
				c.ctx.addr += 4
				c.regs.write(rd, c.ctx.addr)
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

fn (mut c Cpu) thumb_swi(bus &Peripherals) {
	vector_pc := u32(0x08)
	match c.ctx.step {
		0 {
			val := c.read(bus, vector_pc, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			old_cpsr := c.regs.cpsr
			c.regs.cpsr.set_mode(.supervisor)
			c.regs.write(0xE, c.regs.r15 - 2)
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

fn (mut c Cpu) thumb_load_lr_high(bus &Peripherals, offset u16) {
	for {
		match c.ctx.step {
			0 {
				c.regs.write(14, c.regs.r15 + u32(offset) << 12)
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

fn (mut c Cpu) thumb_bl(bus &Peripherals, offset u16) {
	base_pc := c.regs.read(14) + offset << 1
	match c.ctx.step {
		0 {
			val := c.read(bus, base_pc, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[1] = val
			c.ctx.step = 1
		}
		1 {
			val := c.read(bus, base_pc + 2, 0xFFFF_FFFF) or { return }
			c.ctx.opcodes[2] = val
			c.regs.write(14, c.regs.r15 - 2)
			c.regs.r15 = base_pc + 4
			c.ctx.step = 2
		}
		2 {
			c.fetch(bus) or { return }
			c.ctx.step = 0
		}
		else {}
	}
}
