module gameboy

import gg
import peripherals.joypad { Key }

fn key2joy(keycode gg.KeyCode) ?Key {
	return match keycode {
		.z { .a }
		.x { .b }
		.c { .start }
		.v { .@select }
		.up { .up }
		.down { .down }
		.left { .left }
		.right { .right }
		.a { .r }
		.f { .l }
		else { none }
	}
}

fn on_key_down(c gg.KeyCode, _ gg.Modifier, mut g Gameboy) {
	if k := key2joy(c) {
		g.on_key_down(k)
	}
}

fn on_key_up(c gg.KeyCode, _ gg.Modifier, mut g Gameboy) {
	if k := key2joy(c) {
		g.on_key_up(k)
	}
}
