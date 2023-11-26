module cpu

fn (mut c Cpu) decode() {
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
		}
		0b00010_01_0_0000 {
			// msr cpsr register
		}
		0b00010_10_0_0000 {
			// mrs spsr
		}
		0b00010_11_0_0000 {
			// msr spsr register
		}
		0b00110_01_0_0000...0b00110_01_0_1111 {
			// msr cpsr imm
		}
		0b00110_11_0_0000...0b00110_11_0_1111 {
			// msr spsr imm
		}
		// swap
		0b00010_0_00_1001 {
			// swp
		}
		0b00010_1_00_1001 {
			// swpb
		}
		// multiply
		0b000_0000_0_1001, 0b000_0000_1_1001 {
			// mul
		}
		0b000_0001_0_1001, 0b000_0001_1_1001 {
			// mla
		}
		0b000_0100_0_1001, 0b000_0100_1_1001 {
			// umull
		}
		0b000_0101_0_1001, 0b000_0101_1_1001 {
			// umlal
		}
		0b000_0110_0_1001, 0b000_0110_1_1001 {
			// smull
		}
		0b000_0111_0_1001, 0b000_0111_1_1001 {
			// smlal
		}
		// bx
		0b0001_0010_0001 {
			// bx
		}
		// data transfer
		0b010_0_0000_0000...0b010_1_1111_1111 {
			// single data transfer
		}
		0b100_0_0000_0000...0b100_1_1111_1111 {
			// block data transfer
		}
		// branch
		0b101_0_0000_0000...0b101_0_1111_1111 {
			// b
		}
		0b101_1_0000_0000...0b101_1_1111_1111 {
			// bl
		}
		0b1111_0000_0000...0b1111_1111_1111 {
			// swx
		}
		else {
			if base_opcode & 0xE00 == 0 && base_opcode & 0b1001 == 0b1001 && base_opcode & 0b110 > 0 {
				// half word
			}
		}
	}
	// undefined exception
}

fn (mut c Cpu) decode_thumb() {
	opcode := ThumbOpcode(u16(c.ctx.opcodes[0] >> (8 * u8(c.regs.r15 & 2 > 0))))
	match opcode.base_opcode() {
		0b000_00_000...0b000_00_111 {
			// left shift
		}
		0b000_01_000...0b000_01_111 {
			// logic right shift
		}
		0b000_10_000...0b000_10_111 {
			// arithmetic right shift
		}
		0b000_11_00_0, 0b000_11_00_1 {
			// add registers
		}
		0b000_11_01_0, 0b000_11_01_1 {
			// sub registers
		}
		0b000_11_10_0, 0b000_11_10_1 {
			// add register and imm
		}
		0b000_11_11_0, 0b000_11_11_1 {
			// sub register and imm
		}
		0b001_00_000...0b001_00_111 {
			// mov imm
		}
		0b001_01_000...0b001_01_111 {
			// cmp register and imm
		}
		0b001_10_000...0b001_10_111 {
			// add imm to register
		}
		0b001_11_000...0b001_11_111 {
			// sub imm to register
		}
		0b010000_00...0b010000_11 {
			// alu op
		}
		0b010001_00 {
			// add register to register
		}
		0b010001_01 {
			// cmp registers
		}
		0b010001_10 {
			// mov register to register
		}
		0b010001_11 {
			// jump
		}
		0b01001_000...0b01001_111 {
			// load pc relative
		}
		0b0101_00_0_0, 0b0101_00_0_1 {
			// str
		}
		0b0101_00_1_0, 0b0101_00_1_1 {
			// strh
		}
		0b0101_01_0_0, 0b0101_01_0_1 {
			// strb
		}
		0b0101_01_1_0, 0b0101_01_1_1 {
			// ldsb
		}
		0b0101_10_0_0, 0b0101_10_0_1 {
			// ldr
		}
		0b0101_10_1_0, 0b0101_10_1_1 {
			// ldrh
		}
		0b0101_11_0_0, 0b0101_11_0_1 {
			// ldrb
		}
		0b0101_11_1_0, 0b0101_11_1_1 {
			// ldsh
		}
		0b011_00_000...0b011_00_111 {
			// str with imm offset
		}
		0b011_01_000...0b011_01_111 {
			// ldr with imm offset
		}
		0b011_10_000...0b011_10_111 {
			// strb with imm offset
		}
		0b011_11_000...0b011_11_111 {
			// ldrb with imm offset
		}
		0b1000_0_000...0b1000_0_111 {
			// strh with imm offset
		}
		0b1000_1_000...0b1000_1_111 {
			// ldrh with imm offset
		}
		0b1001_0_000...0b1001_0_111 {
			// str sp relative
		}
		0b1001_1_000...0b1001_1_111 {
			// ldr sp relative
		}
		0b1010_0_000...0b1010_0_111 {
			// load address from pc
		}
		0b1010_1_000...0b1010_1_111 {
			// load address from sp
		}
		0b10110000 {
			// add offset to sp
		}
		0b1011_0_10_0, 0b1011_0_10_1 {
			// push
		}
		0b1011_1_10_0, 0b1011_1_10_1 {
			// pop
		}
		0b1100_0_000...0b1100_0_111 {
			// stmia
		}
		0b1100_1_000...0b1100_1_111 {
			// ldmia
		}
		0b1101_0000...0b1101_1101 {
			// cond branch
		}
		0b1101_1111 {
			// swi
		}
		0b11100_000...0b11100_111 {
			// b label
		}
		0b11101_000...0b11101_111 {
			// blx label
		}
		0b11110_000...0b11110_111 {
			// load lr
		}
		0b11111_000...0b11111_111 {
			// bl label
		}
		else {}
	}
}
