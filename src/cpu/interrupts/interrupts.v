module interrupts

@[flag]
pub enum InterruptFlag as u16 {
	vblank
	hblank
	lyc_eq_ly
	timer0
	timer1
	timer2
	timer3
	serial
	dma0
	dma1
	dma2
	dma3
	joypad
	gamepak
}

pub const all_flags = (fn () InterruptFlag {
	mut f := InterruptFlag.vblank
	$for value in InterruptFlag.values {
		f.set(value.value)
	}
	return f
}())

pub struct Interrupts {
pub mut:
	int_flags  InterruptFlag
	int_enable InterruptFlag
	ime        bool
}

pub fn (mut i Interrupts) irq(f InterruptFlag) {
	i.int_flags.set(f)
}

pub fn (i &Interrupts) read(addr u32) u32 {
	return u32(i.read_16(addr)) | (u32(i.read_16(addr + 2)) << 16)
}

pub fn (i &Interrupts) read_16(addr u32) u16 {
	return match addr & 0xFFFF_FFFE {
		0x0400_0200 { u16(i.int_enable) }
		0x0400_0202 { u16(i.int_flags) }
		0x0400_0208 { u16(i.ime) }
		else { 0 }
	} >> ((addr & 1) << 3)
}

pub fn (mut i Interrupts) write(addr u32, val u32, size u32) {
	if size == 0xFFFF_FFFF {
		i.write_16(addr, u16(val), 0xFFFF)
		i.write_16(addr + 2, u16(val >> 16), 0xFFFF)
	} else {
		i.write_16(addr, u16(val), u16(size))
	}
}

pub fn (mut i Interrupts) write_16(addr u32, val u32, size u32) {
	shift := (addr & 1) << 3
	match addr & 0xFFFF_FFFE {
		0x0400_0200 {
			i.int_enable = i.int_enable & unsafe { InterruptFlag(u16(~(size << shift))) }
			i.int_enable = i.int_enable | unsafe { InterruptFlag(u16(val << shift)) }
		}
		0x0400_0202 {
			i.int_flags = i.int_flags & unsafe { InterruptFlag(u16(~(size << shift))) }
			i.int_flags = i.int_flags | unsafe { InterruptFlag(u16(val << shift)) }
		}
		0x0400_0208 {
			if shift == 0 {
				i.ime = val & 1 > 0
			}
		}
		else {}
	}
}

pub fn (i &Interrupts) get_interrupts() InterruptFlag {
	return i.int_flags & i.int_enable
}
