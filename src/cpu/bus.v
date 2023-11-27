module cpu

import peripherals { Peripherals }

fn (mut c Cpu) read(bus &Peripherals, addr u32, size u32) ?u32 {
	match c.ctx.waitstates {
		0 {
			c.ctx.bus_value = bus.read(addr, size)
			c.ctx.waitstates = bus.cycle(addr, size, false)
			return c.read(bus, addr, size)
		}
		1 {
			c.ctx.waitstates--
			return c.ctx.bus_value
		}
		else {
			c.ctx.waitstates--
			return none
		}
	}
}

fn (mut c Cpu) write(mut bus Peripherals, addr u32, val u32, size u32) ? {
	match c.ctx.waitstates {
		0 {
			bus.write(addr, val, size)
			c.ctx.waitstates = bus.cycle(addr, size, false)
			return c.write(mut bus, addr, val, size)
		}
		1 {
			c.ctx.waitstates--
			return
		}
		else {
			c.ctx.waitstates--
			return none
		}
	}
}
