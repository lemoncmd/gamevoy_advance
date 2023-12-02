module cpu

import peripherals { Peripherals }

fn (mut c Cpu) decode(mut bus Peripherals) {
	if c.ctx.is_thumb {
		c.decode_thumb(mut bus)
		return
	}
	opcode := Opcode(c.ctx.opcodes[0])
	base_opcode := opcode.base_opcode()
	// don't forget nds supported ops
	match base_opcode {
		// data processing / psr transfer
		0b00010_00_0_0000 {
			// mrs cpsr
			c.mrs_cpsr(bus, opcode.cond(), opcode.rd())
			return
		}
		0b00010_01_0_0000, 0b00110_01_0_0000...0b00110_01_0_1111 {
			// msr cpsr
			c.msr_cpsr(bus, opcode.cond(), opcode.bit(19), opcode.bit(16), opcode.rd(),
				c.msr_value(opcode))
			return
		}
		0b00010_10_0_0000 {
			// mrs spsr
			c.mrs_spsr(bus, opcode.cond(), opcode.rd())
			return
		}
		0b00010_11_0_0000, 0b00110_11_0_0000...0b00110_11_0_1111 {
			// msr spsr
			c.msr_spsr(bus, opcode.cond(), opcode.bit(19), opcode.bit(16), opcode.rd(),
				c.msr_value(opcode))
			return
		}
		// swap
		0b00010_0_00_1001 {
			// swp
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b00010_1_00_1001 {
			// swpb
			panic('unimplemented instruction: ${opcode:08x}')
		}
		// multiply
		0b000_0000_0_1001, 0b000_0000_1_1001 {
			// mul
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b000_0001_0_1001, 0b000_0001_1_1001 {
			// mla
			c.mla(bus, opcode.cond(), opcode.bit(20), opcode.rn(), opcode.rd(), opcode.rs(),
				opcode.rm())
			return
		}
		0b000_0100_0_1001, 0b000_0100_1_1001 {
			// umull
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b000_0101_0_1001, 0b000_0101_1_1001 {
			// umlal
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b000_0110_0_1001, 0b000_0110_1_1001 {
			// smull
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b000_0111_0_1001, 0b000_0111_1_1001 {
			// smlal
			panic('unimplemented instruction: ${opcode:08x}')
		}
		// bx
		0b0001_0010_0001 {
			// bx
			c.bx(bus, opcode.cond(), opcode.rm())
			return
		}
		// alu
		0b00_0_0000_0_0000...0b00_0_0000_1_1111, 0b00_1_0000_0_0000...0b00_1_0000_1_1111 {
			// and
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, carry := c.calc_alu_op2(opcode)
			c.and(bus, opcode.cond(), opcode.bit(20), opcode.rn(), opcode.rd(), op2, is_rs,
				carry)
			return
		}
		0b00_0_0001_0_0000...0b00_0_0001_1_1111, 0b00_1_0001_0_0000...0b00_1_0001_1_1111 {
			// eor
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, carry := c.calc_alu_op2(opcode)
			c.eor(bus, opcode.cond(), opcode.bit(20), opcode.rn(), opcode.rd(), op2, is_rs,
				carry)
			return
		}
		0b00_0_0010_0_0000...0b00_0_0010_1_1111, 0b00_1_0010_0_0000...0b00_1_0010_1_1111 {
			// sub
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, _ := c.calc_alu_op2(opcode)
			c.sub(bus, opcode.cond(), opcode.bit(20), opcode.rn(), opcode.rd(), op2, is_rs)
			return
		}
		0b00_0_0011_0_0000...0b00_0_0011_1_1111, 0b00_1_0011_0_0000...0b00_1_0011_1_1111 {
			// rsb
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, _ := c.calc_alu_op2(opcode)
			c.rsb(bus, opcode.cond(), opcode.bit(20), opcode.rn(), opcode.rd(), op2, is_rs)
			return
		}
		0b00_0_0100_0_0000...0b00_0_0100_1_1111, 0b00_1_0100_0_0000...0b00_1_0100_1_1111 {
			// add
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, _ := c.calc_alu_op2(opcode)
			c.add(bus, opcode.cond(), opcode.bit(20), opcode.rn(), opcode.rd(), op2, is_rs)
			return
		}
		0b00_0_0101_0_0000...0b00_0_0101_1_1111, 0b00_1_0101_0_0000...0b00_1_0101_1_1111 {
			// adc
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, _ := c.calc_alu_op2(opcode)
			c.adc(bus, opcode.cond(), opcode.bit(20), opcode.rn(), opcode.rd(), op2, is_rs)
			return
		}
		0b00_0_0110_0_0000...0b00_0_0110_1_1111, 0b00_1_0110_0_0000...0b00_1_0110_1_1111 {
			// sbc
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b00_0_0111_0_0000...0b00_0_0111_1_1111, 0b00_1_0111_0_0000...0b00_1_0111_1_1111 {
			// rsc
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b00_0_1000_1_0000...0b00_0_1000_1_1111, 0b00_1_1000_1_0000...0b00_1_1000_1_1111 {
			// tst
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, carry := c.calc_alu_op2(opcode)
			c.tst(bus, opcode.cond(), opcode.rn(), op2, is_rs, carry)
			return
		}
		0b00_0_1001_1_0000...0b00_0_1001_1_1111, 0b00_1_1001_1_0000...0b00_1_1001_1_1111 {
			// teq
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b00_0_1010_1_0000...0b00_0_1010_1_1111, 0b00_1_1010_1_0000...0b00_1_1010_1_1111 {
			// cmp
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, _ := c.calc_alu_op2(opcode)
			c.cmp(bus, opcode.cond(), opcode.rn(), op2, is_rs)
			return
		}
		0b00_0_1011_1_0000...0b00_0_1011_1_1111, 0b00_1_1011_1_0000...0b00_1_1011_1_1111 {
			// cmn
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b00_0_1100_0_0000...0b00_0_1100_1_1111, 0b00_1_1100_0_0000...0b00_1_1100_1_1111 {
			// orr
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, carry := c.calc_alu_op2(opcode)
			c.orr(bus, opcode.cond(), opcode.bit(20), opcode.rn(), opcode.rd(), op2, is_rs,
				carry)
			return
		}
		0b00_0_1101_0_0000...0b00_0_1101_1_1111, 0b00_1_1101_0_0000...0b00_1_1101_1_1111 {
			// mov
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, carry := c.calc_alu_op2(opcode)
			c.mov(bus, opcode.cond(), opcode.bit(20), opcode.rd(), op2, is_rs, carry)
			return
		}
		0b00_0_1110_0_0000...0b00_0_1110_1_1111, 0b00_1_1110_0_0000...0b00_1_1110_1_1111 {
			// bic
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			op2, is_rs, carry := c.calc_alu_op2(opcode)
			c.bic(bus, opcode.cond(), opcode.bit(20), opcode.rn(), opcode.rd(), op2, is_rs,
				carry)
			return
		}
		0b00_0_1111_0_0000...0b00_0_1111_1_1111, 0b00_1_1111_0_0000...0b00_1_1111_1_1111 {
			// mvn
			if !opcode.bit(25) && opcode.bit(7) && opcode.bit(4) {
				unsafe {
					goto unusual_word
				}
			}
			panic('unimplemented instruction: ${opcode:08x}')
		}
		// data transfer
		0b01_0_0_0000_0000...0b01_1_1_1111_1111 {
			// single data transfer
			if !opcode.bit(20) {
				// str
				c.str_(mut bus, opcode.cond(), opcode.bit(24), opcode.bit(23), opcode.bit(22),
					opcode.bit(21), opcode.rn(), opcode.rd(), c.ldstr_offset(opcode))
				return
			} else if !opcode.bit(25) || !opcode.bit(4) {
				// ldr
				c.ldr(bus, opcode.cond(), opcode.bit(24), opcode.bit(23), opcode.bit(22),
					opcode.bit(21), opcode.rn(), opcode.rd(), c.ldstr_offset(opcode))
				return
			}
		}
		0b100_0_0000_0000...0b100_1_1111_1111 {
			// block data transfer
			if opcode.bit(20) {
				// ldm
				c.ldm(bus, opcode.cond(), opcode.bit(24), opcode.bit(23), opcode.bit(22),
					opcode.bit(21), opcode.rn(), u16(opcode))
				return
			} else {
				// stm
				c.stm(mut bus, opcode.cond(), opcode.bit(24), opcode.bit(23), opcode.bit(22),
					opcode.bit(21), opcode.rn(), u16(opcode))
			}
		}
		// branch
		0b101_0_0000_0000...0b101_0_1111_1111 {
			// b
			c.b(bus, opcode.cond(), u32(i32(u32(opcode) << 8) >> 6))
			return
		}
		0b101_1_0000_0000...0b101_1_1111_1111 {
			// bl
			c.bl(bus, opcode.cond(), u32(i32(u32(opcode) << 8) >> 6))
			return
		}
		0b1111_0000_0000...0b1111_1111_1111 {
			// swx
			c.swi(bus, opcode.cond())
		}
		else {
			unusual_word:
			if base_opcode & 0xE00 == 0 && base_opcode & 0b1001 == 0b1001 && base_opcode & 0b110 > 0 {
				// nonusual word
				match u32(opcode.bit(20)) << 2 | (base_opcode >> 1) & 3 {
					1 {
						// strh
						c.strh(mut bus, opcode.cond(), opcode.bit(24), opcode.bit(23),
							opcode.bit(21), opcode.rn(), opcode.rd(), c.unusual_ldstr_offset(opcode))
						return
					}
					2 {
						// ldrd
						panic('unimplemented instruction: ${opcode:08x}')
					}
					3 {
						// strd
						panic('unimplemented instruction: ${opcode:08x}')
					}
					5 {
						// ldrh
						c.ldrh(bus, opcode.cond(), opcode.bit(24), opcode.bit(23), opcode.bit(21),
							opcode.rn(), opcode.rd(), c.unusual_ldstr_offset(opcode))
						return
					}
					6 {
						// ldrsb
						panic('unimplemented instruction: ${opcode:08x}')
					}
					7 {
						// ldrsh
						c.ldrsh(bus, opcode.cond(), opcode.bit(24), opcode.bit(23), opcode.bit(21),
							opcode.rn(), opcode.rd(), c.unusual_ldstr_offset(opcode))
						return
					}
					else {}
				}
			}
		}
	}
	// undefined exception
}

fn (mut c Cpu) decode_thumb(mut bus Peripherals) {
	opcode := ThumbOpcode(u16(c.ctx.opcodes[0]))
	match opcode.base_opcode() {
		0b000_00_000...0b000_00_111 {
			// left shift
			c.thumb_shift(bus, 0, opcode.offset(), opcode.rs(), opcode.rd())
		}
		0b000_01_000...0b000_01_111 {
			// logic right shift
			c.thumb_shift(bus, 1, opcode.offset(), opcode.rs(), opcode.rd())
		}
		0b000_10_000...0b000_10_111 {
			// arithmetic right shift
			c.thumb_shift(bus, 2, opcode.offset(), opcode.rs(), opcode.rd())
		}
		0b000_11_00_0, 0b000_11_00_1 {
			// add registers
			c.thumb_add(bus, 0, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b000_11_01_0, 0b000_11_01_1 {
			// sub registers
			c.thumb_add(bus, 1, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b000_11_10_0, 0b000_11_10_1 {
			// add register and imm
			c.thumb_add(bus, 2, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b000_11_11_0, 0b000_11_11_1 {
			// sub register and imm
			c.thumb_add(bus, 3, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b001_00_000...0b001_00_111 {
			// mov imm
			c.thumb_arith_imm(bus, 0, opcode.rd8(), u8(opcode))
		}
		0b001_01_000...0b001_01_111 {
			// cmp register and imm
			c.thumb_arith_imm(bus, 1, opcode.rd8(), u8(opcode))
		}
		0b001_10_000...0b001_10_111 {
			// add imm to register
			c.thumb_arith_imm(bus, 2, opcode.rd8(), u8(opcode))
		}
		0b001_11_000...0b001_11_111 {
			// sub imm to register
			c.thumb_arith_imm(bus, 3, opcode.rd8(), u8(opcode))
		}
		0b010000_00...0b010000_11 {
			// alu op
			op := u8(opcode >> 6) & 0xF
			match op {
				0x0, 0x1, 0x8, 0xC, 0xE, 0xF {
					c.thumb_arith_logic(bus, op, opcode.rs(), opcode.rd())
				}
				0x2, 0x3, 0x4, 0x7 {
					c.thumb_arith_shift(bus, op, opcode.rs(), opcode.rd())
				}
				0x5, 0x6, 0x9, 0xA, 0xB {
					c.thumb_arith_add(bus, op, opcode.rs(), opcode.rd())
				}
				else {
					c.thumb_mul(bus, op, opcode.rs(), opcode.rd())
				}
			}
		}
		0b010001_00 {
			// add register to register
			c.thumb_hi_reg(bus, 0, opcode.bit(7), opcode.bit(6), opcode.rs(), opcode.rd())
		}
		0b010001_01 {
			// cmp registers
			c.thumb_hi_reg(bus, 1, opcode.bit(7), opcode.bit(6), opcode.rs(), opcode.rd())
		}
		0b010001_10 {
			// mov register to register
			c.thumb_hi_reg(bus, 2, opcode.bit(7), opcode.bit(6), opcode.rs(), opcode.rd())
		}
		0b010001_11 {
			// jump
			c.thumb_hi_reg(bus, 3, opcode.bit(7), opcode.bit(6), opcode.rs(), opcode.rd())
		}
		0b01001_000...0b01001_111 {
			// load pc relative
			c.thumb_ldr(bus, opcode.rd8(), u8(opcode))
		}
		0b0101_00_0_0, 0b0101_00_0_1 {
			// str
			c.thumb_str_reg_offset(mut bus, 0xFFFF_FFFF, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b0101_00_1_0, 0b0101_00_1_1 {
			// strh
			c.thumb_str_reg_offset(mut bus, 0xFFFF, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b0101_01_0_0, 0b0101_01_0_1 {
			// strb
			c.thumb_str_reg_offset(mut bus, 0xFF, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b0101_10_0_0, 0b0101_10_0_1 {
			// ldr
			c.thumb_ldr_reg_offset(bus, 0xFFFF_FFFF, false, opcode.ro(), opcode.rs(),
				opcode.rd())
		}
		0b0101_10_1_0, 0b0101_10_1_1 {
			// ldrh
			c.thumb_ldr_reg_offset(bus, 0xFFFF, false, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b0101_11_0_0, 0b0101_11_0_1 {
			// ldrb
			c.thumb_ldr_reg_offset(bus, 0xFF, false, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b0101_11_1_0, 0b0101_11_1_1 {
			// ldsh
			c.thumb_ldr_reg_offset(bus, 0xFFFF, true, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b0101_01_1_0, 0b0101_01_1_1 {
			// ldsb
			c.thumb_ldr_reg_offset(bus, 0xFF, true, opcode.ro(), opcode.rs(), opcode.rd())
		}
		0b011_00_000...0b011_00_111 {
			// str with imm offset
			c.thumb_str_imm_offset(mut bus, 0xFFFF_FFFF, (u8(opcode >> 6) & 0x1F) << 2,
				opcode.rs(), opcode.rd())
		}
		0b011_01_000...0b011_01_111 {
			// ldr with imm offset
			c.thumb_ldr_imm_offset(bus, 0xFFFF_FFFF, (u8(opcode >> 6) & 0x1F) << 2, opcode.rs(),
				opcode.rd())
		}
		0b011_10_000...0b011_10_111 {
			// strb with imm offset
			c.thumb_str_imm_offset(mut bus, 0xFF, u8(opcode >> 6) & 0x1F, opcode.rs(),
				opcode.rd())
		}
		0b011_11_000...0b011_11_111 {
			// ldrb with imm offset
			c.thumb_ldr_imm_offset(bus, 0xFF, u8(opcode >> 6) & 0x1F, opcode.rs(), opcode.rd())
		}
		0b1000_0_000...0b1000_0_111 {
			// strh with imm offset
			c.thumb_str_imm_offset(mut bus, 0xFFFF, (u8(opcode >> 6) & 0x1F) << 1, opcode.rs(),
				opcode.rd())
		}
		0b1000_1_000...0b1000_1_111 {
			// ldrh with imm offset
			c.thumb_ldr_imm_offset(bus, 0xFFFF, (u8(opcode >> 6) & 0x1F) << 1, opcode.rs(),
				opcode.rd())
		}
		0b1001_0_000...0b1001_0_111 {
			// str sp relative
			c.thumb_str_sp_relative(mut bus, opcode.rd8(), u16(u8(opcode)) << 2)
		}
		0b1001_1_000...0b1001_1_111 {
			// ldr sp relative
			c.thumb_ldr_sp_relative(bus, opcode.rd8(), u16(u8(opcode)) << 2)
		}
		0b1010_0_000...0b1010_0_111 {
			// load address from pc
			c.thumb_load_pc_address(bus, opcode.rd8(), u16(u8(opcode)) << 2)
		}
		0b1010_1_000...0b1010_1_111 {
			// load address from sp
			c.thumb_load_sp_address(bus, opcode.rd8(), u16(u8(opcode)) << 2)
		}
		0b10110000 {
			// add offset to sp
			c.thumb_add_sp(bus, opcode.bit(7), (u16(opcode) & 0x7F) << 2)
		}
		0b1011_0_10_0, 0b1011_0_10_1 {
			// push
			c.thumb_push(mut bus, opcode.bit(8), u8(opcode))
		}
		0b1011_1_10_0, 0b1011_1_10_1 {
			// pop
			c.thumb_pop(bus, opcode.bit(8), u8(opcode))
		}
		0b1100_0_000...0b1100_0_111 {
			// stmia
			c.thumb_stmia(mut bus, opcode.rd8(), u8(opcode))
		}
		0b1100_1_000...0b1100_1_111 {
			// ldmia
			c.thumb_ldmia(bus, opcode.rd8(), u8(opcode))
		}
		0b1101_0000...0b1101_1101 {
			// cond branch
			c.thumb_b(bus, u8(opcode >> 8) & 0xF, u32(i32(i8(opcode))) << 1)
		}
		0b1101_1111 {
			// swi
			c.thumb_swi(bus)
		}
		0b11100_000...0b11100_111 {
			// b label
			c.thumb_b(bus, 0xE, u32(i32(i16(opcode << 5)) >> 4))
		}
		0b11110_000...0b11110_111 {
			// load lr
			c.thumb_load_lr_high(bus, u16(opcode) & 0x7FF)
		}
		0b11111_000...0b11111_111 {
			// bl label
			c.thumb_bl(bus, u16(opcode) & 0x7FF)
		}
		else {}
	}
}
