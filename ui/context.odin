package ui

init_context :: proc(self: ^Context, callbacks: Callbacks, cap: int) {
	self.callbacks = callbacks
	self.buffer = make([]Scope, cap)
	self.current_scope = -1
}

deinit_context :: proc(self: ^Context) {
	delete(self.buffer)
	self.buffer = nil
	self.current_scope = -1
	self.callbacks = {}
}

begin_frame :: proc(ctx: ^Context) {
	ctx.current_scope = -1
	ctx.scope_count = 0
}

end_frame :: proc(ctx: ^Context) {
	assert(ctx.current_scope == -1)
}

get_scope :: #force_inline proc(ctx: ^Context) -> ^Scope {
	return &ctx.buffer[ctx.current_scope]
}

get_parent_scope :: #force_inline proc(ctx: ^Context) -> ^Scope {
	return &ctx.buffer[ctx.buffer[ctx.current_scope].parent]
}

