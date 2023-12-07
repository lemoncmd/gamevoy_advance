module cartridge

pub struct Cartridge {
	rom []u8
mut:
	ram [0x10000]u8
}

pub fn Cartridge.new(rom_ []u8) Cartridge {
	mut rom := rom_.clone()
	header := unsafe { *(&CartridgeHeader(&rom[0])) }
	header.check_sum()

	title := unsafe { tos_clone(&header.game_title[0]) }
	region := match header.game_code[3] {
		`J` { 'Japan' }
		`F` { 'France' }
		`S` { 'Spain' }
		`E` { 'America' }
		`D` { 'Germany' }
		`I` { 'Italy' }
		else { 'Europe, etc' }
	}

	println('cartridge info { title: ${title}, region: ${region}, rom_size: ${rom.len} B }')
	for _ in 0 .. 8 {
		rom << 0
	}
	return Cartridge{
		rom: rom
	}
}

pub fn (c &Cartridge) read(addr u32) u32 {
	return match addr >> 24 {
		0x8...0xD {
			u32(c.rom[addr & 0x01FF_FFFF]) | u32(c.rom[(addr + 1) & 0x01FF_FFFF]) << 8 | u32(c.rom[(
				addr + 2) & 0x01FF_FFFF]) << 16 | u32(c.rom[(addr + 3) & 0x01FF_FFFF]) << 24
		}
		0xE, 0xF {
			val := u32(c.ram[addr & 0xFFFF])
			val | val << 8 | val << 16 | val << 24
		}
		else {
			panic('unexpected address for cartridge: ${addr:08x}')
		}
	}
}

pub fn (mut c Cartridge) write(addr u32, val u32, size u32) {
	if addr >> 24 in [0xE, 0xF] {
		c.ram[addr & 0xFFFF] = u8(match size {
			0xFF { val }
			0xFFFF { val >> ((addr & 1) << 3) }
			else { val >> ((addr & 3) << 3) }
		})
	}
}
