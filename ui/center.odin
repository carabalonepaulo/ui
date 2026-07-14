package ui

Center :: struct {
	container_scope: int,
	content_scope:   int,
	uid:             Id,
	done:            bool,
	fit:             Fit,
}

@(private = "file")
State :: struct {
	last_size: Vec2,
}

begin_center :: proc(uid: Id) -> Center {
	state := get(uid, State)
	size := get_available_size()

	begin_scope(size)
	container_scope := get_scope_id()

	offset_x := max(f32(0), (size.x - state.last_size.x) * 0.5)
	offset_y := max(f32(0), (size.y - state.last_size.y) * 0.5)

	parent := get_scope()
	parent.cursor += {offset_x, offset_y}

	fit := begin_fit(id(uid, "fit"), {AUTO, AUTO})
	content_scope := get_scope_id()

	return Center{container_scope, content_scope, uid, false, fit}
}

@(private = "file")
end_center_child :: proc(state: ^Center, success: bool) {
	if success do end_fit(state.fit)
}

@(deferred_in_out = end_center_child)
center_next :: proc(center: ^Center) -> bool {
	defer center.done = true
	return !center.done
}

end_center :: proc(center: Center) {
	size := get_size(center.content_scope)
	state := get(center.uid, State)
	state.last_size = size

	end_scope()
}

@(deferred_out = end_center)
center :: proc(uid: Id) -> Center {
	return begin_center(uid)
}

