package ui

import "core:math"
import "core:slice"

@(private)
process_input :: proc() {
	mouse_pos := ctx.callbacks.get_mouse_pos()
	wheel := ctx.callbacks.get_mouse_wheel()

	mouse_left_pressed := ctx.callbacks.is_mouse_pressed(.Left)
	mouse_left_down := ctx.callbacks.is_mouse_down(.Left)
	mouse_left_released := ctx.callbacks.is_mouse_released(.Left)

	slice.zero(ctx.touched_buffer[:ctx.scope_count])

	hover_consumed := false
	scroll_consumed := false
	pressed_consumed := false
	released_consumed := false
	focus_consumed := false

	for i := ctx.scope_count - 1; i >= 0; i -= 1 {
		scope := &ctx.buffer[i]
		if scope.interests == {} do continue

		if is_mouse_inside(scope, mouse_pos) {
			if .Hovered in scope.interests {
				if !hover_consumed {
					propagate(i, .Hovered, true)
					hover_consumed = true
				} else if !(.Hovered in ctx.touched_buffer[i]) {
					set(i, .Hovered, false)
				}
			}

			if .Pressed in scope.interests {
				if mouse_left_pressed && !pressed_consumed {
					propagate(i, .Pressed, true)
					pressed_consumed = true
				} else if !(.Pressed in ctx.touched_buffer[i]) {
					set(i, .Pressed, false)
				}
			}

			if .Released in scope.interests {
				if mouse_left_released && !released_consumed {
					propagate(i, .Released, true)
					released_consumed = true
				} else if !(.Released in ctx.touched_buffer[i]) {
					set(i, .Released, false)
				}
			}

			if .Scroll_Y in scope.interests && !scroll_consumed && wheel.y != 0 {
				current := get(i, .Scroll_Y, f32) - wheel.y
				max_scroll := max(0, scope.content_size.y - scope.size.y)
				set(i, .Scroll_Y, math.clamp(current, 0, max_scroll))
				scroll_consumed = true
			}

			if .Scroll_X in scope.interests && !scroll_consumed && wheel.x != 0 {
				current := get(i, .Scroll_X, f32) - wheel.x
				max_scroll := max(0, scope.content_size.x - scope.size.x)
				set(i, .Scroll_X, math.clamp(current, 0, max_scroll))
				scroll_consumed = true
			}

			if .Pressed_Out in scope.interests do set(i, .Pressed_Out, false)
			if .Released_Out in scope.interests do set(i, .Released_Out, false)
		} else {
			if .Hovered in scope.interests do set(i, .Hovered, false)
			if .Pressed in scope.interests do set(i, .Pressed, false)
			if .Pressed_Out in scope.interests do set(i, .Pressed_Out, mouse_left_pressed)
			if .Released in scope.interests do set(i, .Released, false)
			if .Released_Out in scope.interests do set(i, .Released_Out, mouse_left_released)
		}
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
			ctx.touched_buffer[curr] += {interest}
			if !(.Pass_Through in scope.flags) do break
		}
		curr = scope.parent
	}
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

