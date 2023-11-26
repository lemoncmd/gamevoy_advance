module cpu

type Opcode = u32

fn (o Opcode) base_opcode() u16 {
	return u16(((o >> 16) & 0xFF0) | ((o >> 4) & 0xF))
}

fn (o Opcode) cond() u8 {
	return u8(o >> 28)
}

fn (o Opcode) i() bool {
	return o & (1 << 25) > 0
}

fn (o Opcode) p() bool {
	return o & (1 << 24) > 0
}

fn (o Opcode) l_br() bool {
	return o & (1 << 24) > 0
}

fn (o Opcode) u() bool {
	return o & (1 << 23) > 0
}

fn (o Opcode) u_ml() bool {
	return o & (1 << 22) > 0
}

fn (o Opcode) b() bool {
	return o & (1 << 22) > 0
}

fn (o Opcode) s_bdt() bool {
	return o & (1 << 22) > 0
}

fn (o Opcode) n() bool {
	return o & (1 << 22) > 0
}

fn (o Opcode) a() bool {
	return o & (1 << 21) > 0
}

fn (o Opcode) w() bool {
	return o & (1 << 21) > 0
}

fn (o Opcode) s() bool {
	return o & (1 << 20) > 0
}

fn (o Opcode) l() bool {
	return o & (1 << 20) > 0
}

fn (o Opcode) s_htd() bool {
	return o & (1 << 6) > 0
}

fn (o Opcode) h() bool {
	return o & (1 << 5) > 0
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
