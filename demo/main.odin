package demo

import "core:fmt"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:strings"
import ui "../ui"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

FONT_REGULAR :: ui.Font(0)
FONT_BOLD :: ui.Font(1)

App :: struct {
	renderer:              Renderer,
	scale:                 UIScale,
	cards:                 []Card_State,
	grid_offset:           f64,
	view:                  int,
	pending_scale:         f64,
	pending_render_scale:  f64,
	wheel:                 Smooth_Wheel,
	screenshot_path:       string,
	screenshot_frames:     int,
}

app: App

Smooth_Wheel :: struct {
	current:  f64,
	target:   f64,
	velocity: f64,
}

// A small spring that turns discrete wheel notches into smooth pixel deltas.
// The target is clamped around the current position so it cannot accumulate an
// unbounded overscroll while the UI clamps the actual scroll offset.
smooth_wheel :: proc(w: ^Smooth_Wheel, step: f64) -> f64 {
	dt := f64(rl.GetFrameTime())
	if dt <= 0 || dt > 0.1 do dt = 1.0 / 60.0

	raw := f64(rl.GetMouseWheelMoveV().y)
	if raw != 0 {
		target := w.target + raw * step
		w.target = clamp(target, w.current - 160, w.current + 160)
	}

	stiffness := 150.0
	damping := 25.0
	force := (w.target - w.current) * stiffness - w.velocity * damping
	w.velocity += force * dt

	previous := w.current
	w.current += w.velocity * dt

	distance := abs(w.target - w.current)
	if raw == 0 && distance < 0.5 {
		w.current = w.target
		w.velocity = 0
	}

	delta := w.current - previous

	if raw == 0 && abs(w.target - w.current) < 0.1 {
		w.current = 0
		w.target = 0
		w.velocity = 0
	}

	return delta
}

CALLBACKS :: ui.Callbacks {
	get_delta_time = proc() -> f64 {
		return f64(rl.GetFrameTime())
	},
	get_default_font = proc() -> ui.Font {
		return app.renderer.default_font
	},
	measure_text = proc(font: ui.Font, text: string, font_size, spacing: f64) -> ui.Vec2 {
		ppu := app.scale.ppu
		if ppu <= 0 do ppu = 1

		size := renderer_measure(
			&app.renderer,
			font,
			text,
			font_size * ppu,
			spacing * ppu,
		)
		return {size.x / ppu, size.y / ppu}
	},
	get_mouse_pos = proc() -> ui.Vec2 {
		return ui_scale_mouse_pos(&app.scale)
	},
	get_mouse_wheel = proc() -> ui.Vec2 {
		step := 48.0 / max(app.scale.ui_scale, 0.25)
		return {0, smooth_wheel(&app.wheel, step)}
	},
	is_mouse_pressed = proc(btn: ui.Mouse_Button) -> bool {
		return rl.IsMouseButtonPressed(transmute(rl.MouseButton)(btn))
	},
	is_mouse_down = proc(btn: ui.Mouse_Button) -> bool {
		return rl.IsMouseButtonDown(transmute(rl.MouseButton)(btn))
	},
	is_mouse_released = proc(btn: ui.Mouse_Button) -> bool {
		return rl.IsMouseButtonReleased(transmute(rl.MouseButton)(btn))
	},
	is_mouse_up = proc(btn: ui.Mouse_Button) -> bool {
		return rl.IsMouseButtonUp(transmute(rl.MouseButton)(btn))
	},
	is_key_pressed = proc(key: ui.Keyboard_Key) -> bool {
		return rl.IsKeyPressed(transmute(rl.KeyboardKey)(key))
	},
	is_key_down = proc(key: ui.Keyboard_Key) -> bool {
		return rl.IsKeyDown(transmute(rl.KeyboardKey)(key))
	},
	is_key_released = proc(key: ui.Keyboard_Key) -> bool {
		return rl.IsKeyReleased(transmute(rl.KeyboardKey)(key))
	},
	is_key_up = proc(key: ui.Keyboard_Key) -> bool {
		return rl.IsKeyUp(transmute(rl.KeyboardKey)(key))
	},
	draw_rect = proc(x, y, w, h: f64, color: ui.Color) {
		ui_scale_draw_rect(&app.scale, x, y, w, h, color)
	},
	draw_text = proc(font: ui.Font, text: string, x, y, size, spacing: f64, color: ui.Color) {
		ppu := app.scale.ppu
		renderer_draw_text(
			&app.renderer,
			font,
			text,
			x * ppu,
			y * ppu,
			size * ppu,
			spacing * ppu,
			color,
		)
	},
	enable_scissors = proc(x, y, w, h: i32) {
		ui_scale_enable_scissors(&app.scale, x, y, w, h)
	},
	disable_scissors = proc() {
		ui_scale_disable_scissors(&app.scale)
	},
}

main :: proc() {
	ui_scale_init(&app.scale, 1, 2)
	parse_args()

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1180, 760, "Odin UI - demo")
	defer rl.CloseWindow()
	rl.SetWindowMinSize(1000, 650)
	rl.SetTargetFPS(60)

	// Mipmap generation logs at INFO every frame; warnings and errors still show.
	rl.SetTraceLogLevel(.WARNING)

	app.cards = make([]Card_State, CARD_COUNT)
	defer delete(app.cards)

	renderer_init(&app.renderer)
	defer renderer_deinit(&app.renderer)

	defer ui_scale_deinit(&app.scale)

	assert(ui.init(CALLBACKS, 65_536, 8 * mem.Megabyte), "failed to init ui")
	defer ui.deinit()

	for !rl.WindowShouldClose() {
		handle_keys()
		apply_pending()

		rl.BeginDrawing()
		rl.ClearBackground(transmute(rl.Color)(C_WINDOW_BG))
		ui_poll(app_draw)
		take_screenshot_if_requested()
		rl.EndDrawing()

		if app.screenshot_path != "" && app.screenshot_frames == 0 {
			break
		}

		free_all(context.temp_allocator)
	}
}

parse_args :: proc() {
	i := 1
	for i < len(os.args) {
		switch os.args[i] {
		case "--screenshot":
			if i + 1 < len(os.args) {
				app.screenshot_path = os.args[i + 1]
				app.screenshot_frames = 20
				i += 2
			} else {
				i += 1
			}
		case "--view":
			if i + 1 < len(os.args) {
				if view, ok := strconv.parse_int(os.args[i + 1], 10); ok {
					app.view = clamp(view, 0, NAV_COUNT - 1)
				}
				i += 2
			} else {
				i += 1
			}
		case "--scale":
			if i + 1 < len(os.args) {
				if value, ok := strconv.parse_f64(os.args[i + 1]); ok {
					app.scale.ui_scale = clamp(value, 0.5, 1.5)
				}
				i += 2
			} else {
				i += 1
			}
		case "--ssaa":
			if i + 1 < len(os.args) {
				if value, ok := strconv.parse_f64(os.args[i + 1]); ok {
					app.scale.render_scale = clamp(value, 1, 4)
				}
				i += 2
			} else {
				i += 1
			}
		case:
			i += 1
		}
	}
}

take_screenshot_if_requested :: proc() {
	if app.screenshot_frames <= 0 do return

	app.screenshot_frames -= 1
	if app.screenshot_frames == 0 {
		// The UI blit is still inside raylib's render batch.
		rlgl.DrawRenderBatchActive()

		image := rl.LoadImageFromScreen()
		path := strings.clone_to_cstring(app.screenshot_path, context.temp_allocator)
		ok := rl.ExportImage(image, path)
		rl.UnloadImage(image)

		if ok {
			fmt.println("screenshot written to", app.screenshot_path)
		} else {
			fmt.eprintln("failed to write screenshot to", app.screenshot_path)
		}
	}
}

handle_keys :: proc() {
	if rl.IsKeyPressed(.MINUS) || rl.IsKeyPressed(.KP_SUBTRACT) {
		app.pending_scale -= 0.25
	}
	if rl.IsKeyPressed(.EQUAL) || rl.IsKeyPressed(.KP_ADD) {
		app.pending_scale += 0.25
	}
	if rl.IsKeyPressed(.LEFT_BRACKET) {
		app.pending_render_scale -= 0.25
	}
	if rl.IsKeyPressed(.RIGHT_BRACKET) {
		app.pending_render_scale += 0.25
	}
	if rl.IsKeyPressed(.R) {
		app.pending_scale = 1 - app.scale.ui_scale
		app.pending_render_scale = 2 - app.scale.render_scale
	}
}

apply_pending :: proc() {
	if app.pending_scale != 0 {
		app.scale.ui_scale = clamp(app.scale.ui_scale + app.pending_scale, 0.5, 1.5)
		app.pending_scale = 0
	}
	if app.pending_render_scale != 0 {
		app.scale.render_scale = clamp(app.scale.render_scale + app.pending_render_scale, 1, 4)
		app.pending_render_scale = 0
	}
}

ui_poll :: proc(draw: proc(ud: rawptr), ud: rawptr = nil) {
	screen := ui.Vec2{f64(rl.GetScreenWidth()), f64(rl.GetScreenHeight())}
	ui_scale_update(&app.scale, screen)

	ui_scale_begin(&app.scale)
	{
		// Keep frame() and scope() in the same block: their deferred ends run
		// in reverse order here, before the target is unbound.
		ui.frame()
		ui.scope(app.scale.logical_size)
		draw(ud)
	}
	ui_scale_end(&app.scale)
}
