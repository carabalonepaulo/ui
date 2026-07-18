package ui

Stack :: struct {
	inner_flags: Scope_Flags,
	dir:         Dir,
	fit:         Fit,
	gap:         f32,
}

begin_stack :: proc(
	uid: Id,
	dir: Dir,
	gap: f32 = 0,
	flags: Scope_Flags = {},
	inner_flags: Scope_Flags = {},
) -> Stack {
	fit := begin_fit(uid, {AUTO, AUTO}, flags)
	return {inner_flags, dir, fit, gap}
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
	begin_scope(size, stack.inner_flags)
	return true
}

@(deferred_out = end_stack)
stack :: proc(
	uid: Id,
	dir: Dir,
	gap: f32 = 0,
	flags: Scope_Flags = {},
	inner_flags: Scope_Flags = {},
) -> Stack {
	return begin_stack(uid, dir, gap, flags, inner_flags)
}

