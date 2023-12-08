module apu

pub struct Apu {
mut:
	cnt_h u16
	bias  u16
}

pub fn Apu.new() Apu {
	return Apu{}
}

pub fn (a &Apu) read(addr u32) u32 {
	return match addr {
		0x0400_0082 { a.cnt_h }
		0x0400_0088 { a.bias }
		else { 0 }
	}
}

pub fn (mut a Apu) write(addr u32, val u32, size u32) {
	match addr {
		0x0400_0082 { a.cnt_h = u16(val) }
		0x0400_0088 { a.bias = u16(val) }
		else {}
	}
}

pub struct ApuTimer {
pub:
	sound_a bool
	sound_b bool
}

pub fn (mut a Apu) emulate_cycle() ApuTimer {
	return ApuTimer{
		sound_a: (a.cnt_h >> 10) & 1 > 0
		sound_b: (a.cnt_h >> 14) & 1 > 0
	}
}
