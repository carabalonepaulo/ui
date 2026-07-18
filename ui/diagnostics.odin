package ui

import "core:crypto/ristretto255"
import "core:fmt"
import "core:time"

Diagnostics :: struct {
	frame:         time.Duration,
	input:         time.Duration,
	deferred_pre:  time.Duration,
	deferred_post: time.Duration,
	evict:         time.Duration,
}

@(deferred_in_out = end_scope_timer)
scope_timer :: proc(out: ^time.Duration) -> time.Time {
	return time.now()
}

@(private = "file")
end_scope_timer :: proc(out: ^time.Duration, start: time.Time) {
	out^ = time.since(start)
}

profiler :: proc() {
	Row :: struct {
		label: string,
		value: union {
			time.Duration,
			string,
			int,
			f32,
			u64,
		},
	}

	rows := []Row {
		{"Frame", ctx.diagnostics.frame},
		{"Input", ctx.diagnostics.input},
		{"Deferred (Pre)", ctx.diagnostics.deferred_pre},
		{"Deferred (Post)", ctx.diagnostics.deferred_post},
		{"Evict", ctx.diagnostics.evict},
		{"Scopes", ctx.scope_count},
		{"Store Count", len(ctx.store.entries)},
	}

	font_size: f32 = 20
	gap: f32 = 5
	width: f32 = 300

	scope({width, get_available_size().y})
	fill_rect({0, 0, 0, 200})

	padding(top = 10, bottom = 10, left = 10, right = 10)

	constraints, just_created := get(
		id("internal/profiler/constraints"),
		[]Layout_Item,
		destroy = proc(constraints: ^[]Layout_Item) {delete(constraints^)},
	)
	if just_created {
		slice := make([]Layout_Item, len(rows))
		for i in 0 ..< len(slice) do slice[i] = {.Absolute, font_size}
		constraints^ = slice
	}

	c := stack(id("internal/profiler/stack"), .Y, gap)

	for value, i in rows {
		if next(&c, {width, font_size}) {
			r := flex(get_available_size(), .X, {{.Flex, 2}, {.Flex, 1}})
			if next(&r) do draw_text(0, value.label, {}, font_size, 1, {200, 200, 200, 255})
			if next(&r) {
				text := fmt.aprintf("%v", value.value, allocator = get_temp_allocator())
				draw_text(0, text, {}, font_size, 1, {200, 200, 200, 255})
			}
		}
	}
}

format_bytes :: proc(bytes: u64) -> string {
	context.allocator = get_temp_allocator()

	if bytes < 1024 do return fmt.aprintf("%d B", bytes)

	suffixes := [?]string{"B", "KB", "MB", "GB", "TB", "PB", "EB"}

	value := f64(bytes)
	i := 0

	for value >= 1024 && i < len(suffixes) - 1 {
		value /= 1024
		i += 1
	}

	return fmt.aprintf("%.2f %s", value, suffixes[i])
}

