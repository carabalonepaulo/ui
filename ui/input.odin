package ui

import "core:math"

@(private)
process_input :: proc() {
	mouse_pos := ctx.callbacks.get_mouse_pos()
	wheel := ctx.callbacks.get_mouse_wheel().y

	mouse_left_pressed := ctx.callbacks.is_mouse_pressed(.Left)
	mouse_left_released := ctx.callbacks.is_mouse_released(.Left)

	target := resolve_target(mouse_pos)
	if target != -1 {
		scope := &ctx.buffer[target]

		propagate(target, .Hovered, true)

		if mouse_left_pressed do propagate(target, .Pressed, true)
		propagate(target, .Pressed_Out, false)

		if mouse_left_released do propagate(target, .Released, true)
		propagate(target, .Released_Out, false)

		if wheel != 0 do propagate_scroll(target, wheel)
	}
}

@(private = "file")
get :: #force_inline proc(idx: int, interest: Interest, $T: typeid) -> T {
	ptr := (^T)(ctx.interest_buffer[idx][interest])
	return ptr == nil ? {} : ptr^
}

@(private = "file")
set :: #force_inline proc(idx: int, interest: Interest, value: $T) {
	ptr := (^T)(ctx.interest_buffer[idx][interest])
	if ptr != nil do ptr^ = value
}

@(private = "file")
propagate :: proc(id: int, interest: Interest, value: $T) {
	curr := id
	for curr != -1 {
		scope := &ctx.buffer[curr]
		if interest in scope.interests {
			set(curr, interest, value)
			if !(.Pass_Through in scope.flags) do break
		}
		curr = scope.parent
	}
}

@(private = "file")
propagate_scroll :: proc(id: int, wheel: f32) {
	curr := id
	for curr != -1 {
		scope := &ctx.buffer[curr]

		if .Scroll_X in scope.interests {
			if set_scroll(curr, .Scroll_X, .X, wheel) do break
		} else if .Scroll_Y in scope.interests {
			if set_scroll(curr, .Scroll_Y, .Y, wheel) do break
		}

		curr = scope.parent
	}
}

@(private = "file")
set_scroll :: proc(id: int, interest: Interest, dir: Dir, wheel: f32) -> bool {
	scope := &ctx.buffer[id]
	current := get(id, interest, f32) - wheel
	max_scroll := max(0, scope.content_size[dir] - scope.size[dir])
	value := math.clamp(current, 0, max_scroll)

	set(id, interest, value)
	return !(.Pass_Through in scope.flags)
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

@(private = "file")
resolve_target :: proc(pos: Vec2) -> int {
	mouse_left_pressed := ctx.callbacks.is_mouse_pressed(.Left)
	mouse_left_released := ctx.callbacks.is_mouse_released(.Left)

	target := -1

	for i := ctx.scope_count - 1; i >= 0; i -= 1 {
		scope := &ctx.buffer[i]

		if !is_visible(i) || scope.interests == {} do continue

		if .Hovered in scope.interests do set(i, .Hovered, false)
		if .Pressed in scope.interests do set(i, .Pressed, false)
		if .Pressed_Out in scope.interests do set(i, .Pressed_Out, mouse_left_pressed)
		if .Released in scope.interests do set(i, .Released, false)
		if .Released_Out in scope.interests do set(i, .Released_Out, mouse_left_released)

		if target == -1 && is_mouse_inside(scope, pos) do target = i
	}

	return target
}

