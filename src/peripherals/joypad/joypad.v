module joypad

import cpu.interrupts { Interrupts }

@[flag]
pub enum Key as u16 {
	a
	b
	@select
	start
	right
	left
	up
	down
	r
	l
	unused0
	unused1
	unused2
	unused3
	irq_enable
	irq_cond
}

const all_keys = unsafe { Key(0x3F) }

pub struct Joypad {
mut:
	input Key = joypad.all_keys
	cnt   Key
}

pub fn Joypad.new() Joypad {
	return Joypad{}
}

pub fn (b &Joypad) read(addr u32) u32 {
	return match addr {
		0x0400_0130 { u32(b.input) | u32(b.cnt) << 16 }
		0x0400_0132 { u32(b.cnt) }
		else { 0 }
	}
}

pub fn (mut b Joypad) write(addr u32, val u32, size u32) {
	match addr {
		0x0400_0132 { b.cnt = unsafe { Key(val) } }
		else {}
	}
}

pub fn (b &Joypad) emulate_cycle(mut ints Interrupts) {
	if b.cnt.has(.irq_enable) {
		key_match := unsafe { Key(u16(b.cnt & joypad.all_keys) & ~u16(b.input)) }
		cond := if b.cnt.has(.irq_cond) {
			key_match.all(b.cnt & joypad.all_keys)
		} else {
			key_match.has(b.cnt & joypad.all_keys)
		}
		if cond {
			ints.irq(.joypad)
		}
	}
}

pub fn (mut j Joypad) button_down(key Key) {
	j.input.clear(key)
}

pub fn (mut j Joypad) button_up(key Key) {
	j.input.set(key)
}
