module cpu

// returns op2 and is_rs and carry
fn (c &Cpu) calc_alu_op2(opcode Opcode) (u32, bool, ?bool) {
	if (u32(opcode) >> 25) & 1 > 0 {
		// imm
		imm := u32(opcode) & 0xFF
		ls := ((u32(opcode) >> 8) & 0xF) << 1
		op2 := imm >> ls | imm << (32 - ls)
		ca := if ls == 0 { ?bool(none) } else { op2 >> 31 > 0 }
		return op2, false, ca
	} else {
		// reg
		r := u32(opcode) & 0x10 > 0
		rm := c.regs.read(u8(opcode))
		ls := if r {
			c.regs.read(u8(u32(opcode) >> 8))
		} else {
			(u32(opcode) >> 7) & 0x1F
		}
		op2, carry := match (u32(opcode) >> 5) & 3 {
			0 {
				ca := if ls == 0 { ?bool(none) } else { (rm >> (32 - ls)) & 1 > 0 }
				rm << ls, ca
			}
			1 {
				ls2 := if !r && ls == 0 { 32 } else { ls }
				ca := if ls2 == 0 { ?bool(none) } else { (rm >> (ls2 - 1)) & 1 > 0 }
				rm >> ls2, ca
			}
			2 {
				ls2 := if !r && ls == 0 { 32 } else { ls }
				ca := if ls2 == 0 { ?bool(none) } else { (rm >> (ls2 - 1)) & 1 > 0 }
				u32(i32(rm) >> ls2), ca
			}
			else {
				if !r && ls == 0 {
					rm >> 1 | (u32(c.regs.cpsr.get_flag(.c)) << 31), ?bool(rm & 1 > 0)
				} else {
					ls2 := ls & 0x1F
					op2_ := rm >> ls2 | rm << (32 - ls2)
					ca := if ls == 0 { ?bool(none) } else { op2_ >> 31 > 0 }
					op2_, ca
				}
			}
		}
		return op2, r, carry
	}
}
