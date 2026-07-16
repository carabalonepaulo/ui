package ui

Center :: struct {
	uid: Id,
	fit: Maybe(Fit),
}

@(private = "file")
State :: struct {
	last_size: Vec2,
}

begin_center :: proc(uid: Id, content_size := Vec2{AUTO, AUTO}) -> Center {
	local_state := State{content_size}
	state := content_size == {AUTO, AUTO} ? get(uid, State) : &local_state

	size := get_available_size()

	begin_scope(size)

	offset_x := max(f32(0), (size.x - state.last_size.x) * 0.5)
	offset_y := max(f32(0), (size.y - state.last_size.y) * 0.5)

	parent := get_scope()
	parent.cursor += {offset_x, offset_y}

	center := Center{uid, nil}
	if content_size == {AUTO, AUTO} {
		center.fit = begin_fit(id(uid, "fit"), {AUTO, AUTO})
	}

	return center
}

end_center :: proc(center: Center) {
	if fit, ok := center.fit.(Fit); ok {
		content_scope := get_scope_id()
		end_fit(fit)
		state := get(center.uid, State)
		state.last_size = get_size(content_scope)
	}

	end_scope()
}

@(deferred_out = end_center)
center :: proc(uid: Id, content_size := Vec2{AUTO, AUTO}) -> Center {
	return begin_center(uid, content_size)
}

