module gameboy

import math
import gg
import sokol.sapp

const cpu_clock_hz = 16_777_216

const ratio = 4

fn (mut g Gameboy) init_gg() {
	g.gg = gg.new_context(
		width: 240 * gameboy.ratio
		height: 160 * gameboy.ratio
		create_window: true
		window_title: 'gamevoy advance'
		init_fn: fn (mut g Gameboy) {
			if mut gg_ctx := g.gg {
				g.image_idx = gg_ctx.new_streaming_image(240, 160, 4, pixel_format: .rgba8)
			}
		}
		frame_fn: fn (mut g Gameboy) {
			if mut gg_ctx := g.gg {
				gg_ctx.begin()
			}
			mut not_rendered := true
			fps := math.max(int(0.5 + 1.0 / sapp.frame_duration()), 60)
			for _ in 0 .. gameboy.cpu_clock_hz / fps {
				if g.emulate_cycle() {
					not_rendered = false
				}
			}
			if not_rendered {
				if mut gg_ctx := g.gg {
					mut istream_image := gg_ctx.get_cached_image_by_idx(g.image_idx)
					size := gg.window_size()
					gg_ctx.draw_image(0, 0, size.width, size.height, istream_image)
				}
			}
			if mut gg_ctx := g.gg {
				gg_ctx.end()
			}
		}
		user_data: &g
	)
}

fn (mut g Gameboy) draw_lcd(pixels []u8) {
	if mut gg_ctx := g.gg {
		mut istream_image := gg_ctx.get_cached_image_by_idx(g.image_idx)
		istream_image.update_pixel_data(&pixels[0])
		size := gg.window_size()
		gg_ctx.draw_image(0, 0, size.width, size.height, istream_image)
	}
}
