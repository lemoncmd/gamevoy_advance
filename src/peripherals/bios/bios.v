module bios

pub struct Bios {
	rom [0x1000]u32
}

pub fn Bios.new(rom []u32) Bios {
	assert rom.len == 0x1000
	return Bios{
		rom: [0x1000]u32{init: rom[index]}
	}
}

pub fn (b &Bios) read(addr u32) u32 {
	return b.rom[addr >> 2] >> (addr & 3)
}
