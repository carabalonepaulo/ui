package test

import "../ui"
import "core:c"
import "core:fmt"
import "core:mem"
import rl "vendor:raylib"

CALLBACKS :: ui.Callbacks {
	get_mouse_pos = proc() -> ui.Vec2 {
		return transmute(ui.Vec2)(rl.GetMousePosition())
	},
	get_mouse_wheel = proc() -> ui.Vec2 {
		return transmute(ui.Vec2)(rl.GetMouseWheelMoveV())
	},
	//
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
	//
	draw_rect = proc(x, y, w, h: f32, color: ui.Color) {
		rl.DrawRectangle(
			(c.int)(x),
			(c.int)(y),
			(c.int)(w),
			(c.int)(h),
			transmute(rl.Color)(color),
		)
	},
	enable_scissors = proc(x, y, w, h: i32) {
		rl.BeginScissorMode(x, y, w, h)
	},
	disable_scissors = proc() {
		rl.EndScissorMode()
	},
}

main :: proc() {
	ui.init(CALLBACKS, 1024, 8 * mem.Megabyte)
	defer ui.deinit()

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1024, 720, "UI")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground(rl.WHITE)

		ui.begin_frame()
		defer ui.end_frame()

		w, h := rl.GetScreenWidth(), rl.GetScreenHeight()
		col := ui.col({f32(w), f32(h)}, {{.Flex, 1}, {.Flex, 1}, {.Flex, 1}}, 32)
		if ui.next(&col) do simple()
		if ui.next(&col) do row()
		if ui.next(&col) do wrap()
	}
}

is_hovered := false
is_pressed := false
is_pressed_out := false
is_released := false
is_released_out := false

simple :: proc() {
	ui.scope({100, 100}, {.Clip})
	ui.draw_rect(0, 0, 800, 600, transmute(ui.Color)(rl.RED))

	scope := ui.get_scope()
	scope.cursor += {75, 75}
	scope.offset += {25, 25}

	ui.scope({50, 50})
	ui.bind(.Hovered, &is_hovered)
	ui.bind(.Pressed, &is_pressed)
	ui.bind(.Pressed_Out, &is_pressed_out)
	ui.bind(.Released, &is_released)
	ui.bind(.Released_Out, &is_released_out)

	color := is_hovered ? rl.GREEN : rl.MAGENTA
	ui.draw_rect(0, 0, 800, 600, transmute(ui.Color)(color))

	if is_pressed do fmt.println("is pressed / hover =", is_hovered)
	if is_pressed_out do fmt.println("is pressed out / hover =", is_hovered)
	if is_released do fmt.println("is released / hover =", is_hovered)
	if is_released_out do fmt.println("is released out / hover =", is_hovered)
}

row :: proc() {
	ui.scope(ui.get_available_size())
	size := ui.get_available_size()
	ui.draw_rect(0, 0, size.x, size.y, transmute(ui.Color)(rl.GRAY))

	row := ui.row(size, {{.Absolute, 80}, {.Flex, 1}}, gap = 10, padding = {10, 10, 10, 10})

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

wrap :: proc() {
	ui.scope(ui.get_available_size())
	size := ui.get_available_size()
	ui.draw_rect(0, 0, size.x, size.y, transmute(ui.Color)(rl.GRAY))

	w := ui.wrap(size, gap = {8, 8}, padding = {12, 12, 12, 12})

	item_sizes := []ui.Vec2 {
		{70, 30},
		{120, 45},
		{60, 30},
		{150, 25},
		{90, 50},
		{80, 35},
		{110, 30},
		{130, 30},
		{50, 25},
	}

	palette := []rl.Color{rl.RED, rl.GREEN, rl.BLUE, rl.MAGENTA, rl.ORANGE, rl.LIME, rl.GOLD}

	for item_size, index in item_sizes {
		if ui.next(&w, item_size) {
			child_size := ui.get_available_size()

			color := palette[index % len(palette)]
			ui.draw_rect(0, 0, child_size.x, child_size.y, transmute(ui.Color)(color))
		}
	}
}

