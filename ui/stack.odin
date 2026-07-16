package ui

Stack_Dir :: enum {
	X,
	Y,
}

Stack :: struct {
	dir: Stack_Dir,
	fit: Fit,
	gap: f32,
}

begin_stack :: proc(uid: Id, dir: Stack_Dir, gap: f32 = 0) -> Stack {
	fit := begin_fit(uid, {AUTO, AUTO})
	return {dir, fit, gap}
}

end_stack :: proc(stack: Stack) {
	container := get_scope()
	container.cursor[stack.dir] -= stack.gap
	end_fit(stack.fit)
}

@(private)
end_stack_next :: proc(stack: ^Stack, size: Vec2) {
	end_scope()
	get_scope().cursor[stack.dir] += size[stack.dir] + stack.gap
}

@(deferred_in = end_stack_next)
stack_next :: proc(stack: ^Stack, size: Vec2) -> bool {
	begin_scope(size)
	return true
}

@(deferred_out = end_stack)
stack :: proc(uid: Id, dir: Stack_Dir, gap: f32 = 0) -> Stack {
	return begin_stack(uid, dir, gap)
}

