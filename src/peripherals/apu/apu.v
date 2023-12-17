module apu

const wave_duty = [
	[u8(0), 0, 0, 0, 0, 0, 0, 1]!,
	[u8(0), 0, 0, 0, 0, 0, 1, 1]!,
	[u8(0), 0, 0, 0, 1, 1, 1, 1]!,
	[u8(0), 0, 1, 1, 1, 1, 1, 1]!,
]!

pub struct Apu {
mut:
	channel1 Channel1
	channel2 Channel2
	channel3 Channel3
	channel4 Channel4
	channela PcmChannel
	channelb PcmChannel
	cnt_h    u16
	bias     u16
}

pub fn Apu.new() Apu {
	return Apu{}
}

pub fn (a &Apu) read(addr u32) u32 {
	return u32(a.read_16(addr)) | (u32(a.read_16(addr + 2)) << 16)
}

pub fn (a &Apu) read_16(addr u32) u16 {
	return match addr & 0xFFFF_FFFE {
		0x0400_0060...0x0400_0064 { a.channel1.read(addr - 0x0400_0060) }
		0x0400_0068, 0x0400_006C { a.channel2.read(addr - 0x0400_0068) }
		0x0400_0070...0x0400_0074 { a.channel3.read(addr - 0x0400_0070) }
		0x0400_0078, 0x0400_007C { a.channel4.read(addr - 0x0400_0078) }
		0x0400_0080 { 0 }
		0x0400_0082 { a.cnt_h }
		0x0400_0084 { 0 }
		0x0400_0088 { a.bias }
		0x0400_0090...0x0400_009F { a.channel3.read_wave_pattern(addr - 0x0400_0090) }
		else { 0 }
	} >> ((addr & 1) << 3)
}

pub fn (mut a Apu) write(addr u32, val u32, size u32) {
	match addr {
		0x0400_00A0 { a.channela.push(val) }
		0x0400_00A4 { a.channelb.push(val) }
		0x0400_0082 { a.cnt_h = u16(val) }
		0x0400_0088 { a.bias = u16(val) }
		else {}
	}
}

@[params]
pub struct TimerApu {
	timer0 bool
	timer1 bool
}

pub fn (mut a Apu) emulate_cycle(timer TimerApu) bool {
	sound_a := (a.cnt_h >> 10) & 1 > 0
	sound_b := (a.cnt_h >> 14) & 1 > 0
	timer_a := if sound_a { timer.timer1 } else { timer.timer0 }
	timer_b := if sound_b { timer.timer1 } else { timer.timer0 }
	if timer_a {
		a.channela.buffer.shift() or {}
	}
	if timer_b {
		a.channelb.buffer.shift() or {}
	}
	dma_req_a := timer_a && a.channela.buffer.len() <= 16
	dma_req_b := timer_b && a.channelb.buffer.len() <= 16
	return dma_req_a || dma_req_b
}
