module term_input

import strings

pub struct Color {
pub:
	r byte
	g byte
	b byte
}

pub fn (c Color) hex() string {
	return '#${c.r.hex()}${c.g.hex()}${c.b.hex()}'
}

// Synchronized Updates spec, designed to avoid tearing during renders
// https://gitlab.com/gnachman/iterm2/-/wikis/synchronized-updates-spec
const (
	bsu = '\x1bP=1s\x1b\\'
	esu = '\x1bP=2s\x1b\\'
)

[inline]
pub fn (mut ctx Context) write(s string) {
	if s == '' { return }
	ctx.print_buf.push_many(s.str, s.len)
}

[inline]
pub fn (mut ctx Context) flush() {
	// TODO: Diff the previous frame against this one, and only render things that changed?

	// ctx.set_cursor_position(0, 0)
	// ctx.write('$ctx.print_buf.len')
	// ctx.write('${ctx.print_buf[ctx.print_buf.len-50..].hex()}')
	C.write(C.STDOUT_FILENO, bsu.str, bsu.len)
	C.write(C.STDOUT_FILENO, ctx.print_buf.data, ctx.print_buf.len)
	C.write(C.STDOUT_FILENO, esu.str, esu.len)
	ctx.print_buf.clear()
}

[inline]
pub fn (mut ctx Context) bold() {
	ctx.write('\x1b[1m')
}

[inline]
pub fn (mut ctx Context) set_cursor_position(x int, y int) {
	ctx.write('\x1b[$y;${x}H')
}

[inline]
pub fn (mut ctx Context) set_color(c Color) {
	ctx.write('\x1b[38;2;${int(c.r)};${int(c.g)};${int(c.b)}m')
}

[inline]
pub fn (mut ctx Context) set_bg_color(c Color) {
	ctx.write('\x1b[48;2;${int(c.r)};${int(c.g)};${int(c.b)}m')
}

[inline]
pub fn (mut ctx Context) reset_color() {
	ctx.write('\x1b[39m')
}

[inline]
pub fn (mut ctx Context) reset_bg_color() {
	ctx.write('\x1b[49m')
}

[inline]
pub fn (mut ctx Context) reset() {
	ctx.write('\x1b[0m')
}

[inline]
pub fn (mut ctx Context) clear() {
	ctx.write('\x1b[1;1H\x1b[2J\x1b[3J')
}

// pub const (
// 	default_color = gx.rgb(183, 101, 94) // hopefully nobody actually tries to use this color...
// )

// pub struct DrawConfig {
// pub mut:
// 	fg_color gx.Color = default_color
// 	bg_color gx.Color = default_color
// }

[inline]
pub fn (mut ctx Context) draw_point(x int, y int) {
	ctx.set_cursor_position(x, y)
	ctx.write(' ')
}

[inline]
pub fn (mut ctx Context) draw_text(x int, y int, s string) {
	ctx.set_cursor_position(x, y)
	ctx.write(s)
}

pub fn (mut ctx Context) draw_line(x int, y int, x2 int, y2 int) {
	min_x, min_y := if x < x2 { x } else { x2 }, if y < y2 { y } else { y2 }
	max_x, _ := if x > x2 { x } else { x2 }, if y > y2 { y } else { y2 }

	if y == y2 {
		// Horizontal line, performance improvement
		ctx.set_cursor_position(min_x, min_y)
		ctx.write(strings.repeat(` `, max_x + 1 - min_x))
		return
	}

	// Draw the various points with Bresenham's line algorithm:
	mut x0, x1 := x, x2
	mut y0, y1 := y, y2

	sx := if x0 < x1 { 1 } else { -1 }
	sy := if y0 < y1 { 1 } else { -1 }
	dx := if x0 < x1 { x1 - x0 } else { x0 - x1 }
	dy := if y0 < y1 { y0 - y1 } else { y1 - y0 } // reversed

	mut err := dx + dy

	for {
		// res << Segment{ x0, y0 }
		ctx.draw_point(x0, y0)
		if x0 == x1 && y0 == y1 { break }
		e2 := 2 * err
		if e2 >= dy {
			err += dy
			x0 += sx
		}
		if e2 <= dx {
			err += dx
			y0 += sy
		}
	}
}

pub fn (mut ctx Context) draw_rect(x int, y int, x2 int, y2 int) {
	if y == y2 || x == x2 {
		ctx.draw_line(x, y, x2, y2)
		return
	}

	min_y, max_y := if y < y2 { y } else { y2 }, if y > y2 { y } else { y2 }

	for y_pos in min_y .. max_y + 1 {
		ctx.draw_line(x, y_pos, x2, y_pos)
	}
}

pub fn (mut ctx Context) draw_empty_rect(x int, y int, x2 int, y2 int) {
	if y == y2 || x == x2 {
		ctx.draw_line(x, y, x2, y2)
		return
	}

	ctx.draw_line(x,  y,  x2, y)
	ctx.draw_line(x,  y2, x2, y2)
	ctx.draw_line(x,  y,  x,  y2)
	ctx.draw_line(x2, y,  x2, y2)
}

[inline]
pub fn (mut ctx Context) horizontal_separator(y int) {
	ctx.set_cursor_position(0, y)
	ctx.write(strings.repeat(/* `⎽` */`-`, ctx.window_width))
}
