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
pub mut:
	ppu ppu.Ppu
}

pub fn Peripherals.new(b Bios) Peripherals {
	return Peripherals{
		bios: b
		ewram: EWram.new()
		iwram: IWram.new()
		ppu: Ppu.new()
	}
}

pub fn (p &Peripherals) read(addr u32) u32 {
	// println('read: ${addr:08x}')
	return match addr {
		0x0000_0000...0x0000_3FFF {
			p.bios.read(addr)
		}
		// TODO prefetched inst
		0x0000_4000...0x0001_FFFF {
			0
		}
		0x0400_0000...0x0400_005F {
			p.ppu.read(addr)
		}
		0x0400_0060...0x0400_00AB {
			0
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
				else { panic('unexpected address for peripherals: ${addr:08x}') }
			}
		}
	}
}

pub fn (mut p Peripherals) write(addr u32, val u32, size u32) {
	// println('write: ${addr:08x} ${val:08x}')
	match addr {
		0x0400_0000...0x0400_005F {
			p.ppu.write(addr, val, size)
		}
		0x0400_0060...0x0400_03FE {
			println('unsupported write: ${addr:08x}')
		}
		// ???
		0x0400_8000, 0x0400_8020 {
			println('unsupported write: ${addr:08x}')
		}
		else {
			match addr >> 24 {
				0x02 { p.ewram.write(addr, val, size) }
				0x03 { p.iwram.write(addr, val, size) }
				0x05...0x07 { p.ppu.write(addr, val, size) }
				else { panic('unexpected address for peripherals: ${addr:08x}') }
			}
		}
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
