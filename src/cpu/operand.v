module cpu

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

// returns op2 and is_rs and carry
fn (c &Cpu) calc_alu_op2(opcode Opcode) (u32, bool, ?bool) {
	if opcode.bit(25) {
		// imm
		imm := u32(opcode) & 0xFF
		ls := ((u32(opcode) >> 8) & 0xF) << 1
		op2 := imm >> ls | imm << (32 - ls)
		ca := if ls == 0 { ?bool(none) } else { op2 >> 31 > 0 }
		return op2, false, ca
	} else {
		// reg
		r := opcode.bit(4)
		rm := c.regs.read(opcode.rm())
		ls := if r {
			c.regs.read(u8(u32(opcode) >> 8) & 0xF)
		} else {
			(u32(opcode) >> 7) & 0x1F
		}
		// TODO want to merge these two matches if v fix bug
		op2 := match (u32(opcode) >> 5) & 3 {
			0 {
				rm << ls
			}
			1 {
				ls2 := if !r && ls == 0 { 32 } else { ls }
				rm >> ls2
			}
			2 {
				ls2 := if !r && ls == 0 { 32 } else { ls }
				u32(i32(rm) >> ls2)
			}
			else {
				if !r && ls == 0 {
					rm >> 1 | (u32(c.regs.cpsr.get_flag(.c)) << 31)
				} else {
					ls2 := ls & 0x1F
					rm >> ls2 | rm << (32 - ls2)
				}
			}
		}
		ls2 := if !r && ls == 0 { 32 } else { ls }
		carry := match (u32(opcode) >> 5) & 3 {
			0 {
				if ls == 0 { ?bool(none) } else { (rm >> (32 - ls)) & 1 > 0 }
			}
			1 {
				if ls2 == 0 { ?bool(none) } else { (rm >> (ls2 - 1)) & 1 > 0 }
			}
			2 {
				if ls2 == 0 { ?bool(none) } else { (rm >> (ls2 - 1)) & 1 > 0 }
			}
			else {
				if !r && ls == 0 {
					?bool(rm & 1 > 0)
				} else {
					ls3 := ls & 0x1F
					op2_ := rm >> ls3 | rm << (32 - ls3)
					if ls == 0 {
						?bool(none)
					} else {
						op2_ >> 31 > 0
					}
				}
			}
		}
		return op2, r, carry
	}
}

fn (c &Cpu) ldstr_offset(opcode Opcode) u32 {
	if !opcode.bit(25) {
		// imm
		return u32(opcode) & 0xFFF
	} else {
		// reg
		rm := c.regs.read(opcode.rm())
		ls := (u32(opcode) >> 7) & 0x1F
		return match (u32(opcode) >> 5) & 3 {
			0 {
				rm << ls
			}
			1 {
				ls2 := if ls == 0 { 32 } else { ls }
				rm >> ls2
			}
			2 {
				ls2 := if ls == 0 { 32 } else { ls }
				u32(i32(rm) >> ls2)
			}
			else {
				if ls == 0 {
					rm >> 1 | (u32(c.regs.cpsr.get_flag(.c)) << 31)
				} else {
					ls2 := ls & 0x1F
					rm >> ls2 | rm << (32 - ls2)
				}
			}
		}
	}
}

fn (c &Cpu) unusual_ldstr_offset(opcode Opcode) u32 {
	return if opcode.bit(22) {
		// imm
		u32(opcode) & 0xF | (u32(opcode) >> 4) & 0xF0
	} else {
		// reg
		c.regs.read(opcode.rm())
	}
}

fn (c &Cpu) msr_value(opcode Opcode) u32 {
	if opcode.bit(25) {
		// imm
		imm := u32(opcode) & 0xFF
		ls := ((u32(opcode) >> 8) & 0xF) << 1
		return imm >> ls | imm << (32 - ls)
	} else {
		// reg
		return c.regs.read(opcode.rm())
	}
}
