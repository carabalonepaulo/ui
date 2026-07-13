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
		value: time.Duration,
	}

	rows := []Row {
		{"Frame", ctx.diagnostics.frame},
		{"Input", ctx.diagnostics.input},
		{"Deferred (Pre)", ctx.diagnostics.deferred_pre},
		{"Deferred (Post)", ctx.diagnostics.deferred_post},
		{"Evict", ctx.diagnostics.evict},
	}

	font_size: f32 = 20
	gap: f32 = 5
	padding: f32 = 10

	h := get(id("internal/profiler/size"), f32, 0)
	begin_scope({300, h^}, {.Clip})
	container := get_scope()

	size := get_available_size()
	draw_rect(0, 0, size.x, size.y, {67, 67, 67, 255})

	c := begin_col(
		size,
		{
			{.Absolute, font_size},
			{.Absolute, font_size},
			{.Absolute, font_size},
			{.Absolute, font_size},
			{.Absolute, font_size},
		},
		gap = gap,
		padding = {padding, padding, padding, padding},
	)
	parent_scope := get_scope()

	for value in rows {
		if next(&c) {
			r := row(get_available_size(), {{.Flex, 2}, {.Flex, 1}})
			if next(&r) do draw_text(0, value.label, 0, 0, font_size, 1, {0, 0, 0, 255})
			if next(&r) {
				text := fmt.aprintf("%v", value.value, allocator = get_temp_allocator())
				draw_text(0, text, 0, 0, font_size, 1, {0, 0, 0, 255})
			}
		}
	}

	end_col(c)
	end_scope()

	h^ = container.content_size.y
}

