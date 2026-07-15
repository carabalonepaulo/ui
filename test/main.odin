package test

import "../ui"
import "core:c"
import "core:fmt"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

FIRST_TAB :: 1

scroll_modifier: f32 = 5

CALLBACKS :: ui.Callbacks {
	get_delta_time = proc() -> f64 {
		return rl.GetTime()
	},
	get_default_font = proc() -> ui.Font {
		return 0
	},
	measure_text = proc(font: ui.Font, text: string, font_size: f32, spacing: f32) -> ui.Vec2 {
		default := rl.GetFontDefault()
		text_cstr := strings.clone_to_cstring(text, ui.get_temp_allocator())
		return transmute(ui.Vec2)(rl.MeasureTextEx(default, text_cstr, font_size, spacing))
	},
	//
	get_mouse_pos = proc() -> ui.Vec2 {
		return transmute(ui.Vec2)(rl.GetMousePosition())
	},
	get_mouse_wheel = proc() -> ui.Vec2 {
		return transmute(ui.Vec2)(rl.GetMouseWheelMoveV()) * scroll_modifier
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
	draw_text = proc(font: ui.Font, text: string, x, y, size, spacing: f32, color: ui.Color) {
		default := rl.GetFontDefault()
		text_cstr := strings.clone_to_cstring(text, ui.get_temp_allocator())
		rl.DrawTextEx(default, text_cstr, {x, y}, size, spacing, transmute(rl.Color)(color))
	},
	//
	enable_scissors = proc(x, y, w, h: i32) {
		rl.BeginScissorMode(x, y, w, h)
	},
	disable_scissors = proc() {
		rl.EndScissorMode()
	},
}

main :: proc() {
	ui.init(CALLBACKS, 1_005_000, 8 * mem.Megabyte)
	defer ui.deinit()

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1280, 720, "UI")
	defer rl.CloseWindow()

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		defer rl.EndDrawing()

		rl.ClearBackground({150, 150, 150, 255})

		ui.frame()

		w, h := f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())
		ui.scope({w, h})

		tabs([]Tab{{"Layout", layout_tab}, {"Text", text_tab}})

		debug := ui.get(ui.id("debug"), bool, false)
		if rl.IsKeyPressed(.D) do debug^ = !(debug^)
		if debug^ do ui.popup({0, 0}, {f32(w), f32(h)}, ui.profiler)
	}
}

Tab :: struct {
	text: string,
	comp: proc(),
}

tabs :: proc(tabs: []Tab) {
	State :: struct {
		hover:   bool,
		pressed: bool,
	}

	font_color := ui.Color{255, 255, 255, 200}
	font_size: f32 = 20
	spacing: f32 = 1
	padding: f32 = 10

	tab_bg_color: ui.Color = {31, 31, 31, 255}
	tab_bg_hover_color: ui.Color = {41, 41, 41, 255}

	content_bg_color: ui.Color = {21, 21, 21, 255}

	size := ui.get_available_size()
	ui.draw_rect(0, 0, size.x, size.y, tab_bg_color)

	current := ui.get(ui.id("root/tabs/current"), int, FIRST_TAB)

	destroy_constraints := proc(constraints: ^[]ui.Layout_Item) {delete(constraints^)}
	constraints, just_created := ui.get(
		ui.id("root/tabs/constraints"),
		[]ui.Layout_Item,
		destroy = destroy_constraints,
	)
	if just_created {
		slice := make([]ui.Layout_Item, len(tabs))
		for i in 0 ..< len(slice) {
			text_size := ui.ctx.callbacks.measure_text(0, tabs[i].text, font_size, spacing)
			slice[i] = {.Absolute, text_size.x + padding * 2}
		}
		constraints^ = slice
	}

	destroy_state := proc(hover: ^[]State) {delete(hover^)}
	state, state_just_created := ui.get(ui.id("root/tabs/hover"), []State, destroy = destroy_state)
	if state_just_created do state^ = make([]State, len(tabs))

	c := ui.col(ui.id("root/tabs"), size, {{.Absolute, font_size + (padding * 2)}, {.Flex, 1}})
	if ui.next(&c) {
		size := ui.get_available_size()
		r := ui.row(ui.id("root/tabs/row"), size, constraints^)
		for i in 0 ..< len(tabs) {
			if ui.next(&r) {
				ui.bind(.Hovered, &state[i].hover)
				ui.bind(.Pressed, &state[i].pressed)

				size := ui.get_available_size()
				ui.draw_rect(
					0,
					0,
					size.x,
					size.y,
					state[i].hover ? tab_bg_hover_color : tab_bg_color,
				)
				ui.draw_text(0, tabs[i].text, padding, padding, font_size, spacing, font_color)
			}
		}
	}

	if ui.next(&c) {
		size := ui.get_available_size()
		ui.draw_rect(0, 0, size.x, size.y, content_bg_color)
		tabs[current^].comp()
	}

	for i in 0 ..< len(tabs) {
		if state[i].pressed {
			current^ = i
			break
		}
	}
}

layout_tab :: proc() {
	size := ui.get_available_size()
	r := ui.row(ui.id("root"), size, {{.Flex, 1}, {.Flex, 1}}, 32)

	if ui.next(&r) {
		c := ui.col(
			ui.id("root/col"),
			ui.get_available_size(),
			{{.Flex, 1}, {.Flex, 1}, {.Flex, 1}},
			32,
		)
		if ui.next(&c) do simple()
		if ui.next(&c) do wrap()
		if ui.next(&c) do row()
	}

	if ui.next(&r) {
		size := ui.get_available_size()
		c := ui.col(ui.id("root/right/col"), size, {{.Flex, 1}, {.Flex, 1}, {.Flex, 1}})
		if ui.next(&c) do center()
		if ui.next(&c) do huge_list()
		if ui.next(&c) do list()
	}
}

text_tab :: proc() {
	ui.scope({200, 100})
	size := ui.get_available_size()
	ui.draw_rect(0, 0, size.x, size.y, {255, 255, 255, 255})

	opts := ui.Text_Options {
		wrap           = .Letter,
		letter_spacing = 1,
		line_spacing   = 10,
		font           = 0,
		font_size      = 20,
		font_color     = {0, 0, 0, 255},
	}
	ui.text(
		ui.id("tab/text"),
		{200, ui.AUTO},
		"Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc posuere sed ex dignissim luctus. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aliquam ac elementum lorem.",
		opts,
	)
}

profiler :: proc() {
	size := ui.get_available_size()
	ui.profiler()
}

Simple_State :: struct {
	is_hovered:      bool,
	is_pressed:      bool,
	is_pressed_out:  bool,
	is_released:     bool,
	is_released_out: bool,
	is_hover_popup:  bool,
	popup_visible:   bool,
}

simple :: proc() {
	ui.scope({100, 100}, {.Clip})
	ui.draw_rect(0, 0, 800, 600, transmute(ui.Color)(rl.RED))

	scope := ui.get_scope()
	scope.cursor += {75, 75}
	scope.offset += {25, 25}

	state := ui.get(ui.id("simple_state"), Simple_State)

	ui.scope({50, 50})
	ui.bind(.Hovered, &state.is_hovered)
	ui.bind(.Pressed, &state.is_pressed)
	ui.bind(.Pressed_Out, &state.is_pressed_out)
	ui.bind(.Released, &state.is_released)
	ui.bind(.Released_Out, &state.is_released_out)

	color := state.is_hovered ? rl.GREEN : rl.MAGENTA
	ui.draw_rect(0, 0, 800, 600, transmute(ui.Color)(color))

	if state.is_hovered do state.popup_visible = true

	if state.popup_visible {
		anchor := ui.get_anchor(.Bottom_Left)
		ui.popup_with_poly(anchor, {100, 100}, state, proc(state: ^Simple_State) {
			ui.bind(.Hovered, &state.is_hover_popup)
			size := ui.get_available_size()
			color := state.is_hover_popup ? rl.RED : rl.PURPLE
			ui.draw_rect(0, 0, size.x, size.y, transmute(ui.Color)(color))
			ui.draw_text(0, "hello", 0, 0, 20, 1, transmute(ui.Color)(rl.BLACK))
		})
		if !state.is_hover_popup && !state.is_hovered do state.popup_visible = false
	}

	if state.is_pressed do fmt.println("is pressed / hover =", state.is_hovered)
	if state.is_pressed_out do fmt.println("is pressed out / hover =", state.is_hovered)
	if state.is_released do fmt.println("is released / hover =", state.is_hovered)
	if state.is_released_out do fmt.println("is released out / hover =", state.is_hovered)
}

row :: proc() {
	ui.scope(ui.get_available_size())
	size := ui.get_available_size()
	ui.draw_rect(0, 0, size.x, size.y, transmute(ui.Color)(rl.GRAY))

	row := ui.row(
		ui.id("main/row"),
		size,
		{{.Flex, 1}, {.Flex, 5}},
		gap = 10,
		padding = {10, 10, 10, 10},
	)

	if ui.next(&row) {
		child_size := ui.get_available_size()
		ui.draw_rect(0, 0, child_size.x, child_size.y, transmute(ui.Color)(rl.RED))

		col := ui.col(
			ui.id("main/row", 1),
			child_size,
			{{.Flex, 1}, {.Flex, 2}},
			10,
			{10, 10, 10, 10},
		)

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

	w := ui.wrap(ui.id("main/wrap"), size, gap = {8, 8}, padding = {12, 12, 12, 12})

	scroll_y := ui.get(ui.id("main/wrap/scroll_y"), f32, 0.0)
	ui.bind(.Scroll_Y, scroll_y)

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

Center_State :: struct {
	parent_hover: bool,
	child_hover:  bool,
}

center :: proc() {
	state := ui.get(ui.id("root/center/state"), Center_State)
	ui.bind(.Hovered, &state.parent_hover)

	size := ui.get_available_size()
	bg_color := state.parent_hover ? ui.Color({0, 0, 0, 255}) : ui.Color({50, 50, 50, 255})
	ui.draw_rect(0, 0, size.x, size.y, bg_color)

	{
		c := ui.center(ui.id("root/center"))
		if ui.next(&c) {
			ui.scope({100, 100}, {.Pass_Through})
			ui.bind(.Hovered, &state.child_hover)

			size := ui.get_available_size()
			bg_color :=
				state.child_hover ? ui.Color({200, 200, 200, 255}) : ui.Color({200, 50, 50, 255})
			ui.draw_rect(0, 0, size.x, size.y, bg_color)
		}
	}

	ui.scope({32, 32})
	size = ui.get_available_size()
	ui.draw_rect(0, 0, size.x, size.y, {200, 0, 20, 255})
}

huge_list :: proc() {
	size := ui.get_available_size()
	ui.draw_rect(0, 0, size.x, size.y, {40, 40, 40, 255})

	count := 10_000

	states, states_just_created := ui.get(
		ui.id("huge_list/states"),
		[]bool,
		destroy = proc(states: ^[]bool) {delete(states^)},
	)
	if states_just_created do states^ = make([]bool, count)

	constraints, just_created := ui.get(
		ui.id("huge_list/constraints"),
		[]ui.Layout_Item,
		destroy = proc(constraints: ^[]ui.Layout_Item) {delete(constraints^)},
	)
	if just_created {
		list := make([]ui.Layout_Item, count)
		for i in 0 ..< count do list[i] = {.Absolute, 20}
		constraints^ = list
	}

	ui.scope(size, {.Clip})
	offset := ui.get(ui.id("huge_list/offset"), f32)
	ui.bind(.Scroll_Y, offset)

	c := ui.col(ui.id("huge_list/col"), {size.x, ui.AUTO}, constraints^)
	for i in 0 ..< count {
		if ui.next(&c) {
			size := ui.get_available_size()

			if !ui.is_visible() do continue
			ui.bind(.Hovered, &states[i])

			if states[i] do scroll_modifier = 100

			color: ui.Color = i % 2 == 0 ? {255, 255, 255, 255} : {100, 100, 100, 255}
			color = states[i] ? {255, 0, 0, 255} : color

			ui.draw_rect(0, 0, size.x, size.y, color)
			scope := ui.get_scope()
			ui.draw_text(
				0,
				fmt.aprintf("%d - %v", i, scope.clip, allocator = ui.get_temp_allocator()),
				0,
				0,
				20,
				1,
				{0, 0, 0, 255},
			)
		}
	}
}

list :: proc() {
	count := 100_000

	State :: struct {
		text:     string,
		is_hover: bool,
	}

	destroy_items := proc(items: ^[]State) {
		for item in items^ do delete(item.text)
		delete(items^)
	}
	items, just_created := ui.get(ui.id("list/items"), []State, destroy = destroy_items)
	if just_created {
		slice := make([]State, count)
		for i in 0 ..< count do slice[i].text = fmt.aprintf("%v", i)
		items^ = slice
	}

	ui.list_with_poly(ui.id("list"), ui.get_available_size(), count, 20, 10, items, proc(i: int, items: ^[]State) {
		ui.bind(.Hovered, &items[i].is_hover)

		if items[i].is_hover do scroll_modifier = 5

		color: ui.Color = i % 2 == 0 ? {255, 255, 255, 255} : {100, 100, 100, 255}
		color = items[i].is_hover ? {255, 0, 0, 255} : color

		size := ui.get_available_size()
		ui.draw_rect(0, 0, size.x, size.y, color)
		ui.draw_text(0, items[i].text, 0, 0, 20, 1, {0, 0, 0, 255})
	})
}

