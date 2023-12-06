module timer

import cpu.interrupts { Interrupts, InterruptFlag }

pub struct Timers {
mut:
	count u16
	timers [4]Timer
}

struct Timer {
mut:
	tmcnt_l u16
	tmcnt_reload u16
	tmcnt_h u16
}

@[flag]
enum TmCnt as u16 {
	freq0
	freq1
	cascade
	unused0
	unused1
	unused2
	irq_enable
	enable
}

fn TmCnt.from(val u16) TmCnt {
	return unsafe { TmCnt(val) }
}

fn (t TmCnt) matches(count u16) bool {
	return match u16(t) & 3 {
		0 { true }
		1 { count & 0x3F == 0 }
		2 { count & 0xFF == 0 }
		3 { count & 0x3FF == 0 }
		else { false }
	}
}

pub fn Timers.new() Timers {
	return Timers{}
}

pub fn (t &Timers) read(addr u32) u32 {
	return t.read_16(addr + 1) << 16 | t.read_16(addr)
}

fn (t &Timers) read_16(addr u32) u32 {
	return match addr {
		0x0400_0100 { t.timers[0].tmcnt_l }
		0x0400_0102 { t.timers[0].tmcnt_h }
		0x0400_0104 { t.timers[1].tmcnt_l }
		0x0400_0106 { t.timers[1].tmcnt_h }
		0x0400_0108 { t.timers[2].tmcnt_l }
		0x0400_010A { t.timers[2].tmcnt_h }
		0x0400_010C { t.timers[3].tmcnt_l }
		0x0400_010E { t.timers[3].tmcnt_h }
		else { 0 }
	} >> ((addr & 1) << 3)
}

pub fn (mut t Timers) write(addr u32, val u32, size u32) {
	t.write_16(addr, u16(val), u16(size))
	if size == 0xFFFF_FFFF {
		t.write_16(addr + 2, u16(val >> 16), u16(size))
	}
}

fn (mut t Timers) write_16(addr u32, val u16, size u16) {
	shift := (addr & 1) << 3
	match addr {
		0x0400_0100 {
			t.timers[0].tmcnt_reload &= ~(size << shift)
			t.timers[0].tmcnt_reload |= val << shift
		}
		0x0400_0102 {
			enable := TmCnt.from(t.timers[0].tmcnt_h).has(.enable)
			t.timers[0].tmcnt_h &= ~(size << shift)
			t.timers[0].tmcnt_h |= val << shift
			if !enable && TmCnt.from(t.timers[0].tmcnt_h).has(.enable) {
				t.timers[0].tmcnt_l = t.timers[0].tmcnt_reload
			}
		}
		0x0400_0104 {
			t.timers[1].tmcnt_reload &= ~(size << shift)
			t.timers[1].tmcnt_reload |= val << shift
		}
		0x0400_0106 {
			enable := TmCnt.from(t.timers[1].tmcnt_h).has(.enable)
			t.timers[1].tmcnt_h &= ~(size << shift)
			t.timers[1].tmcnt_h |= val << shift
			if !enable && TmCnt.from(t.timers[1].tmcnt_h).has(.enable) {
				t.timers[1].tmcnt_l = t.timers[1].tmcnt_reload
			}
		}
		0x0400_0108 {
			t.timers[2].tmcnt_reload &= ~(size << shift)
			t.timers[2].tmcnt_reload |= val << shift
		}
		0x0400_010A {
			enable := TmCnt.from(t.timers[2].tmcnt_h).has(.enable)
			t.timers[2].tmcnt_h &= ~(size << shift)
			t.timers[2].tmcnt_h |= val << shift
			if !enable && TmCnt.from(t.timers[2].tmcnt_h).has(.enable) {
				t.timers[2].tmcnt_l = t.timers[2].tmcnt_reload
			}
		}
		0x0400_010C {
			t.timers[3].tmcnt_reload &= ~(size << shift)
			t.timers[3].tmcnt_reload |= val << shift
		}
		0x0400_010E {
			enable := TmCnt.from(t.timers[3].tmcnt_h).has(.enable)
			t.timers[3].tmcnt_h &= ~(size << shift)
			t.timers[3].tmcnt_h |= val << shift
			if !enable && TmCnt.from(t.timers[3].tmcnt_h).has(.enable) {
				t.timers[3].tmcnt_l = t.timers[3].tmcnt_reload
			}
		}
		else {}
	}
}

const flags = [InterruptFlag.timer0, .timer1, .timer2, .timer3]

pub fn (mut t Timers) emulate_cycle(mut ints Interrupts) {
	mut overflowed := false
	for i in 0 .. 3 {
		timer := t.timers[i]
		tmcnt := TmCnt.from(timer.tmcnt_h)
		will_overflow := timer.tmcnt_l == 0xFFFF
		if tmcnt.has(.enable) {
			if tmcnt.has(.cascade) {
				if overflowed {
					t.timers[i].tmcnt_l++
				}
			} else if tmcnt.matches(t.count) {
				t.timers[i].tmcnt_l++
			}
			overflowed = false
			if will_overflow && t.timers[i].tmcnt_l == 0 {
				overflowed = true
				t.timers[i].tmcnt_l = timer.tmcnt_reload
				if tmcnt.has(.irq_enable) {
					ints.irq(flags[i])
				}
			}
		} else {
			overflowed = false
		}
	}
	t.count++
}
