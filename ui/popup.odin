package ui

popup :: proc(pos: Vec2, size: Vec2, fn: proc()) {
	ud := temp(Popup)
	ud.pos = pos
	ud.size = size
	ud.fn = fn

	deferred(.Pre, ud, proc(ud: rawptr) {
		assert(ctx.scope_count > 0, "missing root scope")
		ud := (^Popup)(ud)
		ctx.current_scope = 0
		scope_at(ud.pos, ud.size)
		ud.fn()
	})
}

popup_with_poly :: proc(pos: Vec2, size: Vec2, arg: $T, fn: proc(arg: T)) {
	ud := temp(Popup_With(T))
	ud.pos = pos
	ud.size = size
	ud.fn = fn
	ud.ud = arg

	deferred(.Pre, ud, proc(ud: rawptr) {
		assert(ctx.scope_count > 0, "missing root scope")
		ud := (^Popup_With(T))(ud)
		ctx.current_scope = 0
		scope_at(ud.pos, ud.size)
		ud.fn(ud.ud)
	})
}

