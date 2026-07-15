package ui

import "core:container/queue"
import "core:mem"

Texture :: distinct u64

Font :: distinct u64

Vec2 :: [2]f32

Rect :: [4]i32

Color :: [4]u8

Callbacks :: struct {
	get_delta_time:    proc() -> f64,
	get_default_font:  proc() -> Font,
	//
	load_texture:      proc(path: string) -> Texture,
	load_font:         proc(path: string) -> Font,
	//
	get_mouse_pos:     proc() -> Vec2,
	get_mouse_wheel:   proc() -> Vec2,
	//
	is_mouse_pressed:  proc(btn: Mouse_Button) -> bool,
	is_mouse_down:     proc(btn: Mouse_Button) -> bool,
	is_mouse_released: proc(btn: Mouse_Button) -> bool,
	is_mouse_up:       proc(btn: Mouse_Button) -> bool,
	is_key_pressed:    proc(key: Keyboard_Key) -> bool,
	is_key_down:       proc(key: Keyboard_Key) -> bool,
	is_key_released:   proc(key: Keyboard_Key) -> bool,
	is_key_up:         proc(key: Keyboard_Key) -> bool,
	//
	measure_text:      proc(font: Font, text: string, font_size: f32, spacing: f32) -> Vec2,
	//
	draw_text:         proc(font: Font, text: string, x, y, size, spacing: f32, color: Color),
	draw_rect:         proc(x, y, w, h: f32, color: Color),
	draw_texture:      proc(texture: Texture, src: [4]f32, dst: [4]f32, color: Color),
	//
	enable_scissors:   proc(x, y, w, h: i32),
	disable_scissors:  proc(),
}

Deferred_Kind :: enum {
	Pre,
	Post,
}

Deferred :: struct {
	fn: proc(ud: rawptr),
	ud: rawptr,
}

Popup :: struct {
	pos:  Vec2,
	size: Vec2,
	fn:   proc(),
}

Popup_With :: struct($T: typeid) {
	pos:  Vec2,
	size: Vec2,
	fn:   proc(arg: T),
	ud:   T,
}

Interest :: enum {
	Scroll_X,
	Scroll_Y,
	Hovered,
	Pressed,
	Pressed_Out,
	Released,
	Released_Out,
	Focused,
}

Interests :: bit_set[Interest]

Scope_Flag :: enum {
	Clip,
	Propagate_Content_Size,
	Pass_Through,
}

Scope_Flags :: bit_set[Scope_Flag]

Scope :: struct {
	parent:       int,
	screen_pos:   Vec2,
	pos:          Vec2,
	size:         Vec2,
	content_size: Vec2,
	offset:       Vec2,
	cursor:       Vec2,
	clip:         Rect,
	flags:        Scope_Flags,
	interests:    Interests,
}

Context :: struct {
	diagnostics:     Diagnostics,
	callbacks:       Callbacks,
	current_scope:   int,
	scope_count:     int,
	buffer:          []Scope,
	interest_buffer: [][Interest]rawptr,
	touched_buffer:  []Interests,
	//
	deferred_pre:    queue.Queue(Deferred),
	deferred_post:   queue.Queue(Deferred),
	//
	memory:          []u8,
	arena:           mem.Arena,
	arena_allocator: mem.Allocator,
	//
	store:           Store,
}

Anchor :: enum {
	Top_Left,
	Top,
	Top_Right,
	Left,
	Center,
	Right,
	Bottom_Left,
	Bottom,
	Bottom_Right,
}

Mouse_Button :: enum i32 {
	Left    = 0,
	Right   = 1,
	Middle  = 2,
	Side    = 3,
	Extra   = 4,
	Forward = 5,
	Back    = 6,
}

Keyboard_Key :: enum i32 {
	Null          = 0, // Key: NULL, used for no key pressed
	// Alphanumeric keys
	Apostrophe    = 39, // Key: '
	Comma         = 44, // Key: ,
	Minus         = 45, // Key: -
	Period        = 46, // Key: .
	Slash         = 47, // Key: /
	Zero          = 48, // Key: 0
	One           = 49, // Key: 1
	Two           = 50, // Key: 2
	Three         = 51, // Key: 3
	Four          = 52, // Key: 4
	Five          = 53, // Key: 5
	Six           = 54, // Key: 6
	Seven         = 55, // Key: 7
	Eight         = 56, // Key: 8
	Nine          = 57, // Key: 9
	Semicolon     = 59, // Key: ;
	Equal         = 61, // Key: =
	A             = 65, // Key: A | a
	B             = 66, // Key: B | b
	C             = 67, // Key: C | c
	D             = 68, // Key: D | d
	E             = 69, // Key: E | e
	F             = 70, // Key: F | f
	G             = 71, // Key: G | g
	H             = 72, // Key: H | h
	I             = 73, // Key: I | i
	J             = 74, // Key: J | j
	K             = 75, // Key: K | k
	L             = 76, // Key: L | l
	M             = 77, // Key: M | m
	N             = 78, // Key: N | n
	O             = 79, // Key: O | o
	P             = 80, // Key: P | p
	Q             = 81, // Key: Q | q
	R             = 82, // Key: R | r
	S             = 83, // Key: S | s
	T             = 84, // Key: T | t
	U             = 85, // Key: U | u
	V             = 86, // Key: V | v
	W             = 87, // Key: W | w
	X             = 88, // Key: X | x
	Y             = 89, // Key: Y | y
	Z             = 90, // Key: Z | z
	Left_Bracket  = 91, // Key: [
	Backslash     = 92, // Key: '\'
	Right_Bracket = 93, // Key: ]
	Grave         = 96, // Key: `
	// Function keys
	Space         = 32, // Key: Space
	Escape        = 256, // Key: Esc
	Enter         = 257, // Key: Enter
	Tab           = 258, // Key: Tab
	Backspace     = 259, // Key: Backspace
	Insert        = 260, // Key: Ins
	Delete        = 261, // Key: Del
	Right         = 262, // Key: Cursor right
	Left          = 263, // Key: Cursor left
	Down          = 264, // Key: Cursor down
	Up            = 265, // Key: Cursor up
	Page_Up       = 266, // Key: Page up
	Page_Down     = 267, // Key: Page down
	Home          = 268, // Key: Home
	End           = 269, // Key: End
	Caps_Lock     = 280, // Key: Caps lock
	Scroll_Lock   = 281, // Key: Scroll down
	Num_Lock      = 282, // Key: Num lock
	Print_Screen  = 283, // Key: Print screen
	Pause         = 284, // Key: Pause
	F1            = 290, // Key: F1
	F2            = 291, // Key: F2
	F3            = 292, // Key: F3
	F4            = 293, // Key: F4
	F5            = 294, // Key: F5
	F6            = 295, // Key: F6
	F7            = 296, // Key: F7
	F8            = 297, // Key: F8
	F9            = 298, // Key: F9
	F10           = 299, // Key: F10
	F11           = 300, // Key: F11
	F12           = 301, // Key: F12
	Left_Shift    = 340, // Key: Shift left
	Left_Control  = 341, // Key: Control left
	Left_Alt      = 342, // Key: Alt left
	Left_Super    = 343, // Key: Super left
	Right_Shift   = 344, // Key: Shift right
	Right_Control = 345, // Key: Control right
	Right_Alt     = 346, // Key: Alt right
	Right_Super   = 347, // Key: Super right
	KB_Menu       = 348, // Key: KB menu
	// Keypad keys
	KP_0          = 320, // Key: Keypad 0
	KP_1          = 321, // Key: Keypad 1
	KP_2          = 322, // Key: Keypad 2
	KP_3          = 323, // Key: Keypad 3
	KP_4          = 324, // Key: Keypad 4
	KP_5          = 325, // Key: Keypad 5
	KP_6          = 326, // Key: Keypad 6
	KP_7          = 327, // Key: Keypad 7
	KP_8          = 328, // Key: Keypad 8
	KP_9          = 329, // Key: Keypad 9
	KP_Decimal    = 330, // Key: Keypad .
	KP_Divide     = 331, // Key: Keypad /
	KP_Multiply   = 332, // Key: Keypad *
	KP_Subtract   = 333, // Key: Keypad -
	KP_Add        = 334, // Key: Keypad +
	KP_Enter      = 335, // Key: Keypad Enter
	KP_Equal      = 336, // Key: Keypad =
	// Android key buttons
	Back          = 4, // Key: Android back button
	Menuy         = 5, // Key: Android menu button
	Volume_Up     = 24, // Key: Android volume up button
	Volume_Down   = 25, // Key: Android volume down button
}

