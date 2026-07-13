package ui

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

profiler :: proc() {}

