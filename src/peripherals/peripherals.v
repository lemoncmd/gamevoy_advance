module peripherals

import peripherals.bios { Bios }
import peripherals.ewram { EWram }
import peripherals.iwram { IWram }
import peripherals.ppu { Ppu }
import peripherals.timer { Timers }
import peripherals.dma { Dmas }
import peripherals.apu { Apu }
import peripherals.joypad { Joypad }
import peripherals.cartridge { Cartridge }
import cpu.interrupts { Interrupts }

pub struct Peripherals {
	bios bios.Bios
mut:
	ewram     ewram.EWram
	iwram     iwram.IWram
	cartridge cartridge.Cartridge
pub mut:
	ppu    ppu.Ppu
	timers timer.Timers
	dmas   dma.Dmas
	apu    apu.Apu
	joypad joypad.Joypad
}

pub fn Peripherals.new(b Bios, c Cartridge) Peripherals {
	return Peripherals{
		bios: b
		ewram: EWram.new()
		iwram: IWram.new()
		cartridge: c
		ppu: Ppu.new()
		timers: Timers.new()
		dmas: Dmas.new()
		apu: Apu.new()
		joypad: Joypad.new()
	}
}

pub fn (p &Peripherals) read(addr u32, ints &Interrupts) u32 {
	// println('read: ${addr:08x}')
	return match addr {
		0x0000_0000...0x0000_3FFF {
			p.bios.read(addr)
		}
		0x0400_0000...0x0400_005F {
			p.ppu.read(addr)
		}
		0x0400_0060...0x0400_0081 {
			println('unsupported read: ${addr:08x}')
			0
		}
		0x0400_0082 {
			p.apu.read(addr)
		}
		0x0400_0083...0x0400_00AB {
			println('unsupported read: ${addr:08x}')
			0
		}
		0x0400_00B0...0x0400_00DF {
			p.dmas.read(addr)
		}
		0x0400_0100...0x0400_010F {
			p.timers.read(addr)
		}
		0x0400_0130...0x0400_0132 {
			p.joypad.read(addr)
		}
		0x0400_0200...0x0400_020B {
			ints.read(addr)
		}
		/*
		0x0400_0000...0x0400_03FF { io }
		0x0800_0000...0x0FFF_FFFF { p.cartridge.read(addr) }
		*/
		else {
			// reduce range of match case to reduce V compilation speed
			match addr >> 24 {
				0x02 { p.ewram.read(addr) }
				0x03 { p.iwram.read(addr) }
				0x05...0x07 { p.ppu.read(addr) }
				0x08...0x0F { p.cartridge.read(addr) }
				// must be prefetched code
				// else { panic('unexpected address for peripherals: ${addr:08x}') }
				else { 0 }
			}
		}
	}
}

pub fn (mut p Peripherals) write(addr u32, val u32, size u32, mut ints Interrupts) {
	// println('write: ${addr:08x} ${val:08x}')
	match addr {
		0x0400_0000...0x0400_005F {
			p.ppu.write(addr, val, size)
		}
		0x0400_0060...0x0400_0081 {
			println('unsupported write: ${addr:08x}')
		}
		0x0400_0082 {
			p.ppu.write(addr, val, size)
		}
		0x0400_0083...0x0400_00AF {
			println('unsupported write: ${addr:08x}')
		}
		0x0400_00B0...0x0400_00DF {
			p.dmas.write(addr, val, size)
		}
		0x0400_00E0...0x0400_00FF {
			println('unsupported write: ${addr:08x}')
		}
		0x0400_0100...0x0400_010F {
			p.timers.write(addr, val, size)
		}
		0x0400_0110...0x0400_0131 {
			println('unsupported write: ${addr:08x}')
		}
		0x0400_0132 {
			p.joypad.read(addr)
		}
		0x0400_0133...0x0400_01FF {
			println('unsupported write: ${addr:08x}')
		}
		0x0400_0200...0x0400_020B {
			ints.write(addr, val, size)
		}
		0x0400_0300...0x0400_0303 {
			ints.write(addr, val, size)
		}
		else {
			match addr >> 24 {
				0x02 { p.ewram.write(addr, val, size) }
				0x03 { p.iwram.write(addr, val, size) }
				0x05...0x07 { p.ppu.write(addr, val, size) }
				0x08...0x0F { p.cartridge.write(addr, val, size) }
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
