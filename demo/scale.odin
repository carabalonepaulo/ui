package demo

import "core:math"
import ui "../ui"
import rl "vendor:raylib"

// Renders the UI into an offscreen target and blits it to the window.
//
// The UI itself always works in logical pixels. This helper is the only place
// that knows about the window and about physical (texture) pixels:
//
//   logical_size = texture_size / (ui_scale * render_scale)
//   pixels_per_unit = ui_scale * render_scale
//
// `render_scale > 1` renders the UI at a higher resolution than the window and
// downsamples it at the end (SSAA), which keeps text and edges crisp when the
// UI is scaled.
UIScale :: struct {
	ui_scale:     f64,
	render_scale: f64,
	dest_pos:     ui.Vec2,
	dest_size:    ui.Vec2,
	logical_size: ui.Vec2,
	ppu:          f64,
	target:       rl.RenderTexture2D,
	active:       bool,
}

ui_scale_init :: proc(s: ^UIScale, ui_scale: f64 = 1, render_scale: f64 = 2) {
	s.ui_scale = ui_scale
	s.render_scale = render_scale
}

ui_scale_deinit :: proc(s: ^UIScale) {
	if s.target.id != 0 {
		rl.UnloadRenderTexture(s.target)
		s.target = {}
	}
}

// Synchronises the target with the window. Returns true when the target was
// (re)created.
ui_scale_update :: proc(s: ^UIScale, dest_size: ui.Vec2) -> bool {
	dest_pos := ui.Vec2{0, 0}
	dest_size := ui.Vec2{max(1, dest_size.x), max(1, dest_size.y)}
	ui_scale := clamp(s.ui_scale, 0.25, 8)
	render_scale := clamp(s.render_scale, 1, 4)

	tex_w := max(1, i32(math.ceil(dest_size.x * render_scale)))
	tex_h := max(1, i32(math.ceil(dest_size.y * render_scale)))

	changed :=
		s.target.id == 0 ||
		s.dest_pos != dest_pos ||
		s.dest_size != dest_size ||
		s.render_scale != render_scale ||
		s.target.texture.width != tex_w ||
		s.target.texture.height != tex_h

	if changed {
		if s.target.id != 0 {
			rl.UnloadRenderTexture(s.target)
		}

		s.target = rl.LoadRenderTexture(tex_w, tex_h)
		assert(s.target.id != 0, "failed to create the UI render target")
		rl.SetTextureFilter(s.target.texture, .BILINEAR)
	}

	s.dest_pos = dest_pos
	s.dest_size = dest_size
	s.ui_scale = ui_scale
	s.render_scale = render_scale
	s.ppu = ui_scale * render_scale
	s.logical_size = {
		f64(s.target.texture.width) / s.ppu,
		f64(s.target.texture.height) / s.ppu,
	}

	return changed
}

ui_scale_begin :: proc(s: ^UIScale) {
	rl.BeginTextureMode(s.target)
	rl.ClearBackground(rl.BLANK)
	s.active = true
}

ui_scale_end :: proc(s: ^UIScale) {
	s.active = false
	rl.EndTextureMode()

	// Supersampling needs proper minification. GL_LINEAR alone only samples 4
	// texels around one point, which still aliases when downscaling by 2x.
	// Generating mipmaps makes TRILINEAR use the matching level instead.
	if s.render_scale > 1 {
		rl.GenTextureMipmaps(&s.target.texture)
		rl.SetTextureFilter(s.target.texture, .TRILINEAR)
	} else {
		rl.SetTextureFilter(s.target.texture, .BILINEAR)
	}

	source := rl.Rectangle {
		0,
		0,
		f32(s.target.texture.width),
		-f32(s.target.texture.height),
	}
	dest := rl.Rectangle {
		f32(s.dest_pos.x),
		f32(s.dest_pos.y),
		f32(s.dest_size.x),
		f32(s.dest_size.y),
	}

	rl.DrawTexturePro(s.target.texture, source, dest, {0, 0}, 0, rl.WHITE)
}

// Maps a window-space mouse position into logical UI space.
ui_scale_mouse_pos :: proc(s: ^UIScale) -> ui.Vec2 {
	pos := rl.GetMousePosition()
	x := f64(pos.x)
	y := f64(pos.y)

	if x < s.dest_pos.x || y < s.dest_pos.y ||
	   x > s.dest_pos.x + s.dest_size.x ||
	   y > s.dest_pos.y + s.dest_size.y {
		return {-1e9, -1e9}
	}

	return {
		(x - s.dest_pos.x) / s.dest_size.x * s.logical_size.x,
		(y - s.dest_pos.y) / s.dest_size.y * s.logical_size.y,
	}
}

ui_scale_draw_rect :: proc(s: ^UIScale, x, y, w, h: f64, color: ui.Color) {
	x0 := i32(math.round(x * s.ppu))
	y0 := i32(math.round(y * s.ppu))
	x1 := i32(math.round((x + w) * s.ppu))
	y1 := i32(math.round((y + h) * s.ppu))

	if x1 <= x0 || y1 <= y0 do return

	rl.DrawRectangle(x0, y0, x1 - x0, y1 - y0, transmute(rl.Color)(color))
}

ui_scale_enable_scissors :: proc(s: ^UIScale, x, y, w, h: i32) {
	if !s.active do return

	tw := i32(s.target.texture.width)
	th := i32(s.target.texture.height)

	px := i32(math.round(f64(x) * s.ppu))
	py := i32(math.round(f64(y) * s.ppu))
	pw := i32(math.round(f64(w) * s.ppu))
	ph := i32(math.round(f64(h) * s.ppu))

	if px < 0 {
		pw += px
		px = 0
	}
	if py < 0 {
		ph += py
		py = 0
	}

	px = clamp(px, 0, tw)
	py = clamp(py, 0, th)

	pw = clamp(pw, 0, tw - px)
	ph = clamp(ph, 0, th - py)

	// Raylib flips the Y coordinate against the current FBO height for us when
	// rendering into a RenderTexture, so pass top-left coordinates here.
	rl.BeginScissorMode(px, py, pw, ph)
}

ui_scale_disable_scissors :: proc(s: ^UIScale) {
	if s.active {
		rl.EndScissorMode()
	}
}
