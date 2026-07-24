package test

import "../ui"
import "core:c"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import rl "vendor:raylib"

FIRST_TAB :: 0

scroll_modifier: f32 = 5

CALLBACKS :: ui.Callbacks {
	get_delta_time = proc() -> f64 {
		return rl.GetTime()
	},
	get_default_font = proc() -> ui.Font {
		return 0
	},
	measure_text = proc(font: ui.Font, text: string, font_size: f64, spacing: f64) -> ui.Vec2 {
		default := rl.GetFontDefault()
		text_cstr := strings.clone_to_cstring(text, ui.get_temp_allocator())
		size := rl.MeasureTextEx(default, text_cstr, f32(font_size), f32(spacing))
		return ui.Vec2{f64(size.x), f64(size.y)}
	},
	//
	get_mouse_pos = proc() -> ui.Vec2 {
		pos := rl.GetMousePosition()
		return ui.Vec2{f64(pos.x), f64(pos.y)}
	},
	get_mouse_wheel = proc() -> ui.Vec2 {
		@(static) current_offset: f32 = 0.0
		@(static) target_offset: f32 = 0.0
		@(static) velocity: f32 = 0.0
		@(static) last_time: f32 = 0.0

		now := f32(rl.GetTime())
		dt := now - last_time if last_time > 0.0 else rl.GetFrameTime()
		last_time = now

		if dt <= 0.0 || dt > 0.1 do dt = 1.0 / 60.0

		wheel_raw := rl.GetMouseWheelMoveV().y

		scroll_impulse_scale: f32 = 20.0 + scroll_modifier

		if wheel_raw != 0.0 {
			target_offset += wheel_raw * scroll_impulse_scale
		}

		stiffness :: 150.0
		damping :: 25.0

		force := (target_offset - current_offset) * stiffness - velocity * damping
		velocity += force * dt

		prev_offset := current_offset
		current_offset += velocity * dt

		dist_to_target := abs(target_offset - current_offset)
		if wheel_raw == 0.0 && (dist_to_target < 0.5) {
			current_offset = target_offset
			velocity = 0.0
		}

		frame_delta := current_offset - prev_offset

		if wheel_raw == 0.0 && dist_to_target < 0.1 {
			current_offset = 0.0
			target_offset = 0.0
			velocity = 0.0
		}

		return ui.Vec2{0, f64(frame_delta)}
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
	draw_rect = proc(x, y, w, h: f64, color: ui.Color) {
		rl.DrawRectangle(
			(c.int)(math.floor(x)),
			(c.int)(math.floor(y)),
			(c.int)(math.ceil(w)),
			(c.int)(math.ceil(h)),
			transmute(rl.Color)(color),
		)
	},
	draw_text = proc(font: ui.Font, text: string, x, y, size, spacing: f64, color: ui.Color) {
		default := rl.GetFontDefault()
		text_cstr := strings.clone_to_cstring(text, ui.get_temp_allocator())
		rl.DrawTextEx(
			default,
			text_cstr,
			[2]f32{f32(x), f32(y)},
			f32(size),
			f32(spacing),
			transmute(rl.Color)(color),
		)
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
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	context.allocator = mem.tracking_allocator(&track)
	defer {
		if len(track.allocation_map) > 0 {
			fmt.println("[track] leaks")
			for _, value in track.allocation_map {
				fmt.printfln("- %v bytes at %v", value.size, value.location)
			}
		}

		if len(track.bad_free_array) > 0 {
			fmt.println("[track] bad free")
			for value in track.bad_free_array {
				fmt.printfln("- %v", value.location)
			}
		}

		mem.tracking_allocator_destroy(&track)
	}

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

		w, h := f64(rl.GetScreenWidth()), f64(rl.GetScreenHeight())
		ui.scope({w, h})

		tabs({{"Layout", layout_tab}, {"Grid", grid_tab}, {"Text", text_tab}})

		debug := ui.get(ui.id("debug"), bool, false)
		if rl.IsKeyPressed(.D) do debug^ = !(debug^)
		if debug^ do ui.popup({}, {f64(w), f64(h)}, ui.profiler)
	}
}

Tab :: struct {
	text: string,
	fn:   proc(),
}

tabs :: proc(tabs: []Tab) {
	State :: struct {
		hover:   bool,
		pressed: bool,
	}

	LABEL_SIZE :: ui.Vec2{ui.AUTO, ui.AUTO}
	PADDING :: ui.Padding{10, 20, 10, 20}
	BG_COLOR :: ui.Color{31, 31, 31, 255}
	BG_HOVER_COLOR :: ui.Color{41, 41, 41, 255}
	CONTENT_BG_COLOR :: ui.Color{21, 21, 21, 255}

	current := ui.get(ui.id("root/tabs/current"), int, FIRST_TAB)

	destroy_state := proc(hover: ^[]State) {delete(hover^)}
	state, state_just_created := ui.get(ui.id("root/tabs/hover"), []State, destroy = destroy_state)
	if state_just_created do state^ = make([]State, len(tabs))

	opts := ui.Text_Options {
		letter_spacing = 1,
		font_color     = {255, 255, 255, 200},
		font_size      = 20,
	}

	constraints := []ui.Layout_Item {
		{.Absolute, opts.font_size + ui.measure_padding(PADDING, .Y)},
		{.Flex, 1},
	}
	c := ui.flex(ui.get_available_size(), .Y, constraints)
	if ui.next(&c) {
		ui.fill_rect(BG_COLOR)
		s := ui.stack(ui.id("root/tabs/stack"), .X)
		for tab, i in tabs {
			id := ui.id("root/tabs/label", i)

			ui.next(&s, ui.measure_text(id, LABEL_SIZE, tab.text, &opts, PADDING))
			ui.bind(.Hovered, &state[i].hover)
			ui.bind(.Pressed, &state[i].pressed)

			if state[i].hover do ui.fill_rect(BG_HOVER_COLOR)

			ui.padding(PADDING)
			ui.text(id, LABEL_SIZE, tab.text, opts)
		}
	}

	if ui.next(&c) {
		ui.fill_rect(CONTENT_BG_COLOR)
		tabs[current^].fn()
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
	r := ui.flex(size, .X, {{.Flex, 1}, {.Flex, 1}}, 64)

	if ui.next(&r) {
		size := ui.get_available_size()
		c := ui.flex(size, .Y, {{.Flex, 1}, {.Flex, 1}, {.Flex, 1}}, 64)
		if ui.next(&c) {
			r := ui.flex(ui.get_available_size(), .X, {{.Flex, 1}, {.Flex, 1}})
			if ui.next(&r) do simple()
			if ui.next(&r) do stack()
		}
		if ui.next(&c) do wrap()
		if ui.next(&c) do row()
	}

	if ui.next(&r) {
		size := ui.get_available_size()
		f := ui.flex(size, .Y, {{.Flex, 1}, {.Flex, 1}, {.Flex, 1}}, gap = 10)
		if ui.next(&f) do center()
		if ui.next(&f) do huge_list()
		if ui.next(&f) do list()
	}
}

text_tab :: proc() {
	ui.scope_at({10, 10}, {210, 100})
	ui.fill_rect({255, 255, 255, 255})
	ui.padding({10, 10, 10, 10})

	opts := ui.Text_Options {
		scroll         = .Y,
		wrap           = .Word,
		letter_spacing = 1,
		line_spacing   = 10,
		font           = 0,
		font_size      = 20,
		font_color     = {0, 0, 0, 255},
	}

	id := ui.id("tab/text")
	size := ui.get_available_size()
	text := "aoisdjhaiodhaisodhioahdioashdioashdioahdioashdioashdioadhaiosdhaiosd Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nunc posuere sed ex dignissim luctus. Orci varius natoque penatibus et magnis dis parturient montes, nascetur ridiculus mus. Aliquam ac elementum lorem."

	text_size := ui.measure(id, size, text, &opts, {10, 10, 10, 10})
	ui.draw_rect({-10, -10}, text_size, {255, 0, 0, 50})

	ui.text(id, size, text, opts, {.Clip})
}

grid_tab :: proc() {
	COUNT :: 100_000
	GAP :: 20

	@(static) hover: [COUNT]bool

	ui.padding({GAP, GAP, GAP, GAP})
	ui.grid_with_poly(
		ui.id("tabs/grid"),
		ui.get_available_size(),
		COUNT,
		{180, 240},
		GAP,
		hover[:],
		proc(i: int, hover: []bool) {
			ui.bind(.Hovered, &hover[i])
			bg_color: ui.Color = hover[i] ? {55, 109, 176, 50} : {191, 70, 54, 50}
			ui.fill_rect(bg_color)

			ui.draw_text(
				0,
				fmt.aprintf("%v", i, allocator = ui.get_temp_allocator()),
				{0, 0},
				20,
				1,
				{255, 255, 255, 255},
			)
		},
		{.Clip},
	)
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
	ui.draw_rect({}, {800, 600}, auto_cast rl.RED)

	scope := ui.get_scope()
	scope.cursor += {75, 75}
	scope.offset += {25, 25}

	state := ui.get(ui.id("simple_state"), Simple_State)

	ui.scope({50, 50}, {.Clip})
	ui.bind(.Hovered, &state.is_hovered)
	ui.bind(.Pressed, &state.is_pressed)
	ui.bind(.Pressed_Out, &state.is_pressed_out)
	ui.bind(.Released, &state.is_released)
	ui.bind(.Released_Out, &state.is_released_out)

	color := state.is_hovered ? rl.GREEN : rl.MAGENTA
	ui.draw_rect({}, {800, 600}, auto_cast color)

	if state.is_hovered do state.popup_visible = true

	if state.popup_visible {
		anchor := ui.get_anchor(.Bottom_Left)
		ui.popup_with_poly(anchor, {100, 100}, state, proc(state: ^Simple_State) {
			ui.bind(.Hovered, &state.is_hover_popup)
			color := state.is_hover_popup ? rl.RED : rl.PURPLE
			ui.fill_rect(auto_cast color)
			ui.draw_text(0, "hello", {}, 20, 1, auto_cast rl.BLACK)
		})
		if !state.is_hover_popup && !state.is_hovered do state.popup_visible = false
	}

	if state.is_pressed do fmt.println("is pressed / hover =", state.is_hovered)
	if state.is_pressed_out do fmt.println("is pressed out / hover =", state.is_hovered)
	if state.is_released do fmt.println("is released / hover =", state.is_hovered)
	if state.is_released_out do fmt.println("is released out / hover =", state.is_hovered)
}

stack :: proc() {
	size := ui.get_available_size()
	ui.draw_rect({}, size, {255, 255, 0, 255})

	stack := ui.stack(ui.id("root/stack"), .X, 10, {.Clip})
	for i in 1 ..= 3 {
		if ui.next(&stack, {40, f64(i) * 40 / 2}) {
			size := ui.get_available_size()
			ui.draw_rect({}, size, {0, 255, 0, 255})
		}
	}
}

row :: proc() {
	ui.scope(ui.get_available_size())
	ui.fill_rect(auto_cast rl.GRAY)

	row := ui.flex(ui.get_available_size(), .X, {{.Flex, 1}, {.Flex, 5}}, gap = 10)

	if ui.next(&row) {
		ui.fill_rect(auto_cast rl.RED)
		ui.padding({10, 10, 10, 10})

		col := ui.flex(ui.get_available_size(), .Y, {{.Flex, 1}, {.Flex, 2}}, 10)
		if ui.next(&col) do ui.fill_rect(auto_cast rl.MAGENTA)
		if ui.next(&col) do ui.fill_rect(auto_cast rl.BLUE)
	}

	if ui.next(&row) {
		ui.fill_rect(auto_cast rl.GREEN)

		ui.padding({10, 10, 10, 10})
		ui.fill_rect(auto_cast rl.MAGENTA)
	}
}

wrap :: proc() {
	ui.scope(ui.get_available_size())
	size := ui.get_available_size()

	w := ui.wrap(ui.id("main/wrap"), size, gap = {8, 8}, padding = {12, 12, 12, 12})

	scroll_y := ui.get(ui.id("main/wrap/scroll_y"), f64, 0.0)
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
			color := palette[index % len(palette)]
			ui.fill_rect(auto_cast color)
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

	bg_color := state.parent_hover ? ui.Color({0, 0, 0, 255}) : ui.Color({50, 50, 50, 255})
	ui.fill_rect(bg_color)

	{
		ui.center(ui.id("root/center"), {100, 100})

		ui.scope({100, 100}, {.Pass_Through})
		ui.bind(.Hovered, &state.child_hover)

		bg_color :=
			state.child_hover ? ui.Color({200, 200, 200, 255}) : ui.Color({200, 50, 50, 255})
		ui.fill_rect(bg_color)
	}

	ui.scope({64, 64})
	ui.fill_rect({200, 0, 20, 255})
}

huge_list :: proc() {
	size := ui.get_available_size()
	ui.draw_rect({}, size, {40, 40, 40, 255})

	COUNT :: 1_000_000

	states, states_just_created := ui.get(
		ui.id("huge_list/states"),
		[]bool,
		destroy = proc(states: ^[]bool) {delete(states^)},
	)
	if states_just_created do states^ = make([]bool, COUNT)

	ui.padding({10, 10, 10, 10})

	ui.scope(ui.get_available_size(), {.Clip})
	offset := ui.get(ui.id("huge_list/offset"), f64)
	ui.bind(.Scroll_Y, offset)

	s := ui.stack(ui.id("huge_list/stack"), .Y, 10)
	for i in 0 ..< COUNT {
		if ui.next(&s, {size.x, 20}) {
			size := ui.get_available_size()

			ui.bind(.Hovered, &states[i])
			if !ui.is_visible() do continue

			if states[i] do scroll_modifier = 100

			color: ui.Color = i % 2 == 0 ? {255, 255, 255, 255} : {100, 100, 100, 255}
			color = states[i] ? {255, 0, 0, 255} : color

			ui.fill_rect(color)
			scope := ui.get_scope()
			ui.draw_text(
				0,
				fmt.aprintf("%d - %v", i, scope.clip, allocator = ui.get_temp_allocator()),
				{},
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

	ui.fill_rect({40, 40, 40, 255})
	ui.padding({10, 10, 10, 10})

	ui.list_with_poly(ui.id("list"), ui.get_available_size(), count, 20, 10, items, proc(i: int, items: ^[]State) {
		ui.bind(.Hovered, &items[i].is_hover)

		if items[i].is_hover do scroll_modifier = 5

		color: ui.Color = i % 2 == 0 ? {255, 255, 255, 255} : {100, 100, 100, 255}
		color = items[i].is_hover ? {255, 0, 0, 255} : color

		ui.fill_rect(color)
		ui.draw_text(0, items[i].text, {}, 20, 1, {0, 0, 0, 255})
	})
}

