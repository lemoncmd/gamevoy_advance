module dma

import cpu.interrupts { InterruptFlag, Interrupts }

pub struct Dmas {
mut:
	dmas [4]Dma
}

struct Dma {
mut:
	sad         u32
	dad         u32
	cnt_l       u16
	cnt_h       u16
	count       u32
	source      u32
	destination u32
	transfering bool
}

@[flag]
enum DmaCnt as u16 {
	unused0
	unused1
	unused2
	unused3
	unused4
	destination0
	destination1
	source0
	source1
	repeat
	size
	drq
	mode0
	mode1
	irq_enable
	enable
}

fn (d DmaCnt) destination() u16 {
	return (u16(d) >> 5) & 3
}

fn (d DmaCnt) source() u16 {
	return (u16(d) >> 7) & 3
}

fn (d DmaCnt) mode() u16 {
	return (u16(d) >> 12) & 3
}

fn DmaCnt.from(val u16) DmaCnt {
	return unsafe { DmaCnt(val) }
}

pub struct DmaInfo {
pub:
	source      u32
	destination u32
	size        u32
}

pub fn Dmas.new() Dmas {
	return Dmas{}
}

pub fn (d &Dmas) read(addr u32) u32 {
	return match addr & 0xFFFF_FFFC {
		0x0400_00B0 { d.dmas[0].sad }
		0x0400_00B4 { d.dmas[0].dad }
		0x0400_00B8 { u32(d.dmas[0].cnt_l) | u32(d.dmas[0].cnt_h) << 16 }
		0x0400_00BC { d.dmas[1].sad }
		0x0400_00C0 { d.dmas[1].dad }
		0x0400_00C4 { u32(d.dmas[1].cnt_l) | u32(d.dmas[1].cnt_h) << 16 }
		0x0400_00C8 { d.dmas[2].sad }
		0x0400_00CC { d.dmas[2].dad }
		0x0400_00D0 { u32(d.dmas[2].cnt_l) | u32(d.dmas[2].cnt_h) << 16 }
		0x0400_00D4 { d.dmas[3].sad }
		0x0400_00D8 { d.dmas[3].dad }
		0x0400_00DC { u32(d.dmas[3].cnt_l) | u32(d.dmas[3].cnt_h) << 16 }
		else { 0 }
	} >> ((addr & 3) << 3)
}

pub fn (mut d Dmas) write(addr u32, val u32, size u32) {
	shift := (addr & 3) << 3
	println('dma ${addr:08x} ${val:08x} ${size:08x}')
	match addr & 0xFFFF_FFFC {
		0x0400_00B0 {
			d.dmas[0].sad &= ~(size << shift)
			d.dmas[0].sad |= val << shift
		}
		0x0400_00B4 {
			d.dmas[0].dad &= ~(size << shift)
			d.dmas[0].dad |= val << shift
		}
		0x0400_00B8 {
			mut cnt := u32(d.dmas[0].cnt_l) | u32(d.dmas[0].cnt_h) << 16
			disabled := cnt >> 31 == 0
			cnt &= ~(size << shift)
			cnt |= val << shift
			d.dmas[0].cnt_l = u16(cnt)
			d.dmas[0].cnt_h = u16(cnt >> 16)
			if disabled && cnt >> 31 > 0 {
				dma := d.dmas[0]
				d.dmas[0].count = if dma.cnt_l != 0 { dma.cnt_l } else { 0x4000 }
				d.dmas[0].source = dma.sad
				d.dmas[0].destination = dma.dad
			}
		}
		0x0400_00BC {
			d.dmas[1].sad &= ~(size << shift)
			d.dmas[1].sad |= val << shift
		}
		0x0400_00C0 {
			d.dmas[1].dad &= ~(size << shift)
			d.dmas[1].dad |= val << shift
		}
		0x0400_00C4 {
			mut cnt := u32(d.dmas[1].cnt_l) | u32(d.dmas[1].cnt_h) << 16
			disabled := cnt >> 31 == 0
			cnt &= ~(size << shift)
			cnt |= val << shift
			d.dmas[1].cnt_l = u16(cnt)
			d.dmas[1].cnt_h = u16(cnt >> 16)
			if disabled && cnt >> 31 > 0 {
				dma := d.dmas[1]
				d.dmas[1].count = if dma.cnt_l != 0 { dma.cnt_l } else { 0x4000 }
				d.dmas[1].source = dma.sad
				d.dmas[1].destination = dma.dad
			}
		}
		0x0400_00C8 {
			d.dmas[2].sad &= ~(size << shift)
			d.dmas[2].sad |= val << shift
		}
		0x0400_00CC {
			d.dmas[2].dad &= ~(size << shift)
			d.dmas[2].dad |= val << shift
		}
		0x0400_00D0 {
			mut cnt := u32(d.dmas[2].cnt_l) | u32(d.dmas[2].cnt_h) << 16
			disabled := cnt >> 31 == 0
			cnt &= ~(size << shift)
			cnt |= val << shift
			d.dmas[2].cnt_l = u16(cnt)
			d.dmas[2].cnt_h = u16(cnt >> 16)
			if disabled && cnt >> 31 > 0 {
				dma := d.dmas[2]
				d.dmas[2].count = if dma.cnt_l != 0 { dma.cnt_l } else { 0x4000 }
				d.dmas[2].source = dma.sad
				d.dmas[2].destination = dma.dad
			}
		}
		0x0400_00D4 {
			d.dmas[3].sad &= ~(size << shift)
			d.dmas[3].sad |= val << shift
		}
		0x0400_00D8 {
			d.dmas[3].dad &= ~(size << shift)
			d.dmas[3].dad |= val << shift
		}
		0x0400_00DC {
			mut cnt := u32(d.dmas[3].cnt_l) | u32(d.dmas[3].cnt_h) << 16
			disabled := cnt >> 31 == 0
			cnt &= ~(size << shift)
			cnt |= val << shift
			d.dmas[3].cnt_l = u16(cnt)
			d.dmas[3].cnt_h = u16(cnt >> 16)
			if disabled && cnt >> 31 > 0 {
				dma := d.dmas[3]
				d.dmas[3].count = if dma.cnt_l != 0 { u32(dma.cnt_l) } else { 0x10000 }
				d.dmas[3].source = dma.sad
				d.dmas[3].destination = dma.dad
			}
		}
		else {}
	}
}

@[params]
pub struct HookStatus {
	vblank  bool
	hblank  bool
	sound   bool
	capture bool
}

const flags = [InterruptFlag.dma0, .dma1, .dma2, .dma3]

pub fn (mut d Dmas) emulate_cycle(mut ints Interrupts, status HookStatus) ?DmaInfo {
	for i in 0 .. 4 {
		dma := d.dmas[i]
		mut dmacnt := DmaCnt.from(dma.cnt_h)
		if !dmacnt.has(.enable) {
			continue
		}

		if !dma.transfering {
			start := match dmacnt.mode() {
				0 {
					true
				}
				1 {
					status.vblank
				}
				2 {
					status.hblank
				}
				else {
					match i {
						1, 2 { status.sound }
						3 { status.capture }
						else { false }
					}
				}
			}

			if start {
				d.dmas[i].transfering = true
			}
		}

		if d.dmas[i].transfering {
			d.dmas[i].count--
			ret := DmaInfo{
				source: dma.source
				destination: dma.destination
				size: if dmacnt.has(.size) { u32(0xFFFF_FFFF) } else { 0xFFFF }
			}

			size := if dmacnt.has(.size) { u32(4) } else { 2 }
			match dmacnt.source() {
				0, 3 {
					d.dmas[i].source += size
				}
				1 {
					d.dmas[i].source -= size
				}
				else {}
			}
			match dmacnt.destination() {
				0 {
					d.dmas[i].destination += size
				}
				1 {
					d.dmas[i].destination -= size
				}
				else {}
			}

			if d.dmas[i].count == 0 {
				d.dmas[i].transfering = false
				if dmacnt.has(.repeat) {
					d.dmas[i].count = if dma.cnt_l != 0 {
						dma.cnt_l
					} else if i == 3 {
						0x10000
					} else {
						0x4000
					}
					if dmacnt.destination() == 3 {
						d.dmas[i].destination = dma.dad
					}
				} else {
					dmacnt.clear(.enable)
				}
				if dmacnt.has(.irq_enable) {
					ints.irq(dma.flags[i])
				}
			}

			d.dmas[i].cnt_h = u16(dmacnt)
			return ret
		}
		d.dmas[i].cnt_h = u16(dmacnt)
	}
	return none
}
