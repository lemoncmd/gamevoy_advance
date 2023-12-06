module ppu

import cpu.interrupts { Interrupts }

pub struct Ppu {
mut:
	cycle    u16
	dispcnt  u16
	dispstat u16
	vcount   u16
	bg0cnt   u16
	bg1cnt   u16
	bg2cnt   u16
	bg3cnt   u16
	bg0hofs  u16
	bg0vofs  u16
	bg1hofs  u16
	bg1vofs  u16
	bg2hofs  u16
	bg2vofs  u16
	bg3hofs  u16
	bg3vofs  u16
	bg2pa    u16
	bg2pb    u16
	bg2pc    u16
	bg2pd    u16
	bg2x     u32
	bg2y     u32
	bg3pa    u16
	bg3pb    u16
	bg3pc    u16
	bg3pd    u16
	bg3x     u32
	bg3y     u32
	win0h    u16
	win1h    u16
	win0v    u16
	win1v    u16
	winin    u16
	winout   u16
	mosaic   u16
	bldcnt   u16
	bldalpha u16
	bldy     u16
	palette  [0x200]u16
	vram     [0xC000]u16
	oam      [0x100]u32
	buffer   [153600]u8
pub mut:
	vram_in_access bool
}

pub fn Ppu.new() Ppu {
	return Ppu{}
}

pub fn (p &Ppu) read(addr u32) u32 {
	return u32(p.read_16(addr)) | (u32(p.read_16(addr + 2)) << 16)
}

fn (p &Ppu) read_16(addr u32) u16 {
	return match addr >> 24 {
		0x04 {
			match addr & 0xFFFFFE {
				0x00 { p.dispcnt }
				0x04 { p.dispstat }
				0x06 { p.vcount }
				0x08 { p.bg0cnt }
				0x0A { p.bg1cnt }
				0x0C { p.bg2cnt }
				0x0E { p.bg3cnt }
				0x48 { p.winin }
				0x4A { p.winout }
				0x50 { p.bldcnt }
				0x52 { p.bldalpha }
				0x54 { p.bldy }
				else { 0 }
			} >> ((addr & 1) << 3)
		}
		0x05 {
			p.palette[(addr >> 1) & 0x1FF] >> ((addr & 1) << 3)
		}
		0x06 {
			base_addr := if addr & 0x1FFFF >= 0x18000 {
				addr & 0x1FFFF - 0x8000
			} else {
				addr & 0x1FFFF
			}
			p.vram[base_addr >> 1] >> ((base_addr & 1) << 3)
		}
		0x07 {
			u16(p.oam[(addr >> 2) & 0xFF] >> ((addr & 3) << 3))
		}
		else {
			0
		}
	}
}

pub fn (mut p Ppu) write(addr u32, val u32, size u32) {
	if size == 0xFFFF_FFFF {
		p.write_16(addr, u16(val), 0xFFFF)
		p.write_16(addr + 2, u16(val >> 16), 0xFFFF)
	} else {
		p.write_16(addr, u16(val), u16(size))
	}
}

fn (mut p Ppu) write_16(addr u32, val u16, size u16) {
	match addr >> 24 {
		0x04 {
			shift := (addr & 1) << 3
			match addr & 0xFFFFFE {
				0x00 {
					p.dispcnt &= ~(size << shift)
					p.dispcnt |= val << shift
				}
				0x04 {
					p.dispstat &= ~(size << shift)
					p.dispstat |= val << shift
				}
				0x08 {
					p.bg0cnt &= ~(size << shift)
					p.bg0cnt |= val << shift
				}
				0x0A {
					p.bg1cnt &= ~(size << shift)
					p.bg1cnt |= val << shift
				}
				0x0C {
					p.bg2cnt &= ~(size << shift)
					p.bg2cnt |= val << shift
				}
				0x0E {
					p.bg3cnt &= ~(size << shift)
					p.bg3cnt |= val << shift
				}
				0x10 {
					p.bg0hofs &= ~(size << shift)
					p.bg0hofs |= val << shift
				}
				0x12 {
					p.bg0vofs &= ~(size << shift)
					p.bg0vofs |= val << shift
				}
				0x14 {
					p.bg1hofs &= ~(size << shift)
					p.bg1hofs |= val << shift
				}
				0x16 {
					p.bg1vofs &= ~(size << shift)
					p.bg1vofs |= val << shift
				}
				0x18 {
					p.bg2hofs &= ~(size << shift)
					p.bg2hofs |= val << shift
				}
				0x1A {
					p.bg2vofs &= ~(size << shift)
					p.bg2vofs |= val << shift
				}
				0x1C {
					p.bg3hofs &= ~(size << shift)
					p.bg3hofs |= val << shift
				}
				0x1E {
					p.bg3vofs &= ~(size << shift)
					p.bg3vofs |= val << shift
				}
				0x20 {
					p.bg2pa &= ~(size << shift)
					p.bg2pa |= val << shift
				}
				0x22 {
					p.bg2pb &= ~(size << shift)
					p.bg2pb |= val << shift
				}
				0x24 {
					p.bg2pc &= ~(size << shift)
					p.bg2pc |= val << shift
				}
				0x26 {
					p.bg2pd &= ~(size << shift)
					p.bg2pd |= val << shift
				}
				0x28 {
					p.bg2x &= ~(u32(size) << shift)
					p.bg2x |= u32(val) << shift
				}
				0x2A {
					p.bg2x &= ~(u32(size) << (shift + 16))
					p.bg2x |= u32(val) << (shift + 16)
				}
				0x2C {
					p.bg2y &= ~(u32(size) << shift)
					p.bg2y |= u32(val) << shift
				}
				0x2E {
					p.bg2y &= ~(u32(size) << (shift + 16))
					p.bg2y |= u32(val) << (shift + 16)
				}
				0x30 {
					p.bg3pa &= ~(size << shift)
					p.bg3pa |= val << shift
				}
				0x32 {
					p.bg3pb &= ~(size << shift)
					p.bg3pb |= val << shift
				}
				0x34 {
					p.bg3pc &= ~(size << shift)
					p.bg3pc |= val << shift
				}
				0x36 {
					p.bg3pd &= ~(size << shift)
					p.bg3pd |= val << shift
				}
				0x38 {
					p.bg3x &= ~(u32(size) << shift)
					p.bg3x |= u32(val) << shift
				}
				0x3A {
					p.bg3x &= ~(u32(size) << (shift + 16))
					p.bg3x |= u32(val) << (shift + 16)
				}
				0x3C {
					p.bg3y &= ~(u32(size) << shift)
					p.bg3y |= u32(val) << shift
				}
				0x3E {
					p.bg3y &= ~(u32(size) << (shift + 16))
					p.bg3y |= u32(val) << (shift + 16)
				}
				0x40 {
					p.win0h &= ~(size << shift)
					p.win0h |= val << shift
				}
				0x42 {
					p.win1h &= ~(size << shift)
					p.win1h |= val << shift
				}
				0x44 {
					p.win0v &= ~(size << shift)
					p.win0v |= val << shift
				}
				0x46 {
					p.win1v &= ~(size << shift)
					p.win1v |= val << shift
				}
				0x48 {
					p.winin &= ~(size << shift)
					p.winin |= val << shift
				}
				0x4A {
					p.winout &= ~(size << shift)
					p.winout |= val << shift
				}
				0x4C {
					p.mosaic &= ~(size << shift)
					p.mosaic |= val << shift
				}
				0x50 {
					p.bldcnt &= ~(size << shift)
					p.bldcnt |= val << shift
				}
				0x52 {
					p.bldalpha &= ~(size << shift)
					p.bldalpha |= val << shift
				}
				0x54 {
					p.bldy &= ~(size << shift)
					p.bldy |= val << shift
				}
				else {}
			}
		}
		0x05 {
			base_addr := (addr >> 1) & 0x1FF
			p.palette[base_addr] = if size == 0xFFFF {
				val
			} else {
				u16(val) | u16(val << 8)
			}
		}
		0x06 {
			base_addr := if addr & 0x1FFFF >= 0x18000 {
				addr & 0x1FFFF - 0x8000
			} else {
				addr & 0x1FFFF
			}
			if size == 0xFFFF {
				p.vram[base_addr >> 1] = u16(val)
			} else {
				// TODO 0x14000 in Bitmap mode
				if base_addr < 0x10000 {
					p.vram[base_addr >> 1] = u16(val) | u16(val << 8)
				}
			}
		}
		0x07 {
			if size == 0xFF {
				return
			}
			base_addr := (addr >> 2) & 0xFF
			shift := (addr & 3) << 3
			p.oam[base_addr] &= ~(size << shift)
			p.oam[base_addr] |= val << shift
		}
		else {}
	}
}

fn (mut p Ppu) check_lyc_eq_ly(mut ints Interrupts) {
	lyc := p.dispstat >> 8
	ly := p.vcount & 0xFF
	mut dispstat := DispStat.from(p.dispstat)
	if lyc == ly {
		dispstat.set(.vcounter)
		if dispstat.has(.vcounter_int_enable) {
			ints.irq(.lyc_eq_ly)
		}
	} else {
		dispstat.clear(.vcounter)
	}
	p.dispstat = u16(dispstat)
}

pub fn (mut p Ppu) emulate_cycle(mut ints Interrupts) bool {
	mut dispstat := DispStat.from(p.dispstat)
	defer {
		p.dispstat = u16(dispstat)
	}
	p.cycle++
	match p.cycle {
		960 {
			if p.vcount < 160 {
				// hblank
				p.render()
				dispstat.set(.hblank)
				if dispstat.has(.hblank_int_enable) {
					ints.irq(.hblank)
				}
			}
		}
		1232 {
			p.cycle = 0
			p.vcount++
			match p.vcount {
				0...159 {
					dispstat.clear(.hblank)
				}
				160 {
					// vblank
					dispstat.set(.vblank)
					if dispstat.has(.vblank_int_enable) {
						ints.irq(.vblank)
					}
				}
				228 {
					p.vcount = 0
					dispstat.clear(.vblank)
					return true
				}
				else {}
			}
			p.check_lyc_eq_ly(mut ints)
		}
		else {}
	}
	return false
}

fn (mut p Ppu) render() {
	p.fill_with_backdrop()
	mut winflags := [240]WindowFlag{init: unsafe { WindowFlag(u8(p.winout)) }}
	mut priorities := [240]u8{init: 3}
	p.calculate_window(mut winflags)
	p.render_bg(winflags, mut priorities)
	p.render_obj(winflags, priorities)
}

pub fn (p &Ppu) in_vblank() bool {
	return DispStat.from(p.dispstat).has(.vblank)
}

pub fn (p &Ppu) in_hblank() bool {
	return DispStat.from(p.dispstat).has(.hblank)
}

pub fn (p &Ppu) pixel_buffer() []u8 {
	return []u8{len: 153600, init: p.buffer[index]}
}
