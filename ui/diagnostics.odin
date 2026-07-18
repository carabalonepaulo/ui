package ui

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

	FONT_SIZE :: 20
	GAP :: 5
	WIDTH :: 300
	PADDING :: 10
	BG_COLOR :: Color{0, 0, 0, 200}
	FONT_COLOR :: Color{200, 200, 200, 255}

	height := measure(FONT_SIZE, len(rows), GAP, Vec2{PADDING, PADDING})
	scope({WIDTH, height})
	fill_rect(BG_COLOR)

	padding(PADDING, PADDING, PADDING, PADDING)

	c := stack(id("internal/profiler/stack"), .Y, GAP)
	for value, i in rows {
		if next(&c, {WIDTH, FONT_SIZE}) {
			r := flex(get_available_size(), .X, {{.Flex, 2}, {.Flex, 1}})
			if next(&r) do draw_text(0, value.label, {}, FONT_SIZE, 1, FONT_COLOR)
			if next(&r) {
				text := fmt.aprintf("%v", value.value, allocator = get_temp_allocator())
				draw_text(0, text, {}, FONT_SIZE, 1, FONT_COLOR)
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

