package ui

import "core:math"

AUTO :: -1

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

	if .Scroll_X in child.interests {
		if ptr := (^f32)(ctx.interest_buffer[ctx.current_scope][.Scroll_X]); ptr != nil {
			ptr^ = math.clamp(ptr^, 0, max(0, child.content_size.x - child.size.x))
			child.offset.x = ptr^
		}
	}

	if .Scroll_Y in child.interests {
		if ptr := (^f32)(ctx.interest_buffer[ctx.current_scope][.Scroll_Y]); ptr != nil {
			ptr^ = math.clamp(ptr^, 0, max(0, child.content_size.y - child.size.y))
			child.offset.y = ptr^
		}
	}

	if child.parent != -1 {
		parent := &ctx.buffer[child.parent]
		effective_size := child.size

		if .Propagate_Content_Size in child.flags {
			effective_size = Vec2 {
				max(child.size.x, child.content_size.x),
				max(child.size.y, child.content_size.y),
			}
		}

		child_extended_boundary := child.pos + effective_size
		parent.content_size.x = max(parent.content_size.x, child_extended_boundary.x)
		parent.content_size.y = max(parent.content_size.y, child_extended_boundary.y)
	}

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

get_scope_id :: #force_inline proc() -> int {
	return ctx.current_scope
}

get_scope :: #force_inline proc(id := -1) -> ^Scope {
	id := id == -1 ? ctx.current_scope : id
	return &ctx.buffer[id]
}

get_parent_scope :: #force_inline proc(id := -1) -> ^Scope {
	id := id == -1 ? ctx.current_scope : id
	return &ctx.buffer[ctx.buffer[id].parent]
}

get_size :: #force_inline proc(id := -1) -> Vec2 {
	id := id == -1 ? ctx.current_scope : id
	return ctx.buffer[id].size
}

get_content_size :: #force_inline proc(id := -1) -> Vec2 {
	id := id == -1 ? ctx.current_scope : id
	return ctx.buffer[id].content_size
}

get_screen_pos :: #force_inline proc(id := -1) -> Vec2 {
	id := id == -1 ? ctx.current_scope : id
	return ctx.buffer[id].screen_pos
}

get_available_size :: #force_inline proc(id := -1) -> Vec2 {
	id := id == -1 ? ctx.current_scope : id
	scope := &ctx.buffer[id]
	return Vec2 {
		max(f32(0), scope.size.x - scope.cursor.x),
		max(f32(0), scope.size.y - scope.cursor.y),
	}
}

get_visible_rect :: proc(id := -1) -> [4]f32 {
	child := get_scope(id)
	if child.parent == -1 do return [4]f32{0, 0, child.size.x, child.size.y}

	parent := get_parent_scope(id)

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

is_visible :: #force_inline proc(id := -1) -> bool {
	child := get_scope(id)
	return child.clip.z > 0 && child.clip.w > 0
}

get_anchor :: proc(anchor: Anchor, id := -1) -> (Vec2, bool) #optional_ok {
	child := get_scope(id)
	if child.parent == -1 do return {}, false

	visible := get_visible_rect(id)
	if visible[2] <= 0 || visible[3] <= 0 do return {}, false

	parent := get_parent_scope(id)
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

to_screen_pos_at :: #force_inline proc(id: int, local: Vec2) -> Vec2 {
	scope := get_scope(id)
	return scope.screen_pos + local - scope.offset
}

to_local_pos_at :: #force_inline proc(id: int, screen: Vec2) -> Vec2 {
	scope := get_scope(id)
	return screen - scope.screen_pos + scope.offset
}

to_screen_pos :: #force_inline proc(local: Vec2) -> Vec2 {
	return to_screen_pos_at(ctx.current_scope, local)
}

to_local_pos :: #force_inline proc(screen: Vec2) -> Vec2 {
	return to_local_pos_at(ctx.current_scope, screen)
}

is_scroll_at_start :: #force_inline proc(axis: Dir, id := -1) -> bool {
	return get_scope(id).offset[axis] == 0
}

is_scroll_at_end :: #force_inline proc(axis: Dir, id := -1) -> bool {
	scope := get_scope(id)
	max_offset := max(scope.content_size[axis] - scope.size[axis], 0)
	return scope.offset[axis] >= max_offset
}

measure_fixed :: proc(size: f32, count: int, gap: f32 = 0, padding: [2]f32 = {0, 0}) -> f32 {
	if count <= 0 do return 0
	count := f32(count)
	return (size * count + gap * (count - 1)) + padding[0] + padding[1]
}

measure_dynamic :: proc(
	items: []$T,
	fn: proc(item: T) -> f32,
	gap: f32 = 0,
	padding: [2]f32 = {0, 0},
) -> f32 {
	if len(items) == 0 do return 0

	size: f32 = 0
	for item in items do size += fn(item)

	return (size + gap * f32(len(items) - 1)) + padding[0] + padding[1]
}

