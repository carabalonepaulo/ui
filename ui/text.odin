package ui

import "core:unicode/utf8"

@(private = "file")
Cached_Token :: struct {
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

	text_id := id(uid, text)
	text_size := get_text_size(text_id, text, &opts)

	if (text_size.x < container_size.x && text_size.y < container_size.y) || opts.wrap == .None {
		draw_text(opts.font, text, 0, 0, opts.font_size, opts.letter_spacing, opts.font_color)
		container.content_size = text_size
		return
	}

	available := container_size.x
	max_width: f32 = 0

	tokens := get_token_cache(id(text_id, "cache"), text, &opts)
	for i in 0 ..< len(tokens) {
		token := text[tokens[i].start:tokens[i].end]
		token_size := tokens[i].size
		step := tokens[i].step
		draw(container, &available, &max_width, token, token_size, step, &opts)
	}

	container.content_size = {max_width, container.cursor.y + opts.font_size}
}

@(private = "file")
measure_text :: #force_inline proc(text: string, opts: ^Text_Options) -> Vec2 {
	return ctx.callbacks.measure_text(opts.font, text, opts.font_size, opts.letter_spacing)
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

@(private = "file")
get_text_size :: proc(uid: Id, text: string, opts: ^Text_Options) -> Vec2 {
	text_size, just_created := get(uid, Vec2)
	if just_created {
		text_size^ = ctx.callbacks.measure_text(
			opts.font,
			text,
			opts.font_size,
			opts.letter_spacing,
		)
	}
	return text_size^
}

@(private = "file")
get_token_cache :: proc(uid: Id, text: string, opts: ^Text_Options) -> []Cached_Token {
	destroy_cache := proc(cache: ^[dynamic]Cached_Token) {delete(cache^)}
	cache, just_created := get(uid, [dynamic]Cached_Token, destroy = destroy_cache)

	if just_created {
		space_size := ctx.callbacks.measure_text(
			opts.font,
			" ",
			opts.font_size,
			opts.letter_spacing,
		)

		sizes := make([dynamic]Cached_Token)
		idx := 0
		start := 0

		if opts.wrap == .Word {
			for idx < len(text) {
				rune, rune_size := utf8.decode_rune(text[idx:])
				idx += rune_size

				if rune == ' ' {
					end := idx - rune_size
					if start < end {
						word_size := measure_text(text[start:end], opts)
						cached := Cached_Token{start, end, word_size, word_size.x + space_size.x}
						append(&sizes, cached)
					}
					start = idx
				}
			}

			if start < idx {
				word_size := measure_text(text[start:idx], opts)
				cached := Cached_Token{start, idx, word_size, word_size.x}
				append(&sizes, cached)
			}
		} else {
			for idx < len(text) {
				rune, rune_size := utf8.decode_rune(text[idx:])
				start = idx
				idx += rune_size

				letter := text[start:idx]
				token := Cached_Token {
					start = start,
					end   = idx,
				}

				if rune == ' ' {
					token.size = space_size
					token.step = space_size.x + opts.letter_spacing
				} else {
					token.size = measure_text(letter, opts)
					token.step = token.size.x + opts.letter_spacing
				}

				append(&sizes, token)
			}
		}
		cache^ = sizes
	}

	return cache^[:]
}

