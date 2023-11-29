module cpu

import peripherals { Peripherals }

fn (mut c Cpu) decode(mut bus Peripherals) {
	if c.regs.cpsr.get_flag(.t) {
		c.decode_thumb()
		return
	}
	opcode := Opcode(c.ctx.opcodes[0])
	base_opcode := opcode.base_opcode()
	// don't forget nds supported ops
	match base_opcode {
		// data processing / psr transfer
		0b00010_00_0_0000 {
			// mrs cpsr
			panic('unimplemented instruction: ${opcode:08x}')
		}
		0b00010_01_0_0000, 0b00110_01_0_0000...0b00110_01_0_1111 {
			// msr cpsr
			c.msr_cpsr(bus, opcode.cond(), opcode.bit(19), opcode.bit(16), opcode.rd(),
				c.msr_value(opcode))
			return
		}
		0b00010_10_0_0000 {
			// mrs spsr
			panic('unimplemented instruction: ${opcode:08x}')
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
			panic('unimplemented instruction: ${opcode:08x}')
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
			panic('unimplemented instruction: ${opcode:08x}')
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
			panic('unimplemented instruction: ${opcode:08x}')
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
			panic('unimplemented instruction: ${opcode:08x}')
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

fn (mut c Cpu) decode_thumb() {
	opcode := ThumbOpcode(u16(c.ctx.opcodes[0]))
	match opcode.base_opcode() {
		0b000_00_000...0b000_00_111 {
			// left shift
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b000_01_000...0b000_01_111 {
			// logic right shift
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b000_10_000...0b000_10_111 {
			// arithmetic right shift
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b000_11_00_0, 0b000_11_00_1 {
			// add registers
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b000_11_01_0, 0b000_11_01_1 {
			// sub registers
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b000_11_10_0, 0b000_11_10_1 {
			// add register and imm
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b000_11_11_0, 0b000_11_11_1 {
			// sub register and imm
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b001_00_000...0b001_00_111 {
			// mov imm
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b001_01_000...0b001_01_111 {
			// cmp register and imm
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b001_10_000...0b001_10_111 {
			// add imm to register
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b001_11_000...0b001_11_111 {
			// sub imm to register
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b010000_00...0b010000_11 {
			// alu op
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b010001_00 {
			// add register to register
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b010001_01 {
			// cmp registers
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b010001_10 {
			// mov register to register
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b010001_11 {
			// jump
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b01001_000...0b01001_111 {
			// load pc relative
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b0101_00_0_0, 0b0101_00_0_1 {
			// str
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b0101_00_1_0, 0b0101_00_1_1 {
			// strh
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b0101_01_0_0, 0b0101_01_0_1 {
			// strb
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b0101_01_1_0, 0b0101_01_1_1 {
			// ldsb
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b0101_10_0_0, 0b0101_10_0_1 {
			// ldr
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b0101_10_1_0, 0b0101_10_1_1 {
			// ldrh
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b0101_11_0_0, 0b0101_11_0_1 {
			// ldrb
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b0101_11_1_0, 0b0101_11_1_1 {
			// ldsh
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b011_00_000...0b011_00_111 {
			// str with imm offset
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b011_01_000...0b011_01_111 {
			// ldr with imm offset
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b011_10_000...0b011_10_111 {
			// strb with imm offset
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b011_11_000...0b011_11_111 {
			// ldrb with imm offset
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1000_0_000...0b1000_0_111 {
			// strh with imm offset
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1000_1_000...0b1000_1_111 {
			// ldrh with imm offset
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1001_0_000...0b1001_0_111 {
			// str sp relative
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1001_1_000...0b1001_1_111 {
			// ldr sp relative
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1010_0_000...0b1010_0_111 {
			// load address from pc
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1010_1_000...0b1010_1_111 {
			// load address from sp
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b10110000 {
			// add offset to sp
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1011_0_10_0, 0b1011_0_10_1 {
			// push
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1011_1_10_0, 0b1011_1_10_1 {
			// pop
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1100_0_000...0b1100_0_111 {
			// stmia
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1100_1_000...0b1100_1_111 {
			// ldmia
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1101_0000...0b1101_1101 {
			// cond branch
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b1101_1111 {
			// swi
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b11100_000...0b11100_111 {
			// b label
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b11101_000...0b11101_111 {
			// blx label
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b11110_000...0b11110_111 {
			// load lr
			panic('unimplemented instruction: ${opcode:16b}')
		}
		0b11111_000...0b11111_111 {
			// bl label
			panic('unimplemented instruction: ${opcode:16b}')
		}
		else {}
	}
}
