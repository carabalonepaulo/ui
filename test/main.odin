package test

import "../ui"
import "core:c"
import "core:mem"
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

	ui.init(callbacks, 1024, 8 * mem.Megabyte)
	defer ui.deinit()

	rl.InitWindow(800, 600, "UI")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.WHITE)

		ui.begin_frame()
		defer ui.end_frame()

		// simple()
		row()
	}
}

simple :: proc() {
	ui.begin_scope({100, 100})
	ui.draw_rect(0, 0, 800, 600, transmute(ui.Color)(rl.RED))

	scope := ui.get_scope()
	scope.cursor += {75, 75}
	scope.offset += {25, 25}

	ui.begin_scope({50, 50})
	ui.draw_rect(0, 0, 800, 600, transmute(ui.Color)(rl.GREEN))
	ui.end_scope()

	ui.end_scope()
}

row :: proc() {
	row := ui.begin_row(
		{400, 100},
		{{.Absolute, 80}, {.Flex, 1}},
		gap = 8,
		padding = {16, 16, 16, 16},
	)
	defer ui.end_row()

	if ui.row_next(&row) {
		child_size := ui.get_available_size()
		ui.draw_rect(0, 0, child_size.x, child_size.y, transmute(ui.Color)(rl.RED))
	}

	if ui.row_next(&row) {
		child_size := ui.get_available_size()
		ui.draw_rect(0, 0, child_size.x, child_size.y, transmute(ui.Color)(rl.GREEN))
	}
}

