package ui

import "core:mem"

ctx: Context

init_context :: proc(callbacks: Callbacks, cap: int, frame_memory: int) -> bool {
	memory, alloc_err := mem.alloc_bytes(frame_memory)
	if alloc_err != nil do return false

	ctx.memory = memory
	mem.arena_init(&ctx.arena, ctx.memory)
	ctx.arena_allocator = mem.arena_allocator(&ctx.arena)

	ctx.callbacks = callbacks
	ctx.buffer = make([]Scope, cap)
	ctx.current_scope = -1

	return true
}

deinit_context :: proc() {
	delete(ctx.buffer)
	ctx.buffer = nil
	ctx.current_scope = -1
	ctx.callbacks = {}
}

begin_frame :: proc() {
	ctx.current_scope = -1
	ctx.scope_count = 0
}

end_frame :: proc() {
	assert(ctx.current_scope == -1)
	mem.free_all(ctx.arena_allocator)
}

get_scope :: #force_inline proc() -> ^Scope {
	return &ctx.buffer[ctx.current_scope]
}

get_parent_scope :: #force_inline proc() -> ^Scope {
	return &ctx.buffer[ctx.buffer[ctx.current_scope].parent]
}

get_available_size :: #force_inline proc() -> Vec2 {
	assert(ctx.current_scope != -1)
	scope := &ctx.buffer[ctx.current_scope]

	return Vec2 {
		max(f32(0), scope.size.x - scope.cursor.x),
		max(f32(0), scope.size.y - scope.cursor.y),
	}
}

