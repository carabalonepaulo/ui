package ui

begin_padding :: proc(padding: Padding, flags: Scope_Flags = {}) {
	size := get_available_size()

	begin_scope(size, flags)
	container := get_scope()
	container.cursor += {padding.left, padding.top}

	begin_scope(Vec2{size.x - padding.right - padding.left, size.y - padding.top - padding.bottom})
}

end_padding :: proc() {
	end_scope()
	end_scope()
}

@(deferred_none = end_padding)
padding :: proc(padding: Padding, flags: Scope_Flags = {}) {
	begin_padding(padding, flags)
}

