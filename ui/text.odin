package ui

import "core:strings"
import "core:unicode/utf8"

Cached_Word :: struct {
	size: Vec2,
	step: f32,
}

Cached_Letter :: struct {
	start, end: int,
	size:       Vec2,
	step:       f32,
}

Text_Wrap :: enum {
	None,
	Word,
	Letter,
}

Text_Options :: struct {
	wrap:           Text_Wrap,
	letter_spacing: f32,
	line_spacing:   f32,
	font:           Font,
	font_size:      f32,
	font_color:     Color,
}

text :: proc(uid: Id, size: Vec2, text: string, opts: Text_Options) {
	assert(!(size.x == AUTO && size.y == AUTO), "only one axis can be auto")

	text := text
	opts := opts

	if size.x == AUTO do opts.wrap = .None

	is_fit := size.x == AUTO || size.y == AUTO
	fit: Fit

	if is_fit do fit = begin_fit(id(uid, "fit", {}), size)
	else do begin_scope(size, {})
	defer {
		if is_fit do end_fit(fit)
		else do end_scope()
	}

	container := get_scope()
	container_size := get_size()
	draw_rect(0, 0, container_size.x, container_size.y, {255, 0, 0, 255})

	text_size := ctx.callbacks.measure_text(opts.font, text, opts.font_size, opts.letter_spacing)
	space_size := ctx.callbacks.measure_text(opts.font, " ", opts.font_size, opts.letter_spacing)

	if (text_size.x < container_size.x && text_size.y < container_size.y) || opts.wrap == .None {
		draw_text(opts.font, text, 0, 0, opts.font_size, opts.letter_spacing, opts.font_color)
		container.content_size = text_size
		return
	}

	available := container_size.x
	max_width: f32 = 0

	if opts.wrap == .Word {
		destroy_cache := proc(cache: ^[dynamic]Cached_Word) {delete(cache^)}
		cache, just_created := get(
			id(uid, text, "cache/word"),
			[dynamic]Cached_Word,
			destroy = destroy_cache,
		)

		if just_created {
			sizes := make([dynamic]Cached_Word)
			iter := &text
			for word in strings.split_iterator(iter, " ") {
				word, word_size, step := measure_text(word, &opts, space_size)
				append(&sizes, Cached_Word{word_size, step})
			}
			cache^ = sizes
		}

		iter := &text
		count := 0

		for word in strings.split_iterator(iter, " ") {
			value := cache^[count]
			draw(container, &available, &max_width, word, value.size, value.step, &opts)
			count += 1
		}
	} else {
		destroy_cache := proc(cache: ^[dynamic]Cached_Letter) {delete(cache^)}
		cache, just_created := get(
			id(uid, text, "cache/letter"),
			[dynamic]Cached_Letter,
			destroy = destroy_cache,
		)

		if just_created {
			sizes := make([dynamic]Cached_Letter)

			idx := 0
			for idx < len(text) {
				rune, rune_size := utf8.decode_rune(text[idx:])
				idx += rune_size

				letter_size, step := measure_rune(rune, &opts, space_size)
				append(&sizes, Cached_Letter{idx - rune_size, idx, letter_size, step})
			}

			cache^ = sizes
		}

		letters := cache^
		for i in 0 ..< len(letters) {
			letter := text[letters[i].start:letters[i].end]
			letter_size := letters[i].size
			step := letters[i].step

			draw(container, &available, &max_width, letter, letter_size, step, &opts)
		}
	}
	container.content_size = {max_width, container.cursor.y + opts.font_size}
}

@(private = "file")
measure_text :: proc(text: string, opts: ^Text_Options, space_size: Vec2) -> (string, Vec2, f32) {
	text_size := ctx.callbacks.measure_text(opts.font, text, opts.font_size, opts.letter_spacing)
	return text, text_size, text_size.x + space_size.x
}

@(private = "file")
measure_rune :: proc(c: rune, opts: ^Text_Options, space_size: Vec2) -> (Vec2, f32) {
	letter := utf8.runes_to_string({c}, get_temp_allocator())
	letter_size := ctx.callbacks.measure_text(
		opts.font,
		letter,
		opts.font_size,
		opts.letter_spacing,
	)
	return letter_size, letter_size.x + opts.letter_spacing
}

@(private = "file")
draw :: proc(
	container: ^Scope,
	available: ^f32,
	max_width: ^f32,
	text: string,
	text_size: Vec2,
	step: f32,
	opts: ^Text_Options,
) {
	if available^ - text_size.x < 0 {
		if container.cursor.x > max_width^ do max_width^ = container.cursor.x
		container.cursor.y += opts.font_size + opts.line_spacing
		container.cursor.x = 0
		available^ = container.size.x
	}

	draw_text(
		opts.font,
		text,
		container.cursor.x,
		container.cursor.y,
		opts.font_size,
		opts.letter_spacing,
		opts.font_color,
	)

	container.cursor.x += step
	available^ -= step
}

