module cpu

type Opcode = u32

fn (o Opcode) base_opcode() u16 {
	return u16(((o >> 16) & 0xFF0) | ((o >> 4) & 0xF))
}

fn (o Opcode) cond() u8 {
	return u8(o >> 28)
}

fn (o Opcode) rn() u8 {
	return u8(o >> 16) & 0xF
}

fn (o Opcode) rd() u8 {
	return u8(o >> 12) & 0xF
}

fn (o Opcode) rs() u8 {
	return u8(o >> 8) & 0xF
}

fn (o Opcode) rm() u8 {
	return u8(o) & 0xF
}

type ThumbOpcode = u16

fn (o ThumbOpcode) base_opcode() u8 {
	return u8(o >> 8)
}
