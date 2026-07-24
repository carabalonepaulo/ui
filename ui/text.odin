package ui

import "core:unicode/utf8"

@(private = "file")
Cached_Token :: struct {
	start, end: int,
	size:       Vec2,
	step:       f64,
}

Text_Wrap :: enum {
	None,
	Word,
	Letter,
}

Text_Sroll :: enum {
	None,
	X,
	Y,
	Both,
}

Text_Options :: struct {
	wrap:           Text_Wrap,
	letter_spacing: f64,
	line_spacing:   f64,
	font:           Font,
	font_size:      f64,
	font_color:     Color,
	scroll:         Text_Sroll,
}

text :: proc(uid: Id, size: Vec2, text: string, opts: Text_Options, flags: Scope_Flags = {}) {
	size := size
	if size.x == AUTO && size.y == AUTO do size.y = opts.font_size

	text := text
	opts := opts

	if size.x == AUTO {
		opts.wrap = .None
		if opts.scroll == .X do opts.scroll = .None
		else if opts.scroll == .Both do opts.scroll = .Y
	}

	if size.y == AUTO {
		if opts.scroll == .Y do opts.scroll = .None
		else if opts.scroll == .Both do opts.scroll = .X
	}

	is_fit := size.x == AUTO || size.y == AUTO
	fit: Fit

	if is_fit do fit = begin_fit(id(uid, "fit"), size, flags)
	else do begin_scope(size, flags)
	defer {
		if is_fit do end_fit(fit)
		else do end_scope()
	}

	container := get_scope()
	container_size := get_size()

	if opts.scroll == .X || opts.scroll == .Both {
		bind(.Scroll_X, get(id(uid, 'x'), f64))
	}

	if opts.scroll == .Y || opts.scroll == .Both {
		bind(.Scroll_Y, get(id(uid, 'y'), f64))
	}

	text_id := get_text_id(uid, text, &opts)
	text_size := get_text_size(text_id, text, &opts)

	if (text_size.x < container_size.x && text_size.y < container_size.y) || opts.wrap == .None {
		draw_text(opts.font, text, {}, opts.font_size, opts.letter_spacing, opts.font_color)
		container.content_size = text_size
		return
	}

	available := container_size.x
	max_width: f64 = 0

	tokens := get_token_cache(id(text_id, "cache"), text, &opts)
	for i in 0 ..< len(tokens) {
		token := text[tokens[i].start:tokens[i].end]
		token_size := tokens[i].size
		step := tokens[i].step
		draw(container, &available, &max_width, token, token_size, step, &opts)
	}

	final_width := size.x != AUTO ? clamp(max_width, 0, container.size.x) : max_width
	container.content_size = {final_width, container.cursor.y + opts.font_size}
}

@(private = "file")
draw :: proc(
	container: ^Scope,
	available: ^f64,
	max_width: ^f64,
	text: string,
	text_size: Vec2,
	step: f64,
	opts: ^Text_Options,
) {
	if container.cursor.x > 0 && available^ - text_size.x < 0 {
		if container.cursor.x > max_width^ do max_width^ = container.cursor.x
		container.cursor.y += opts.font_size + opts.line_spacing
		container.cursor.x = 0
		available^ = container.size.x
	}

	draw_text(
		opts.font,
		text,
		container.cursor,
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
						word_size := ctx.callbacks.measure_text(
							opts.font,
							text[start:end],
							opts.font_size,
							opts.letter_spacing,
						)
						cached := Cached_Token{start, end, word_size, word_size.x + space_size.x}
						append(&sizes, cached)
					}
					start = idx
				}
			}

			if start < idx {
				word_size := ctx.callbacks.measure_text(
					opts.font,
					text[start:idx],
					opts.font_size,
					opts.letter_spacing,
				)
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
					word_size := ctx.callbacks.measure_text(
						opts.font,
						letter,
						opts.font_size,
						opts.letter_spacing,
					)
					token.step = token.size.x + opts.letter_spacing
				}

				append(&sizes, token)
			}
		}
		cache^ = sizes
	}

	return cache^[:]
}

get_text_id :: #force_inline proc(uid: Id, text: string, opts: ^Text_Options) -> Id {
	return id(uid, text, opts.font, opts.font_size, opts.letter_spacing, opts.line_spacing)
}

measure_text :: proc(
	uid: Id,
	container_size: Vec2,
	text: string,
	opts: ^Text_Options,
	padding: Padding = {},
) -> Vec2 {
	text_id := get_text_id(uid, text, opts)
	text_size := get_text_size(text_id, text, opts)

	if (text_size.x < container_size.x && text_size.y < container_size.y) || opts.wrap == .None {
		return {
			text_size.x + padding.left + padding.right,
			text_size.y + padding.top + padding.bottom,
		}
	}

	layout_size_id := id(text_id, container_size.x, "layout_size")
	layout_size, just_created := get(layout_size_id, Vec2)
	if just_created {
		available := container_size.x
		max_width: f64 = 0
		cursor: Vec2 = {}

		tokens := get_token_cache(id(text_id, "cache"), text, opts)
		for i in 0 ..< len(tokens) {
			token := text[tokens[i].start:tokens[i].end]
			token_size := tokens[i].size
			step := tokens[i].step

			if cursor.x > 0 && available - token_size.x < 0 {
				if cursor.x > max_width do max_width = cursor.x
				cursor.y += opts.font_size + opts.line_spacing
				cursor.x = 0
				available = container_size.x
			}

			cursor.x += step
			available -= step
		}

		final_width := container_size.x != AUTO ? clamp(max_width, 0, container_size.x) : max_width
		layout_size^ = {final_width, cursor.y + opts.font_size}
	}

	size := layout_size^
	return {size.x + padding.left + padding.right, size.y + padding.top + padding.bottom}
}

