package ui

begin_padding :: proc(
	top: f32 = 0,
	right: f32 = 0,
	bottom: f32 = 0,
	left: f32 = 0,
	flags: Scope_Flags = {},
) {
	size := get_available_size()

	begin_scope(size, flags)
	container := get_scope()
	container.cursor += {left, top}

	begin_scope(Vec2{size.x - right - left, size.y - top - bottom})
}

end_padding :: proc() {
	end_scope()
	end_scope()
}

@(deferred_none = end_padding)
padding :: proc(top: f32 = 0, right: f32 = 0, bottom: f32 = 0, left: f32 = 0) {
	begin_padding(top, right, bottom, left)
}

