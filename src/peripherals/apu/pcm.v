module apu

import datatypes

struct PcmChannel {
mut:
	buffer datatypes.LinkedList[u8]
}

fn (mut p PcmChannel) push(val u32) {
	p.buffer.push_many([
		u8(val),
		u8(val >> 8),
		u8(val >> 16),
		u8(val >> 24),
	])
}
