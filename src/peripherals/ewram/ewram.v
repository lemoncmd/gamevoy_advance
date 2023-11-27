module ewram

pub struct EWram {
mut:
	ram [0x10000]u32
}

pub fn EWram.new() EWram {
	return EWram{}
}

pub fn (e &EWram) read(addr u32) u32 {
	return e.ram[(addr >> 2) & 0xFFFF] >> ((addr & 3) << 3)
}

pub fn (mut e EWram) write(addr u32, val u32, size u32) {
	base_addr := (addr >> 2) & 0xFFFF
	shift := (addr & 3) << 3
	e.ram[base_addr] &= ~(size << shift)
	e.ram[base_addr] |= val << shift
}
