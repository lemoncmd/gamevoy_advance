module main

import os
import gameboy as _ { Gameboy }
import peripherals.bios as _ { Bios }
import peripherals.cartridge as _ { Cartridge }

fn main() {
	bios_file_name := os.args[1]
	bios_data := os.read_bytes(bios_file_name)!
	b := Bios.new(bios_data)

	cartridge_file_name := os.args[2]
	cartridge_data := os.read_bytes(cartridge_file_name)!
	c := Cartridge.new(cartridge_data)

	mut g := Gameboy.new(b, c)
	g.run()!
}
