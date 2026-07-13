package ui

import "core:container/queue"
import "core:mem"

ctx: Context

init_context :: proc(callbacks: Callbacks, cap: int, frame_memory: int) -> bool {
	memory, alloc_err := mem.alloc_bytes(frame_memory)
	if alloc_err != nil do return false

	ctx.memory = memory
	mem.arena_init(&ctx.arena, ctx.memory)
	ctx.arena_allocator = mem.arena_allocator(&ctx.arena)

	ctx.callbacks = callbacks
	ctx.interest_buffer = make([][Interest]rawptr, cap)
	ctx.buffer = make([]Scope, cap)
	ctx.current_scope = -1

	queue.init(&ctx.deferred_pre)
	queue.init(&ctx.deferred_post)

	init_store(&ctx.store)

	return true
}

deinit_context :: proc() {
	deinit_store(&ctx.store)
	delete(ctx.interest_buffer)
	delete(ctx.buffer)
	queue.destroy(&ctx.deferred_pre)
	queue.destroy(&ctx.deferred_post)
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

	execute_deferred(&ctx.deferred_pre)
	process_input()
	execute_deferred(&ctx.deferred_post)

	evict()
	mem.free_all(ctx.arena_allocator)
}

@(deferred_none = end_frame)
frame :: #force_inline proc() {
	begin_frame()
}

temp :: #force_inline proc($T: typeid) -> ^T {
	return new(T, ctx.arena_allocator)
}

@(private = "file")
execute_deferred :: proc(q: ^queue.Queue(Deferred)) {
	for queue.len(q^) > 0 {
		deferred := queue.dequeue(q)
		deferred.fn(deferred.ud)
	}
}

deferred :: #force_inline proc(kind: Deferred_Kind, ud: rawptr, fn: proc(ud: rawptr)) {
	queue.enqueue(kind == .Pre ? &ctx.deferred_pre : &ctx.deferred_post, Deferred{fn, ud})
}

Deferred_Arg :: struct($T: typeid) {
	arg: T,
	fn:  proc(arg: T),
}

deferred_with_poly :: proc(kind: Deferred_Kind, arg: $T, fn: proc(arg: T)) {
	tmp := temp(Deferred_Arg(T))
	tmp.arg = arg
	tmp.fn = fn

	fn := proc(ud: rawptr) {
		tmp := (^Deferred_Arg(T))(ud)
		tmp.fn(tmp.arg)
	}

	deferred(kind, tmp, fn)
}

