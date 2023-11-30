module bios

pub struct Bios {
	rom [0x1000]u32
}

pub fn Bios.new(rom []u8) Bios {
	assert rom.len == 0x4000
	ret := Bios{}
	unsafe { vmemcpy(&ret.rom[0], &rom[0], sizeof(ret.rom)) }
	return ret
}

pub fn (b &Bios) read(addr u32) u32 {
	return b.rom[addr >> 2] >> ((addr & 3) << 3)
}
