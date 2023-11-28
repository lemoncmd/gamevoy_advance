module ppu

@[flag]
enum DispCnt as u16 {
	bgmode_0
	bgmode_1
	bgmode_2
	cgb_mode
	frame
	oam_enable_in_hblank
	obj_mapping_mode
	fblank
	bg0_enable
	bg1_enable
	bg2_enable
	bg3_enable
	obj_enable
	win0_enable
	win1_enable
	objwin_enable
}

fn DispCnt.from(val u16) DispCnt {
	return unsafe { DispCnt(val) }
}

fn (d DispCnt) bgmode() u8 {
	return u8(d) & 0b111
}

@[flag]
enum DispStat as u16 {
	vblank
	hblank
	vcounter
	vblank_int_enable
	hblank_int_enable
	vcounter_int_enable
}

fn DispStat.from(val u16) DispStat {
	return unsafe { DispStat(val) }
}

fn (d DispStat) lyc() u8 {
	return u8(u16(d) >> 8)
}
