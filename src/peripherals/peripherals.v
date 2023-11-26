module peripherals

import peripherals.bios { Bios }

pub struct Peripherals {
	bios bios.Bios
}

pub fn (p &Peripherals) read(addr u32) u32 {
	return match addr {
		0x0000_0000...0x0000_3FFF { p.bios.read(addr) }
		// must be prefetched code
		else { 0 }
	}
}

pub fn (p &Peripherals) cycle(addr u32) u8 {
	return 1
}
