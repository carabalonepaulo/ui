package ui

import "core:hash/xxhash"
import "core:mem"

SEP :: 0xff

Id :: distinct u64

@(private = "file")
Entry :: struct {
	ptr:     rawptr,
	tid:     typeid,
	frame:   u64,
	size:    int,
	destroy: proc(ptr: rawptr),
}

@(private)
Store :: struct {
	frame:   u64,
	entries: map[Id]Entry,
}

@(private)
init_store :: proc(store: ^Store) {
	store.entries = make(map[Id]Entry)
}

@(private)
deinit_store :: proc(store: ^Store) {
	for id in store.entries {
		destroy_entry(id)
	}
	delete(store.entries)
}

get :: proc(
	id: Id,
	$T: typeid,
	default: Maybe(T) = nil,
	destroy: proc(ptr: ^T) = nil,
) -> (
	^T,
	bool,
) #optional_ok {
	if entry, ok := &ctx.store.entries[id]; ok {
		assert(typeid_of(T) == entry.tid, "unexpected type")
		entry.frame = ctx.store.frame
		return (^T)(entry.ptr), false
	}

	ptr, err := mem.alloc(size_of(T), align_of(T))
	assert(err == nil, "out of memory")

	entry := Entry {
		ptr     = ptr,
		tid     = typeid_of(T),
		frame   = ctx.store.frame,
		size    = size_of(T),
		destroy = auto_cast destroy,
	}
	if val, ok := default.(T); ok do (^T)(ptr)^ = val
	ctx.store.entries[id] = entry

	return (^T)(entry.ptr), true
}

@(private)
destroy_entry :: proc(id: Id) {
	entry := ctx.store.entries[id]
	if entry.destroy != nil {
		entry.destroy(entry.ptr)
	}
	mem.free_with_size(entry.ptr, entry.size)
}

exists :: #force_inline proc(id: Id) -> bool {
	return id in ctx.store.entries
}

@(private)
evict :: proc() {
	expired := make([dynamic]Id, ctx.arena_allocator)

	for id, entry in ctx.store.entries {
		if entry.frame < ctx.store.frame {
			append(&expired, id)
		}
	}

	for id in expired {
		destroy_entry(id)
		delete_key(&ctx.store.entries, id)
	}

	ctx.store.frame += 1
}

id :: proc(args: ..any) -> Id {
	state: xxhash.XXH64_state
	xxhash.XXH64_reset_state(&state, 0)

	sep_byte: u8 = SEP

	for arg in args {
		tid := arg.id
		xxhash.XXH64_update(&state, mem.any_to_bytes(tid))

		switch v in arg {
		case string:
			xxhash.XXH64_update(&state, transmute([]u8)v)
		case bool:
			b: u8 = v ? 1 : 0
			xxhash.XXH64_update(&state, mem.any_to_bytes(b))
		case:
			xxhash.XXH64_update(&state, mem.any_to_bytes(v))
		}

		xxhash.XXH64_update(&state, mem.any_to_bytes(sep_byte))
	}

	h := xxhash.XXH64_digest(&state)
	return Id(h)
}

