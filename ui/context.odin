package ui

import "core:math"
import "core:mem"

ctx: Context

init_context :: proc(callbacks: Callbacks, cap: int, frame_memory: int) -> bool {
	memory, alloc_err := mem.alloc_bytes(frame_memory)
	if alloc_err != nil do return false

	ctx.memory = memory
	mem.arena_init(&ctx.arena, ctx.memory)
	ctx.arena_allocator = mem.arena_allocator(&ctx.arena)

	ctx.callbacks = callbacks
	ctx.buffer = make([]Scope, cap)
	ctx.current_scope = -1

	return true
}

deinit_context :: proc() {
	delete(ctx.buffer)
	ctx.buffer = nil
	ctx.current_scope = -1
	ctx.callbacks = {}
}

begin_frame :: proc() {
	ctx.current_scope = -1
	ctx.scope_count = 0
}

end_frame :: proc() {
	assert(ctx.current_scope == -1)
	mem.free_all(ctx.arena_allocator)
	process_input()
}

get_scope :: #force_inline proc() -> ^Scope {
	return &ctx.buffer[ctx.current_scope]
}

get_parent_scope :: #force_inline proc() -> ^Scope {
	return &ctx.buffer[ctx.buffer[ctx.current_scope].parent]
}

get_available_size :: #force_inline proc() -> Vec2 {
	assert(ctx.current_scope != -1)
	scope := &ctx.buffer[ctx.current_scope]

	return Vec2 {
		max(f32(0), scope.size.x - scope.cursor.x),
		max(f32(0), scope.size.y - scope.cursor.y),
	}
}

is_hovered :: proc() -> bool {
	assert(ctx.current_scope != -1, "invalid scope")
	scope := get_scope()
	assert(.Hovered in scope.interests, "scope must be bound to Interest.Hovered before querying")
	return (^bool)(scope.interests_ptrs[.Hovered])^
}

is_pressed :: proc() -> bool {
	assert(ctx.current_scope != -1, "invalid scope")
	scope := get_scope()
	assert(.Pressed in scope.interests, "scope must be bound to Interest.Pressed before querying")
	return (^bool)(scope.interests_ptrs[.Pressed])^
}

@(private)
process_input :: proc() {
	mouse_pos := ctx.callbacks.get_mouse_pos()
	wheel := ctx.callbacks.get_mouse_wheel()

	mouse_left_pressed := ctx.callbacks.is_mouse_pressed(.Left)
	mouse_left_down := ctx.callbacks.is_mouse_down(.Left)
	mouse_left_released := ctx.callbacks.is_mouse_released(.Left)

	scroll_consumed := false
	click_consumed := false
	focus_consumed := false

	for i := ctx.scope_count - 1; i >= 0; i -= 1 {
		scope := &ctx.buffer[i]
		if scope.interests == {} do continue

		if is_mouse_inside(scope, mouse_pos) {
			if .Hovered in scope.interests {
				set(scope, .Hovered, true)
			}

			if .Pressed in scope.interests && !click_consumed && mouse_left_pressed {
				set(scope, .Pressed, true)
				click_consumed = true
			}

			if .Scroll_Y in scope.interests && !scroll_consumed && wheel.y != 0 {
				current := get(scope, .Scroll_Y, f32) - wheel.y
				max_scroll := max(0, scope.content_size.y - scope.size.y)
				set(scope, .Scroll_Y, math.clamp(current, 0, max_scroll))
				scroll_consumed = true
			}

			if .Scroll_X in scope.interests && !scroll_consumed && wheel.x != 0 {
				current := get(scope, .Scroll_X, f32) - wheel.x
				max_scroll := max(0, scope.content_size.x - scope.size.x)
				set(scope, .Scroll_X, math.clamp(current, 0, max_scroll))
				scroll_consumed = true
			}
		} else {
			if .Hovered in scope.interests {
				set(scope, .Hovered, false)
			}
		}
	}
}

@(private = "file")
get :: #force_inline proc(scope: ^Scope, interest: Interest, $T: typeid) -> T {
	ptr := (^T)(scope.interests_ptrs[interest])
	return ptr == nil ? {} : ptr^
}

@(private = "file")
set :: #force_inline proc(scope: ^Scope, interest: Interest, value: $T) {
	ptr := (^T)(scope.interests_ptrs[interest])
	if ptr != nil do ptr^ = value
}

@(private = "file")
is_mouse_inside :: #force_inline proc(scope: ^Scope, pos: Vec2) -> bool {
	rect := [4]f32{f32(scope.clip[0]), f32(scope.clip[1]), f32(scope.clip[2]), f32(scope.clip[3])}
	return(
		pos.x >= rect[0] &&
		pos.x <= rect[0] + rect[2] &&
		pos.y >= rect[1] &&
		pos.y <= rect[1] + rect[3] \
	)
}

