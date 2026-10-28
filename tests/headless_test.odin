package tests

import "core:testing"
import ui "ui:."
import hl "ui:headless"

@(test)
headless_records_text :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := ui.Text_Options{font = 0, font_size = 10, wrap = .None}

	hl.begin(&b, {400, 400})
	ui.text(ui.id("label"), {100, 20}, "hello", opts)
	hl.end(&b)

	count := 0
	for call in b.calls {
		if call.kind != .Text do continue
		count += 1
		testing.expect_value(t, call.text, "hello")
		testing.expect_value(t, call.pos, ui.Vec2{0, 0})
		testing.expect_value(t, call.font_size, 10)
	}
	testing.expect_value(t, count, 1)
}

@(test)
headless_measures_monospace :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := ui.Text_Options{font = 0, font_size = 10, wrap = .None}

	size: ui.Vec2
	hl.begin(&b, {400, 400})
	size = ui.measure_text(ui.id("m"), {ui.AUTO, ui.AUTO}, "hello", &opts)
	hl.end(&b)

	testing.expect_value(t, size, ui.Vec2{50, 10})
}

@(test)
headless_records_rects_and_scissors :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	hl.begin(&b, {400, 400})
	{
		ui.scope({100, 50}, {.Clip})
		ui.fill_rect({1, 2, 3, 255})
	}
	hl.end(&b)

	rects, scissors := 0, 0
	for call in b.calls {
		switch call.kind {
		case .Rect:
			rects += 1
			testing.expect_value(t, call.size, ui.Vec2{100, 50})
		case .Scissor_Begin:
			scissors += 1
		case .Scissor_End:
			scissors -= 1
		case .Text:
		}
	}
	testing.expect_value(t, rects, 1)
	testing.expect_value(t, scissors, 0)
}

