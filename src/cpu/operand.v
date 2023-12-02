module cpu

import util

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
		op2, ca := util.ror(imm, ls)
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
		ls2 := if !r && ls == 0 { u32(32) } else { ls }
		op2, carry := match (u32(opcode) >> 5) & 3 {
			0 {
				util.lsl(rm, ls)
			}
			1 {
				util.lsr(rm, ls2)
			}
			2 {
				util.asr(rm, ls2)
			}
			else {
				if !r && ls == 0 {
					rm >> 1 | (u32(c.regs.cpsr.get_flag(.c)) << 31), ?bool(rm & 1 > 0)
				} else {
					util.ror(rm, ls)
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
		ls2 := if ls == 0 { u32(32) } else { ls }
		op2, _ := match (u32(opcode) >> 5) & 3 {
			0 {
				util.lsl(rm, ls)
			}
			1 {
				util.lsr(rm, ls2)
			}
			2 {
				util.asr(rm, ls2)
			}
			else {
				if ls == 0 {
					rm >> 1 | (u32(c.regs.cpsr.get_flag(.c)) << 31), ?bool(none)
				} else {
					util.ror(rm, ls)
				}
			}
		}
		return op2
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
		op2, _ := util.ror(imm, ls)
		return op2
	} else {
		// reg
		return c.regs.read(opcode.rm())
	}
}
