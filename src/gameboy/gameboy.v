module gameboy

import gg { Context }
import cpu { Cpu }
import peripherals { Peripherals }
import peripherals.bios { Bios }

pub struct Gameboy {
mut:
	cpu         Cpu
	peripherals Peripherals
	gg          ?&Context
	image_idx   int
}

pub fn Gameboy.new(b Bios) &Gameboy {
	mut ret := &Gameboy{
		cpu: Cpu.new()
		peripherals: Peripherals.new(b)
	}
	ret.cpu.init(ret.peripherals)
	ret.init_gg()
	return ret
}

pub fn (mut g Gameboy) run() ! {
	mut gg_ctx := g.gg or { return error('gg is not initialized') }
	gg_ctx.run()
}

pub fn (mut g Gameboy) emulate_cycle() bool {
	g.cpu.emulate_cycle(mut g.peripherals)
	if g.peripherals.ppu.emulate_cycle() {
		g.draw_lcd(g.peripherals.ppu.pixel_buffer())
		return true
	}
	return false
}
