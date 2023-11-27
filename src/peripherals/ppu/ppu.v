module ppu

pub struct Ppu {
mut:
	palette [0x200]u16
	vram    [0xC000]u16
	oam     [0x100]u32
}

pub fn (p &Ppu) read(addr u32) u32 {
	return match addr >> 24 {
		0x05 {
			low := p.palette[(addr >> 1) & 0x1FF]
			high := p.palette[((addr >> 1) & 0x1FF) + 1] or { 0 }
			((u32(high) << 16) | u32(low)) >> ((addr & 3) << 3)
		}
		0x06 {
			base_addr := if addr & 0x1FFFF >= 0x18000 {
				addr & 0x1FFFF - 0x8000
			} else {
				addr & 0x1FFFF
			}
			low := p.vram[base_addr >> 1]
			high := p.vram[(base_addr >> 1) + 1] or { 0 }
			((u32(high) << 16) | u32(low)) >> ((base_addr & 3) << 3)
		}
		0x07 {
			p.oam[(addr >> 2) & 0xFF] >> ((addr & 3) << 3)
		}
		else {
			0
		}
	}
}

pub fn (mut p Ppu) write(addr u32, val u32, size u32) {
	match addr >> 24 {
		0x05 {
			base_addr := (addr >> 1) & 0x1FF
			if size > 0xFFFF {
				p.palette[base_addr] = u16(val)
				p.palette[base_addr + 1] = u16(val >> 16)
			} else {
				shift := (addr & 1) << 3
				p.palette[base_addr] &= ~(u16(size) << shift)
				p.palette[base_addr] |= u16(val) << shift
			}
		}
		0x06 {
			base_addr := if addr & 0x1FFFF >= 0x18000 {
				addr & 0x1FFFF - 0x8000
			} else {
				addr & 0x1FFFF
			}
			if size > 0xFFFF {
				p.vram[base_addr] = u16(val)
				p.vram[base_addr + 1] = u16(val >> 16)
			} else {
				shift := (addr & 1) << 3
				p.vram[base_addr] &= ~(u16(size) << shift)
				p.vram[base_addr] |= u16(val) << shift
			}
		}
		0x07 {
			base_addr := (addr >> 2) & 0xFF
			shift := (addr & 3) << 3
			p.oam[base_addr] &= ~(size << shift)
			p.oam[base_addr] |= val << shift
		}
		else {}
	}
}
