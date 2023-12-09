module ppu

@[flag]
enum ObjAttr as u16 {
	y0
	y1
	y2
	y3
	y4
	y5
	y6
	y7
	affine_enable
	invisible_or_double
	mode0
	mode1
	mosaic_enable
	palette
	shape0
	shape1
}

fn (o ObjAttr) y() u8 {
	return u8(o)
}

fn (o ObjAttr) mode() u16 {
	return (u16(o) >> 10) & 3
}

fn (o ObjAttr) shape() u16 {
	return u16(o) >> 14
}

const shape_length = [
	[8, 8, 16, 32]!,
	[8, 16, 32, 64]!,
	[16, 32, 32, 64]!,
]!

fn (mut p Ppu) render_obj(winflags [240]WindowFlag, priorities [240]u8) {
	if !DispCnt.from(p.dispcnt).has(.obj_enable) {
		return
	}
	for i in 0 .. 128 {
		attr1 := unsafe { ObjAttr(p.oam[i << 1]) }
		attr2 := u16(p.oam[i << 1] >> 16)

		if !attr1.has(.affine_enable) && attr1.has(.invisible_or_double) {
			continue
		}

		ly := p.vcount & 0xFF
		y := i8(attr1.y())
		y_size := match attr1.shape() {
			0 { ppu.shape_length[1][attr2 >> 14] }
			1 { ppu.shape_length[0][attr2 >> 14] }
			2 { ppu.shape_length[2][attr2 >> 14] }
			else { 0 }
		}

		if ly < y || y + y_size <= ly {
			continue
		}

		flipped_y := u16(if (attr2 >> 13) & 1 > 0 {
			y_size - (i16(ly) - y) - 1
		} else {
			i16(ly) - y
		})
		x_size := match attr1.shape() {
			0 { ppu.shape_length[1][attr2 >> 14] }
			1 { ppu.shape_length[2][attr2 >> 14] }
			2 { ppu.shape_length[0][attr2 >> 14] }
			else { 0 }
		}

		if !attr1.has(.affine_enable) {
			p.render_text_obj(winflags, priorities, attr1.mode(), i, ly, flipped_y, attr1.has(.palette),
				x_size)
		} else {
			p.render_affine_obj(winflags, priorities, attr1.mode(), i, ly, flipped_y,
				attr1.has(.palette), x_size)
		}
	}
}

fn (mut p Ppu) render_text_obj(winflags [240]WindowFlag, priorities [240]u8, mode u16, i int, ly int, flipped_y int, color_mode bool, x_size int) {
	attr2 := u16(p.oam[i << 1] >> 16)
	attr3 := u16(p.oam[i << 1 + 1])

	x := i16((attr2 & 0x1FF) << 7) >> 7
	for lx in 0 .. 240 {
		if !winflags[lx].has(.obj_enable) || priorities[lx] < ((attr3 >> 10) & 3) {
			continue
		}

		if lx < x || x + x_size <= lx {
			continue
		}
		xx := lx - x

		flipped_x := if (attr2 >> 12) & 1 > 0 {
			x_size - xx - 1
		} else {
			xx
		}

		tile_number := (attr3 & 0x3FF) + if DispCnt.from(p.dispcnt).has(.obj_mapping_mode) {
			// 1 dim
			((flipped_x >> 3) + (flipped_y >> 3) * (x_size >> 3)) << int(color_mode)
		} else {
			// 2dim
			(flipped_x >> 3) << int(color_mode) + (flipped_y >> 3) * 0x20
		}

		// TODO a000 in bgmode 3-5
		tile_data_address := 0x8000
		palette := if color_mode {
			// 256 colors
			Palette(Palette256{
				number: u8(p.vram[tile_data_address + tile_number << 4 + (flipped_y & 7) << 2 +
					(flipped_x & 7) >> 1] >> ((flipped_x & 1) << 3))
			})
		} else {
			// 16 palettes 16 colors
			Palette(Palette16{
				palette: u8(attr3 >> 12)
				number: u8(p.vram[tile_data_address + tile_number << 4 + (flipped_y & 7) << 1 +
					(flipped_x & 7) >> 2] >> ((flipped_x & 3) << 2)) & 0xF
			})
		}

		if mode == 0 && !palette.is_transparent() {
			color := p.get_color_from_palette(true, palette)

			p.buffer[ly * 960 + lx * 4] = color.red()
			p.buffer[ly * 960 + lx * 4 + 1] = color.green()
			p.buffer[ly * 960 + lx * 4 + 2] = color.blue()
			p.buffer[ly * 960 + lx * 4 + 3] = 255
		}
	}
}

fn (mut p Ppu) render_affine_obj(winflags [240]WindowFlag, priorities [240]u8, mode u16, i int, ly int, flipped_y int, color_mode bool, x_size int) {
	attr2 := u16(p.oam[i << 1] >> 16)
	attr3 := u16(p.oam[i << 1 + 1])

	x := i16((attr2 & 0x1FF) << 7) >> 7
	for lx in 0 .. 240 {
		if !winflags[lx].has(.obj_enable) || priorities[lx] < ((attr3 >> 10) & 3) {
			continue
		}

		if lx < x || x + x_size <= lx {
			continue
		}
		xx := lx - x

		flipped_x := if (attr2 >> 12) & 1 > 0 {
			x_size - xx - 1
		} else {
			xx
		}

		tile_number := (attr3 & 0x3FF) + if DispCnt.from(p.dispcnt).has(.obj_mapping_mode) {
			// 1 dim
			((flipped_x >> 3) + (flipped_y >> 3) * (x_size >> 3)) << int(color_mode)
		} else {
			// 2dim
			(flipped_x >> 3) << int(color_mode) + (flipped_y >> 3) * 0x20
		}

		// TODO a000 in bgmode 3-5
		tile_data_address := 0x8000
		palette := if color_mode {
			// 256 colors
			Palette(Palette256{
				number: u8(p.vram[tile_data_address + tile_number << 4 + (flipped_y & 7) << 2 +
					(flipped_x & 7) >> 1] >> ((flipped_x & 1) << 3))
			})
		} else {
			// 16 palettes 16 colors
			Palette(Palette16{
				palette: u8(attr3 >> 12)
				number: u8(p.vram[tile_data_address + tile_number << 4 + (flipped_y & 7) << 1 +
					(flipped_x & 7) >> 2] >> ((flipped_x & 3) << 2)) & 0xF
			})
		}

		if mode == 0 && !palette.is_transparent() {
			color := p.get_color_from_palette(true, palette)

			p.buffer[ly * 960 + lx * 4] = color.red()
			p.buffer[ly * 960 + lx * 4 + 1] = color.green()
			p.buffer[ly * 960 + lx * 4 + 2] = color.blue()
			p.buffer[ly * 960 + lx * 4 + 3] = 255
		}
		p.buffer[ly * 960 + lx * 4] = 255
		p.buffer[ly * 960 + lx * 4 + 1] = 0
		p.buffer[ly * 960 + lx * 4 + 2] = 0
		p.buffer[ly * 960 + lx * 4 + 3] = 255
	}
}
