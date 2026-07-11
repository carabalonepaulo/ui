package ui

intersect_rects :: proc(a, b: Rect) -> Rect {
	ix1 := max(a[0], b[0])
	iy1 := max(a[1], b[1])
	ix2 := min(a[0] + a[2], b[0] + b[2])
	iy2 := min(a[1] + a[3], b[1] + b[3])

	if ix2 > ix1 && iy2 > iy1 {
		return Rect{ix1, iy1, ix2 - ix1, iy2 - iy1}
	}

	return Rect{0, 0, 0, 0}
}

begin_scope :: proc(size: Vec2) {
	parent_idx := ctx.current_scope

	idx := ctx.scope_count + 1
	ctx.scope_count += 1
	assert(idx < len(ctx.buffer), "ui buffer overflow")

	scope := &ctx.buffer[idx]
	scope^ = Scope {
		parent = parent_idx,
		size   = size,
	}
	rect := Rect{0, 0, size[0], size[1]}

	if parent_idx != -1 {
		parent := &ctx.buffer[parent_idx]

		scope.screen_pos = parent.screen_pos + parent.cursor - parent.offset
		scope.pos = parent.cursor
		scope.parent = parent_idx

		child_extended_boundary := parent.cursor + size
		parent.content_size.x = max(parent.content_size.x, child_extended_boundary.x)
		parent.content_size.y = max(parent.content_size.y, child_extended_boundary.y)

		rect[0] = scope.screen_pos[0]
		rect[1] = scope.screen_pos[1]
		scope.clip = intersect_rects(parent.clip, rect)
	} else {
		scope.clip = Rect{scope.screen_pos[0], scope.screen_pos[1], size[0], size[1]}
	}

	ctx.current_scope = idx

	ctx.callbacks.enable_scissors(scope.clip[0], scope.clip[1], scope.clip[2], scope.clip[3])
}

end_scope :: proc() {
	assert(ctx.current_scope != -1, "end_scope() must be called after a begin_scope()")

	child := &ctx.buffer[ctx.current_scope]
	ctx.callbacks.disable_scissors()
	if child.parent != -1 {
		parent := &ctx.buffer[child.parent]
		ctx.callbacks.enable_scissors(
			parent.clip[0],
			parent.clip[1],
			parent.clip[2],
			parent.clip[3],
		)
	} else {
		ctx.callbacks.disable_scissors()
	}
	ctx.current_scope = child.parent
}

