package ui

import "core:math"

intersect :: proc(a, b: Rect) -> Rect {
	x1 := max(a.x, b.x)
	y1 := max(a.y, b.y)
	x2 := min(a.x + a.z, b.x + b.z)
	y2 := min(a.y + a.w, b.y + b.w)
	return x2 > x1 && y2 > y1 ? Rect{x1, y1, x2 - x1, y2 - y1} : {0, 0, 0, 0}
}

begin_scope :: proc(size: Vec2, flags: Scope_Flags = {}) {
	parent_idx := ctx.current_scope

	idx := ctx.scope_count
	ctx.scope_count += 1
	assert(idx < len(ctx.buffer), "ui buffer overflow")

	ctx.interest_buffer[idx] = {}
	scope := &ctx.buffer[idx]
	scope^ = Scope {
		parent = parent_idx,
		size   = size,
		flags  = flags,
	}
	rect := Rect{0, 0, i32(math.ceil(size[0])), i32(math.ceil(size[1]))}

	if parent_idx != -1 {
		parent := &ctx.buffer[parent_idx]

		scope.screen_pos = parent.screen_pos + parent.cursor - parent.offset
		scope.pos = parent.cursor
		scope.parent = parent_idx

		child_extended_boundary := parent.cursor + size
		parent.content_size.x = max(parent.content_size.x, child_extended_boundary.x)
		parent.content_size.y = max(parent.content_size.y, child_extended_boundary.y)

		rect[0] = i32(scope.screen_pos[0])
		rect[1] = i32(scope.screen_pos[1])
		scope.clip = intersect(parent.clip, rect)
	} else {
		rect[0] = i32(scope.screen_pos[0])
		rect[1] = i32(scope.screen_pos[1])
		scope.clip = rect
	}

	ctx.current_scope = idx

	if .Clip in flags {
		ctx.callbacks.enable_scissors(scope.clip[0], scope.clip[1], scope.clip[2], scope.clip[3])
	}
}

end_scope :: proc() {
	assert(ctx.current_scope != -1, "end_scope() must be called after a begin_scope()")

	child := &ctx.buffer[ctx.current_scope]
	if .Clip in child.flags {
		ctx.callbacks.disable_scissors()
		parent := child.parent
		for parent != -1 {
			scope := &ctx.buffer[parent]
			if .Clip in scope.flags {
				ctx.callbacks.enable_scissors(
					scope.clip[0],
					scope.clip[1],
					scope.clip[2],
					scope.clip[3],
				)
				break
			}
			parent = scope.parent
		}
	}
	ctx.current_scope = child.parent
}

@(deferred_none = end_scope)
scope :: proc(size: Vec2, flags: Scope_Flags = {}) {
	begin_scope(size, flags)
}

@(deferred_none = end_scope)
scope_at :: proc(pos: Vec2, size: Vec2, flags: Scope_Flags = {}) {
	parent := get_scope()
	old_cursor := parent.cursor
	parent.cursor = pos
	begin_scope(size, flags)
	parent.cursor = old_cursor
}

bind :: proc(interest: Interest, ptr: rawptr) {
	assert(ctx.current_scope != -1, "invalid scope")

	if ptr == nil do return

	scope := get_scope()
	scope.interests += {interest}
	ctx.interest_buffer[ctx.current_scope][interest] = ptr

	#partial switch interest {
	case .Scroll_X:
		scope.offset.x = (^f32)(ptr)^
	case .Scroll_Y:
		scope.offset.y = (^f32)(ptr)^
	}
}

get_scope :: #force_inline proc() -> ^Scope {
	return &ctx.buffer[ctx.current_scope]
}

get_parent_scope :: #force_inline proc() -> ^Scope {
	return &ctx.buffer[ctx.buffer[ctx.current_scope].parent]
}

get_available_size :: #force_inline proc() -> Vec2 {
	scope := &ctx.buffer[ctx.current_scope]
	return Vec2 {
		max(f32(0), scope.size.x - scope.cursor.x),
		max(f32(0), scope.size.y - scope.cursor.y),
	}
}

get_visible_rect :: proc() -> [4]f32 {
	child := get_scope()
	if child.parent == -1 do return [4]f32{0, 0, child.size.x, child.size.y}

	parent := get_parent_scope()

	left := max(child.pos.x, parent.offset.x)
	top := max(child.pos.y, parent.offset.y)
	right := min(child.pos.x + child.size.x, parent.offset.x + parent.size.x)
	bottom := min(child.pos.y + child.size.y, parent.offset.y + parent.size.y)

	return [4]f32 {
		left - parent.offset.x,
		top - parent.offset.y,
		max(0, right - left),
		max(0, bottom - top),
	}
}

is_visible :: #force_inline proc() -> bool {
	child := get_scope()
	return child.clip.z > 0 && child.clip.w > 0
}

get_anchor :: proc(anchor: Anchor) -> (Vec2, bool) #optional_ok {
	child := get_scope()
	if child.parent == -1 do return {}, false

	visible := get_visible_rect()
	if visible[2] <= 0 || visible[3] <= 0 do return {}, false

	parent := get_parent_scope()
	x := parent.screen_pos.x + visible.x
	y := parent.screen_pos.y + visible.y

	w := visible[2]
	h := visible[3]

	switch anchor {
	case .Top_Left:
		return {x, y}, true
	case .Top:
		return {x + w * 0.5, y}, true
	case .Top_Right:
		return {x + w, y}, true

	case .Left:
		return {x, y + h * 0.5}, true
	case .Center:
		return {x + w * 0.5, y + h * 0.5}, true
	case .Right:
		return {x + w, y + h * 0.5}, true

	case .Bottom_Left:
		return {x, y + h}, true
	case .Bottom:
		return {x + w * 0.5, y + h}, true
	case .Bottom_Right:
		return {x + w, y + h}, true
	}

	return {}, false
}

