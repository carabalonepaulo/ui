package ui

Fit :: distinct Id

begin_fit :: proc(uid: Id, size: Vec2, flags: Scope_Flags = {}) -> Fit {
	size_id := id(uid, "fit/size")
	prev_size := get(size_id, Vec2, Vec2{max(0, size.x), max(0, size.y)})
	begin_scope(prev_size^, flags)
	return Fit(size_id)
}

end_fit :: proc(fit: Fit) {
	get(Id(fit), Vec2)^ = ctx.buffer[ctx.current_scope].content_size
	end_scope()
}

@(deferred_out = end_fit)
fit :: proc(id: Id, size: Vec2, flags: Scope_Flags = {}) -> Fit {
	return begin_fit(id, size, flags)
}

