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
	ui.scope({100, 100})
	ui.draw_rect(0, 0, 800, 600, transmute(ui.Color)(rl.RED))

	scope := ui.get_scope()
	scope.cursor += {75, 75}
	scope.offset += {25, 25}

	ui.scope({50, 50})
	ui.draw_rect(0, 0, 800, 600, transmute(ui.Color)(rl.GREEN))
}

row :: proc() {
	ui.scope({400, 100})
	size := ui.get_available_size()
	ui.draw_rect(0, 0, size.x, size.y, transmute(ui.Color)(rl.GRAY))

	row := ui.row({400, 100}, {{.Absolute, 80}, {.Flex, 1}}, gap = 10, padding = {10, 10, 10, 10})

	if ui.next(&row) {
		child_size := ui.get_available_size()
		ui.draw_rect(0, 0, child_size.x, child_size.y, transmute(ui.Color)(rl.RED))

		col := ui.col(child_size, {{.Flex, 1}, {.Flex, 2}}, 10, {10, 10, 10, 10})

		if ui.next(&col) {
			child_size := ui.get_available_size()
			ui.draw_rect(0, 0, child_size.x, child_size.y, transmute(ui.Color)(rl.MAGENTA))
		}

		if ui.next(&col) {
			child_size := ui.get_available_size()
			ui.draw_rect(0, 0, child_size.x, child_size.y, transmute(ui.Color)(rl.BLUE))
		}
	}

	if ui.next(&row) {
		child_size := ui.get_available_size()
		ui.draw_rect(0, 0, child_size.x, child_size.y, transmute(ui.Color)(rl.GREEN))
	}
}

