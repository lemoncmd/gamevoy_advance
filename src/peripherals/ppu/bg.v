module ppu

@[flag]
enum BgCnt as u16 {
	priority_0
	priority_1
	tile_data_addr_0
	tile_data_addr_1
	unused0
	unused1
	mosaic_enable
	color_mode
	map_data_addr_0
	map_data_addr_1
	map_data_addr_2
	map_data_addr_3
	overflow_wraparround
	display_size_x
	display_size_y
}

fn BgCnt.from(val u16) BgCnt {
	return unsafe { BgCnt(val) }
}

fn (b BgCnt) priority() u8 {
	return u8(b) & 0b11
}

fn (b BgCnt) tile_data_address() u16 {
	return ((u16(b) >> 2) & 0b11) << 13
}

fn (b BgCnt) map_data_address() u16 {
	return ((u16(b) >> 8) & 0b1111) << 10
}

fn (b BgCnt) display_size() u16 {
	return 128 << (u16(b) >> 14)
}

fn (mut p Ppu) fill_with_backdrop() {
	color := p.get_color_from_palette(false, Palette16{
		palette: 0
		number: 0
	})
	ly := p.vcount & 0xFF
	for lx in 0 .. 240 {
		p.buffer[int(ly) * 960 + lx * 4] = color.red()
		p.buffer[int(ly) * 960 + lx * 4 + 1] = color.green()
		p.buffer[int(ly) * 960 + lx * 4 + 2] = color.blue()
		p.buffer[int(ly) * 960 + lx * 4 + 3] = 255
	}
}

fn (mut p Ppu) render_bg(winflags [240]WindowFlag, mut priorities [240]u8) {
	disp_cnt := DispCnt.from(p.dispcnt)
	if disp_cnt.bgmode() < 3 {
		p.render_tile_mode_bg(winflags, mut priorities, disp_cnt)
	} else {
		p.render_bitmap_mode_bg(winflags, mut priorities, disp_cnt)
	}
}

const rendered_bg_in_mode = [
	[0, 1, 2, 3],
	[0, 1, 2],
	[2, 3],
]

fn (mut p Ppu) render_tile_mode_bg(winflags [240]WindowFlag, mut priorities [240]u8, disp_cnt DispCnt) {
	bg_enable := [
		disp_cnt.has(.bg0_enable),
		disp_cnt.has(.bg1_enable),
		disp_cnt.has(.bg2_enable),
		disp_cnt.has(.bg3_enable),
	]
	bg_cnts := [p.bg0cnt, p.bg1cnt, p.bg2cnt, p.bg3cnt].map(BgCnt.from(it))
	bg_priorities := bg_cnts.map(it.priority())
	bg_mode := disp_cnt.bgmode()
	mut layer_to_render := []int{}
	for priority in 0 .. 4 {
		for i, bg_priority in bg_priorities {
			if priority == bg_priority && i in ppu.rendered_bg_in_mode[bg_mode] && bg_enable[i] {
				layer_to_render << i
			}
		}
	}
	for layer in layer_to_render {
		if bg_mode == 0 || (bg_mode == 1 && layer < 2) {
			offset_x := match bg_mode {
				0 { p.bg0hofs }
				1 { p.bg1hofs }
				2 { p.bg2hofs }
				else { p.bg3hofs }
			} & 0x1FF
			offset_y := match bg_mode {
				0 { p.bg0vofs }
				1 { p.bg1vofs }
				2 { p.bg2vofs }
				else { p.bg3vofs }
			} & 0x1FF
			p.render_text_layer(winflags, mut priorities, layer, bg_cnts[layer], offset_x,
				offset_y)
		} else {
			p.render_affine_layer(winflags, mut priorities, layer, bg_cnts[layer])
		}
	}
}

fn (mut p Ppu) render_text_layer(winflags [240]WindowFlag, mut priorities [240]u8, number int, bg_cnt BgCnt, offset_x u16, offset_y u16) {
	tile_data_address := bg_cnt.tile_data_address()
	map_data_address := bg_cnt.map_data_address()
	ly := p.vcount & 0xFF
	size_x := if bg_cnt.has(.display_size_x) { 512 } else { 256 }
	size_y := if bg_cnt.has(.display_size_y) { 512 } else { 256 }
	for lx in 0 .. 240 {
		if !winflags[lx].bg_enable(number) {
			continue
		}
		x := u16((lx + offset_x) & (size_x - 1))
		y := u16((ly + offset_y) & (size_y - 1))

		map_number := u16(if size_x == 512 && size_y == 512 {
			((y & 0x100) >> 7) | (x >> 8)
		} else {
			(x >> 8) | (y >> 8)
		})

		tile_data := p.vram[map_data_address + map_number << 10 + ((y & 0xF8) << 2) +
			((x & 0xF8) >> 3)]

		flipped_x := if (tile_data >> 10) & 1 > 0 {
			7 - (x & 7)
		} else {
			x & 7
		}
		flipped_y := if (tile_data >> 11) & 1 > 0 {
			7 - (y & 7)
		} else {
			y & 7
		}

		palette := if bg_cnt.has(.color_mode) {
			// 256 colors
			Palette(Palette256{
				number: u8(p.vram[tile_data_address + (tile_data & 0x3FF) << 5 + flipped_y << 2 +
					flipped_x >> 1] >> ((flipped_x & 1) << 3))
			})
		} else {
			// 16 palettes 16 colors
			Palette(Palette16{
				palette: u8(tile_data >> 12)
				number: u8(p.vram[tile_data_address + (tile_data & 0x3FF) << 4 + flipped_y << 1 +
					flipped_x >> 2] >> ((flipped_x & 3) << 2)) & 0xF
			})
		}

		if !palette.is_transparent() || number == 0 {
			color := p.get_color_from_palette(false, palette)

			p.buffer[int(ly) * 960 + lx * 4] = color.red()
			p.buffer[int(ly) * 960 + lx * 4 + 1] = color.green()
			p.buffer[int(ly) * 960 + lx * 4 + 2] = color.blue()
			p.buffer[int(ly) * 960 + lx * 4 + 3] = 255

			priorities[lx] = bg_cnt.priority()
		}
	}
}

fn (mut p Ppu) render_affine_layer(winflags [240]WindowFlag, mut priorities [240]u8, number int, bg_cnt BgCnt) {}

fn (mut p Ppu) render_bitmap_mode_bg(winflags [240]WindowFlag, mut priorities [240]u8, disp_cnt DispCnt) {
	bg_mode := disp_cnt.bgmode()
	bg_cnt := BgCnt.from(p.bg2cnt)
	ly := p.vcount & 0xFF
	frame_buffer_addr := if bg_mode > 3 && disp_cnt.has(.frame) { 0x5000 } else { 0 }
	for lx in 0..240 {
		match bg_mode {
			3 {}
			4 {
				color_number := p.vram[frame_buffer_addr + ly * 120 + lx >> 1] >> ((lx & 1) << 3)
				if color_number != 0 {
					palette := Palette256{u8(color_number)}
					color := p.get_color_from_palette(false, palette)

					p.buffer[int(ly) * 960 + lx * 4] = color.red()
					p.buffer[int(ly) * 960 + lx * 4 + 1] = color.green()
					p.buffer[int(ly) * 960 + lx * 4 + 2] = color.blue()
					p.buffer[int(ly) * 960 + lx * 4 + 3] = 255

					priorities[lx] = bg_cnt.priority()
				}
			}
			5 {}
			else {}
		}
	}
}
