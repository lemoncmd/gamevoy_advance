module ppu

type Color = u16

fn (c Color) red() u8 {
	base := u8(u16(c) & 0b11111)
	return (base << 3) | (base >> 2)
}

fn (c Color) green() u8 {
	base := u8((u16(c) >> 5) & 0b11111)
	return (base << 3) | (base >> 2)
}

fn (c Color) blue() u8 {
	base := u8((u16(c) >> 10) & 0b11111)
	return (base << 3) | (base >> 2)
}

struct Palette16 {
	palette u8
	number  u8
}

struct Palette256 {
	number u8
}

type Palette = Palette16 | Palette256

fn (p Palette) get_color_number() u8 {
	return match p {
		Palette16 { (p.palette << 4) | p.number }
		Palette256 { p.number }
	}
}

fn (p Palette) is_transparent() bool {
	return 0 == match p {
		Palette16, Palette256 { p.number }
	}
}

fn (p &Ppu) get_color_from_palette(is_obj_palette bool, palette Palette) Color {
	palette_address := (if is_obj_palette { 0x100 } else { 0 }) + palette.get_color_number()
	return Color(p.palette[palette_address])
}
