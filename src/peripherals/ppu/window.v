module ppu

@[flag]
enum WindowFlag as u8 {
	bg0_enable
	bg1_enable
	bg2_enable
	bg3_enable
	obj_enable
	effect
}

fn (w WindowFlag) bg_enable(number int) bool {
	return match number {
		0 { w.has(.bg0_enable) }
		1 { w.has(.bg1_enable) }
		2 { w.has(.bg2_enable) }
		else { w.has(.bg3_enable) }
	}
}

// v bug
const all_flags = WindowFlag.bg1_enable | WindowFlag.bg0_enable | WindowFlag.bg2_enable | WindowFlag.bg3_enable | WindowFlag.obj_enable

fn (mut p Ppu) calculate_window(mut winflags [240]WindowFlag) {
	dispcnt := DispCnt.from(p.dispcnt)
	mut win_enable := false
	if dispcnt.has(.obj_enable) && dispcnt.has(.objwin_enable) {
		p.calculate_obj_window(mut winflags)
		win_enable = true
	}
	if dispcnt.has(.win1_enable) {
		p.calculate_normal_window(mut winflags, 1)
		win_enable = true
	}
	if dispcnt.has(.win0_enable) {
		p.calculate_normal_window(mut winflags, 0)
		win_enable = true
	}
	if !win_enable {
		for i in 0 .. 240 {
			winflags[i] = ppu.all_flags
		}
	}
}

fn (mut p Ppu) calculate_normal_window(mut winflags [240]WindowFlag, i int) {
	winflag := unsafe { WindowFlag(u8(p.winin >> (i << 3))) }

	y := if i == 0 { p.win0v } else { p.win1v }
	y_top := u8(y >> 8)
	y_bottom_ := u8(y)
	y_bottom := if y_bottom_ > 160 || y_top > y_bottom_ { 160 } else { y_bottom_ }
	ly := p.vcount & 0xFF
	if ly < y_top || y_bottom < ly {
		return
	}

	for lx in 0 .. 240 {
		x := if i == 0 { p.win0h } else { p.win1h }
		x_left := u8(x >> 8)
		x_right_ := u8(x)
		x_right := if x_right_ > 240 || x_left > x_right_ { 240 } else { x_right_ }
		if x_left <= lx && lx <= x_right {
			winflags[lx] = winflag
		}
	}
}

fn (mut p Ppu) calculate_obj_window(mut winflags [240]WindowFlag) {
	for i in 0 .. 128 {
		attr1 := unsafe { ObjAttr(p.oam[i << 1]) }
		if attr1.mode() != 2 {
			continue
		}

		attr2 := u16(p.oam[i << 1] >> 16)

		if !attr1.has(.affine_enable) && attr1.has(.invisible_or_double) {
			continue
		}

		ly := p.vcount & 0xFF
		y := i8(attr1.y())
		y_size := match attr1.shape() {
			0 { shape_length[1][attr2 >> 14] }
			1 { shape_length[0][attr2 >> 14] }
			2 { shape_length[2][attr2 >> 14] }
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
			0 { shape_length[1][attr2 >> 14] }
			1 { shape_length[2][attr2 >> 14] }
			2 { shape_length[0][attr2 >> 14] }
			else { 0 }
		}

		if !attr1.has(.affine_enable) {
			p.calculate_text_obj(mut winflags, i, ly, flipped_y, attr1.has(.palette),
				x_size)
		}
	}
}

fn (mut p Ppu) calculate_text_obj(mut winflags [240]WindowFlag, i int, ly int, flipped_y int, color_mode bool, x_size int) {
	winflag := unsafe { WindowFlag(u8(p.winout >> 8)) }
	attr2 := u16(p.oam[i << 1] >> 16)
	attr3 := u16(p.oam[i << 1 + 1])

	x := i16((attr2 & 0x1FF) << 7) >> 7
	for lx in 0 .. 240 {
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

		if !palette.is_transparent() {
			winflags[lx] = winflag
		}
	}
}
