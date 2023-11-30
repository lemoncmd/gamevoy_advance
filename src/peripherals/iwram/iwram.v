module iwram

pub struct IWram {
mut:
	ram [0x2000]u32
}

pub fn IWram.new() IWram {
	return IWram{}
}

pub fn (e &IWram) read(addr u32) u32 {
	return e.ram[(addr >> 2) & 0x1FFF] >> ((addr & 3) << 3)
}

pub fn (mut e IWram) write(addr u32, val u32, size u32) {
	base_addr := (addr >> 2) & 0x1FFF
	shift := (addr & 3) << 3
	e.ram[base_addr] &= ~(size << shift)
	e.ram[base_addr] |= val << shift
}
