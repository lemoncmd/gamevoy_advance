module main

import gameboy as _ { Gameboy }

fn main() {
	mut g := Gameboy.new()
	g.run()!
}
