module gameboy

import gg { Context }
import cpu { Cpu }
import peripherals { Peripherals }
import peripherals.bios { Bios }
import peripherals.cartridge { Cartridge }

pub struct Gameboy {
mut:
	cpu         Cpu
	peripherals Peripherals
	gg          ?&Context
	image_idx   int
}

pub fn Gameboy.new(b Bios, c Cartridge) &Gameboy {
	mut ret := &Gameboy{
		cpu: Cpu.new()
		peripherals: Peripherals.new(b, c)
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
	if g.cpu.dma_info == none {
		if dma_info := g.peripherals.dmas.emulate_cycle(mut g.cpu.interrupts) {
			g.cpu.dma_info = dma_info
		}
	}
	g.cpu.emulate_cycle(mut g.peripherals)
	g.peripherals.timers.emulate_cycle(mut g.cpu.interrupts)
	if g.peripherals.ppu.emulate_cycle(mut g.cpu.interrupts) {
		g.draw_lcd(g.peripherals.ppu.pixel_buffer())
		return true
	}
	return false
}
