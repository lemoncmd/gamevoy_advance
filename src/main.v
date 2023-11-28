module main

import os
import gameboy as _ { Gameboy }
import peripherals.bios as _ { Bios }

fn main() {
	bios_file_name := os.args[1]
	bios_data := os.read_bytes(bios_file_name)!
	b := Bios.new(bios_data)

	mut g := Gameboy.new(b)
	g.run()!
}
