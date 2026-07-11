package test

import "../ui"
import "core:c"
import rl "vendor:raylib"

main :: proc() {
	callbacks := ui.Callbacks {
		draw_rect = proc(x, y, w, h: f32, color: ui.Color) {
			rl.DrawRectangle(
				(c.int)(x),
				(c.int)(y),
				(c.int)(w),
				(c.int)(h),
				transmute(rl.Color)(color),
			)
		},
		enable_scissors = proc(x, y, w, h: f32) {
			rl.BeginScissorMode((c.int)(x), (c.int)(y), (c.int)(w), (c.int)(h))
		},
		disable_scissors = proc() {
			rl.EndScissorMode()
		},
	}

	ctx: ui.Context
	ui.init(&ctx, callbacks, 1024)
	defer ui.deinit(&ctx)

	rl.InitWindow(800, 600, "UI")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.WHITE)

		ui.begin_frame(&ctx)
		defer ui.end_frame(&ctx)

		ui.begin_scope(&ctx, {100, 100})
		ui.draw_rect(&ctx, 0, 0, 800, 600, transmute(ui.Color)(rl.RED))

		scope := ui.get_scope(&ctx)
		scope.cursor += {75, 75}
		scope.offset += {25, 25}

		ui.begin_scope(&ctx, {50, 50})
		ui.draw_rect(&ctx, 0, 0, 800, 600, transmute(ui.Color)(rl.GREEN))
		ui.end_scope(&ctx)

		ui.end_scope(&ctx)
	}
}

