module register

pub struct Register {
mut:
	r0      u32
	r1      u32
	r2      u32
	r3      u32
	r4      u32
	r5      u32
	r6      u32
	r7      u32
	r8      u32
	r9      u32
	r10     u32
	r11     u32
	r12     u32
	r13     u32
	r14     u32
	r8_fiq  u32
	r9_fiq  u32
	r10_fiq u32
	r11_fiq u32
	r12_fiq u32
	r13_fiq u32
	r14_fiq u32
	r13_svc u32
	r14_svc u32
	r13_abt u32
	r14_abt u32
	r13_irq u32
	r14_irq u32
	r13_und u32
	r14_und u32
pub mut:
	r15      u32
	cpsr     Psr = u32(Flag.i) | u32(Flag.f) | u32(Mode.supervisor)
	spsr_fiq Psr
	spsr_svc Psr
	spsr_abt Psr
	spsr_irq Psr
	spsr_und Psr
}

pub enum Mode {
	user       = 0b10000
	fiq        = 0b10001
	irq        = 0b10010
	supervisor = 0b10011
	abort      = 0b10111
	undefined  = 0b11011
	system     = 0b11111
}

pub enum Flag as u32 {
	t = 1 << 5
	f = 1 << 6
	i = 1 << 7
	v = 1 << 28
	c = 1 << 29
	z = 1 << 30
	n = 1 << 31
}

type Psr = u32

fn (p Psr) get_mode() Mode {
	mode := u32(p) & 0b11111
	$for m in Mode.values {
		if mode == u32(m.value) {
			return m.value
		}
	}
	panic('invalid cpu mode: ${mode:05b}')
}

pub fn (mut p Psr) set_mode(m Mode) {
	p &= ~0b11111
	p |= u32(m)
}

pub fn (mut p Psr) set_flag(f Flag, val bool) {
	if val {
		p |= u32(f)
	} else {
		p &= ~u32(f)
	}
}

pub fn (p Psr) get_flag(f Flag) bool {
	return u32(p) & u32(f) > 0
}

pub fn (p Psr) is_priviledge() bool {
	return p.get_mode() != .user
}

pub fn (r &Register) read(addr u8) u32 {
	return match addr {
		0 {
			r.r0
		}
		1 {
			r.r1
		}
		2 {
			r.r2
		}
		3 {
			r.r3
		}
		4 {
			r.r4
		}
		5 {
			r.r5
		}
		6 {
			r.r6
		}
		7 {
			r.r7
		}
		8 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r8_fiq }
				else { r.r8 }
			}
		}
		9 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r9_fiq }
				else { r.r9 }
			}
		}
		10 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r10_fiq }
				else { r.r10 }
			}
		}
		11 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r11_fiq }
				else { r.r11 }
			}
		}
		12 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r12_fiq }
				else { r.r12 }
			}
		}
		13 {
			match r.cpsr.get_mode() {
				.system { r.r13 }
				.user, .fiq { r.r13_fiq }
				.supervisor { r.r13_svc }
				.abort { r.r13_abt }
				.irq { r.r13_irq }
				.undefined { r.r13_und }
			}
		}
		14 {
			match r.cpsr.get_mode() {
				.system { r.r14 }
				.user, .fiq { r.r14_fiq }
				.supervisor { r.r14_svc }
				.abort { r.r14_abt }
				.irq { r.r14_irq }
				.undefined { r.r14_und }
			}
		}
		15 {
			r.r15
		}
		else {
			panic('unexpected address for register: 0x${addr:02X}')
		}
	}
}

pub fn (mut r Register) write(addr u8, val u32) {
	match addr {
		0 {
			r.r0 = val
		}
		1 {
			r.r1 = val
		}
		2 {
			r.r2 = val
		}
		3 {
			r.r3 = val
		}
		4 {
			r.r4 = val
		}
		5 {
			r.r5 = val
		}
		6 {
			r.r6 = val
		}
		7 {
			r.r7 = val
		}
		8 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r8_fiq = val }
				else { r.r8 = val }
			}
		}
		9 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r9_fiq = val }
				else { r.r9 = val }
			}
		}
		10 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r10_fiq = val }
				else { r.r10 = val }
			}
		}
		11 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r11_fiq = val }
				else { r.r11 = val }
			}
		}
		12 {
			match r.cpsr.get_mode() {
				.user, .fiq { r.r12_fiq = val }
				else { r.r12 = val }
			}
		}
		13 {
			match r.cpsr.get_mode() {
				.system { r.r13 = val }
				.user, .fiq { r.r13_fiq = val }
				.supervisor { r.r13_svc = val }
				.abort { r.r13_abt = val }
				.irq { r.r13_irq = val }
				.undefined { r.r13_und = val }
			}
		}
		14 {
			match r.cpsr.get_mode() {
				.system { r.r14 = val }
				.user, .fiq { r.r14_fiq = val }
				.supervisor { r.r14_svc = val }
				.abort { r.r14_abt = val }
				.irq { r.r14_irq = val }
				.undefined { r.r14_und = val }
			}
		}
		15 {
			r.r15 = val
		}
		else {
			panic('unexpected address for register: 0x${addr:02X}')
		}
	}
}

pub fn (r &Register) read_user_register(addr u8) u32 {
	return match addr {
		0 { r.r0 }
		1 { r.r1 }
		2 { r.r2 }
		3 { r.r3 }
		4 { r.r4 }
		5 { r.r5 }
		6 { r.r6 }
		7 { r.r7 }
		8 { r.r8 }
		9 { r.r9 }
		10 { r.r10 }
		11 { r.r11 }
		12 { r.r12 }
		13 { r.r13 }
		14 { r.r14 }
		15 { r.r15 }
		else { panic('unexpected address for register: 0x${addr:02X}') }
	}
}

pub fn (mut r Register) write_user_register(addr u8, val u32) {
	match addr {
		0 { r.r0 = val }
		1 { r.r1 = val }
		2 { r.r2 = val }
		3 { r.r3 = val }
		4 { r.r4 = val }
		5 { r.r5 = val }
		6 { r.r6 = val }
		7 { r.r7 = val }
		8 { r.r8 = val }
		9 { r.r9 = val }
		10 { r.r10 = val }
		11 { r.r11 = val }
		12 { r.r12 = val }
		13 { r.r13 = val }
		14 { r.r14 = val }
		15 { r.r15 = val }
		else { panic('unexpected address for register: 0x${addr:02X}') }
	}
}

pub fn (r &Register) read_spsr() Psr {
	return match r.cpsr.get_mode() {
		.fiq { r.spsr_fiq }
		.supervisor { r.spsr_svc }
		.abort { r.spsr_abt }
		.irq { r.spsr_irq }
		.undefined { r.spsr_und }
		else { panic('cannot get spsr in user or system mode') }
	}
}

pub fn (mut r Register) write_spsr(val u32) {
	match r.cpsr.get_mode() {
		.fiq { r.spsr_fiq = val }
		.supervisor { r.spsr_svc = val }
		.abort { r.spsr_abt = val }
		.irq { r.spsr_irq = val }
		.undefined { r.spsr_und = val }
		else { panic('cannot get spsr in user or system mode') }
	}
}
