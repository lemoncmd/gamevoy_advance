module util

pub fn lsl(val u32, count u32) (u32, ?bool) {
	return match count {
		0 { val, ?bool(none) }
		1...31 { val << count, ?bool((val >> (32 - count)) & 1 > 0) }
		32 { 0, ?bool(val & 1 > 0) }
		else { 0, ?bool(false) }
	}
}

pub fn lsr(val u32, count u32) (u32, ?bool) {
	return match count {
		0 { val, ?bool(none) }
		1...31 { val >> count, ?bool((val >> (count - 1)) & 1 > 0) }
		32 { 0, ?bool((val >> 31) & 1 > 0) }
		else { 0, ?bool(false) }
	}
}

pub fn asr(val u32, count u32) (u32, ?bool) {
	return match count {
		0 { val, ?bool(none) }
		1...31 { u32(i32(val) >> count), ?bool((val >> (count - 1)) & 1 > 0) }
		32 { u32(i32(val) >> 31), ?bool((val >> 31) & 1 > 0) }
		else { 0, ?bool(false) }
	}
}

pub fn ror(val u32, count_ u32) (u32, ?bool) {
	return if count_ == 0 {
		val, ?bool(none)
	} else if count_ & 0x1F == 0 {
		val, ?bool((val >> 31) & 1 > 0)
	} else {
		count := count_ & 0x1F
		val >> count | val << (32 - count), ?bool((val >> (count - 1)) & 1 > 0)
	}
}
