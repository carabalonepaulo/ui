package tests

import "core:testing"
import ui "ui:."
import hl "ui:headless"

// The headless backend measures one rune as `advance` (10 by default) and the
// height as `font_size`, so every expectation below is exact arithmetic.

text_opts :: proc(wrap: ui.Text_Wrap, size: f64 = 10) -> ui.Text_Options {
	return {font = 0, font_size = size, wrap = wrap}
}

// Collects the text calls of the last frame, in draw order.
texts_of :: proc(b: ^hl.Backend, allocator := context.allocator) -> [dynamic]hl.Call {
	calls := make([dynamic]hl.Call, 0, len(b.calls), allocator)
	for call in b.calls {
		if call.kind == .Text do append(&calls, call)
	}
	return calls
}

@(test)
wrap_mode_is_part_of_the_draw_cache :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Word)
	word_calls, letter_calls: int

	hl.begin(&b, {400, 400})
	{
		ui.scope({35, 100})
		ui.text(ui.id("d"), {35, 100}, "abcd efgh", opts)
	}
	hl.end(&b)

	word_calls = len(texts_of(&b))
	hl.reset(&b)

	opts.wrap = .Letter
	hl.begin(&b, {400, 400})
	{
		ui.scope({35, 100})
		ui.text(ui.id("d"), {35, 100}, "abcd efgh", opts)
	}
	hl.end(&b)

	letter_calls = len(texts_of(&b))

	// Word wrap draws two words; letter wrap draws one call per rune.
	testing.expect_value(t, word_calls, 2)
	testing.expect_value(t, letter_calls, 9)
}

@(test)
measure_auto_does_not_wrap :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Word)
	size: ui.Vec2

	hl.begin(&b, {400, 400})
	size = ui.measure_text(ui.id("m"), {ui.AUTO, ui.AUTO}, "aaa bbb", &opts)
	hl.end(&b)

	// One line of 7 runes. Wrapping at a width of -1 produced one word per line.
	testing.expect_value(t, size, ui.Vec2{70, 10})
}

@(test)
wrap_mode_is_part_of_the_cache_key :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Word)
	word, letter: ui.Vec2

	hl.begin(&b, {400, 400})
	word = ui.measure_text(ui.id("m"), {35, 100}, "abcd efgh", &opts)
	hl.end(&b)

	opts.wrap = .Letter
	hl.begin(&b, {400, 400})
	letter = ui.measure_text(ui.id("m"), {35, 100}, "abcd efgh", &opts)
	hl.end(&b)

	// Word: "abcd" then "efgh". Letter: abc / def / gh.
	testing.expect_value(t, word, ui.Vec2{35, 20})
	testing.expect_value(t, letter, ui.Vec2{30, 30})
}

@(test)
spaces_are_preserved :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Word)

	hl.begin(&b, {400, 400})
	{
		ui.scope({65, 100})
		ui.text(ui.id("s"), {65, 100}, "aa  bb cc", opts)
	}
	hl.end(&b)

	texts := texts_of(&b)
	defer delete(texts)

	testing.expect_value(t, len(texts), 3)
	if len(texts) != 3 do return

	// Two spaces before "bb" are two advances, not one.
	testing.expect_value(t, texts[0].text, "aa")
	testing.expect_value(t, texts[0].pos, ui.Vec2{0, 0})
	testing.expect_value(t, texts[1].text, "bb")
	testing.expect_value(t, texts[1].pos, ui.Vec2{40, 0})
	testing.expect_value(t, texts[2].text, "cc")
	testing.expect_value(t, texts[2].pos, ui.Vec2{0, 10})
}

@(test)
measured_width_is_ink :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Word)
	size: ui.Vec2

	hl.begin(&b, {400, 400})
	size = ui.measure_text(ui.id("m"), {100, 100}, "aaa bbb cccc", &opts)
	hl.end(&b)

	// Line 1 is "aaa bbb", which ends at 70. The space before "cccc" belongs to
	// the next line, so it must not widen the reported size.
	testing.expect_value(t, size, ui.Vec2{70, 20})
}

@(test)
letter_spacing_width_is_ink :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Letter)
	opts.letter_spacing = 5

	size: ui.Vec2
	hl.begin(&b, {400, 400})
	size = ui.measure_text(ui.id("m"), {35, 100}, "abcdef", &opts)
	hl.end(&b)

	// Two runes per line (10 + 5 + 10 = 25), three lines.
	testing.expect_value(t, size, ui.Vec2{25, 30})
}

@(test)
measure_and_draw_agree :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Word)
	measured: ui.Vec2

	hl.begin(&b, {400, 400})
	measured = ui.measure_text(ui.id("m"), {100, 100}, "aaa bbb cccc", &opts)
	hl.end(&b)

	hl.reset(&b)

	hl.begin(&b, {400, 400})
	{
		ui.scope_at({0, 0}, measured)
		ui.text(ui.id("m"), measured, "aaa bbb cccc", opts)
	}
	hl.end(&b)

	texts := texts_of(&b)
	defer delete(texts)

	testing.expect_value(t, len(texts), 3)
	if len(texts) != 3 do return

	// Drawing in the measured box breaks the lines exactly like measuring did.
	testing.expect_value(t, texts[1].pos, ui.Vec2{40, 0})
	testing.expect_value(t, texts[2].pos, ui.Vec2{0, 10})
}

@(test)
exact_fit_draws_once :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Word)

	hl.begin(&b, {400, 400})
	{
		ui.scope({30, 100})
		ui.text(ui.id("s"), {30, 100}, "abc", opts)
	}
	hl.end(&b)

	texts := texts_of(&b)
	defer delete(texts)

	testing.expect_value(t, len(texts), 1)
	if len(texts) == 1 {
		testing.expect_value(t, texts[0].text, "abc")
		testing.expect_value(t, texts[0].pos, ui.Vec2{0, 0})
	}
}

@(test)
overlong_word_is_clamped_to_the_container :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Word)
	size: ui.Vec2

	hl.begin(&b, {400, 400})
	size = ui.measure_text(ui.id("m"), {29, 100}, "abcdefgh", &opts)
	hl.end(&b)

	// Word wrap never splits a word: the text overflows and the reported size is
	// clamped, so `.Clip` on the scope is what prevents the visual overflow.
	testing.expect_value(t, size, ui.Vec2{29, 10})
}

@(test)
scroll_y_clamps_to_the_text_height :: proc(t: ^testing.T) {
	b: hl.Backend
	if !hl.init(&b) do testing.fail_now(t, "headless init failed")
	defer hl.deinit(&b)

	opts := text_opts(.Word)
	opts.scroll = .Y

	offset: f64

	hl.begin(&b, {400, 400})
	{
		off := ui.get(ui.id(ui.id("s"), 'y'), f64)
		off^ = 1000

		ui.text(ui.id("s"), {50, 20}, "aaa bbb ccc ddd", opts)

		offset = off^
	}
	hl.end(&b)

	// Four lines of 10 in a 20 tall box: the offset stops at 20.
	testing.expect_value(t, offset, 20)
}
