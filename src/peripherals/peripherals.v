module peripherals

import peripherals.bios { Bios }
import peripherals.ewram { EWram }
import peripherals.iwram { IWram }
import peripherals.ppu { Ppu }

pub struct Peripherals {
	bios bios.Bios
mut:
	ewram ewram.EWram
	iwram iwram.IWram
	ppu   ppu.Ppu
}

pub fn (p &Peripherals) read(addr u32) u32 {
	return match addr {
		0x0000_0000...0x0000_3FFF {
			p.bios.read(addr)
		}
		/*
		0x0400_0000...0x0400_03FE { io }
		0x0800_0000...0x0FFF_FFFF { p.cartridge.read(addr) }
		*/
		else {
			// reduce range of match case to reduce V compilation speed
			match addr >> 24 {
				0x02 { p.ewram.read(addr) }
				0x03 { p.iwram.read(addr) }
				0x05...0x07 { p.ppu.read(addr) }
				// must be prefetched code
				else { 0 }
			}
		}
	}
}

pub fn (mut p Peripherals) write(addr u32, val u32, size u32) {
	match addr >> 24 {
		0x02 { p.ewram.write(addr, val, size) }
		0x03 { p.iwram.write(addr, val, size) }
		0x05...0x07 { p.ppu.write(addr, val, size) }
		else {}
	}
}

pub fn (p &Peripherals) cycle(addr u32, size u32, is_sequencial bool) u8 {
	return match addr >> 24 {
		0x02 {
			if size > 0xFFFF {
				u8(6)
			} else {
				3
			}
		}
		0x05, 0x06 {
			u8(p.ppu.vram_in_access) + if size > 0xFFFF {
				2
			} else {
				1
			}
		}
		0x07 {
			u8(p.ppu.vram_in_access) + 1
		}
		else {
			1
		}
	}
}
