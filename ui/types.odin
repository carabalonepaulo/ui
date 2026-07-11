package ui

Vec2 :: [2]f32

Rect :: [4]f32

Color :: [4]u8

Callbacks :: struct {
	load_texture:      proc(),
	load_font:         proc(),
	//
	get_mouse_pos:     proc(),
	is_mouse_pressed:  proc(),
	is_mouse_down:     proc(),
	is_mouse_released: proc(),
	is_mouse_up:       proc(),
	is_key_pressed:    proc(),
	is_key_down:       proc(),
	is_key_released:   proc(),
	is_key_up:         proc(),
	//
	get_text_width:    proc(),
	//
	draw_text:         proc(),
	draw_rect:         proc(x, y, w, h: f32, color: Color),
	draw_texture:      proc(),
	//
	enable_scissors:   proc(x, y, w, h: f32),
	disable_scissors:  proc(),
}

Scope :: struct {
	parent:     int,
	screen_pos: Vec2,
	pos:        Vec2,
	size:       Vec2,
	offset:     Vec2,
	cursor:     Vec2,
	clip:       Rect,
}

Context :: struct {
	callbacks:     Callbacks,
	current_scope: int,
	scope_count:   int,
	buffer:        []Scope,
}

