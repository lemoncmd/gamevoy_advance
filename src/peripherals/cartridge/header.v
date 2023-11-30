module cartridge

@[packed]
struct CartridgeHeader {
	entry_point  u32
	packed_logo  [156]u8
	game_title   [12]u8
	game_code    [4]u8
	maker_code   [2]u8
	magic_number [2]u8
	device_type  u8
	reserved     [7]u8
	version      u8
	check_sum    u8
}

fn (c &CartridgeHeader) check_sum() {
	mut chk := u8(0)
	data := unsafe { &u8(c) }
	for i in 0xA0 .. 0xBD {
		chk -= unsafe { data[i] }
	}
	chk -= 0x19
	assert chk == c.check_sum, 'checksum validation failed'
}
