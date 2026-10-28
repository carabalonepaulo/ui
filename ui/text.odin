package ui

import "core:unicode/utf8"

@(private = "file")
Cached_Token :: struct {
	start, end: int,
	// Ink size of the token: the measured word (`.Word`) or rune (`.Letter`).
	size:       Vec2,
	// Horizontal gap before this token: the spaces that precede a word, or the
	// letter spacing between two runes. A wrapped token drops its gap, so a line
	// never starts with whitespace and line widths never include trailing
	// whitespace.
	lead:       f64,
}

@(private = "file")
Token_Cache :: struct {
	tokens: [dynamic]Cached_Token,
	valid:  bool,
}

@(private = "file")
destroy_token_cache :: proc(cache: ^Token_Cache) {
	delete(cache.tokens)
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

	if fits(text_size, container_size) || opts.wrap == .None {
		// Keep the token cache alive across frames that take the fast path, so an
		// animating width does not rebuild it every other frame.
		if opts.wrap != .None do touch_token_cache(text_id, opts.wrap)

		draw_text(opts.font, text, {}, opts.font_size, opts.letter_spacing, opts.font_color)
		container.content_size = text_size
		return
	}

	tokens := get_token_cache(text_id, text, &opts)
	container.content_size = run_layout(tokens, text, container_size, &opts, draw = true)
}

// Lays the tokens out and returns the content size. With `draw`, every token is
// emitted at its final position in the current scope. `measure_text` runs the
// same loop without drawing, so measuring and drawing cannot disagree.
@(private = "file")
run_layout :: proc(
	tokens: []Cached_Token,
	text: string,
	container_size: Vec2,
	opts: ^Text_Options,
	draw: bool,
) -> Vec2 {
	x, y: f64
	available := container_size.x
	max_width: f64
	line_height := opts.font_size + opts.line_spacing

	for i in 0 ..< len(tokens) {
		token := tokens[i]

		if x > 0 && available - token.lead - token.size.x < 0 {
			max_width = max(max_width, x)
			x = 0
			y += line_height
			available = container_size.x
		} else {
			x += token.lead
			available -= token.lead
		}

		if draw {
			draw_text(
				opts.font,
				text[token.start:token.end],
				{x, y},
				opts.font_size,
				opts.letter_spacing,
				opts.font_color,
			)
		}

		x += token.size.x
		available -= token.size.x
		max_width = max(max_width, x)
	}

	width := max_width
	if container_size.x != AUTO do width = clamp(width, 0, container_size.x)

	return {width, y + opts.font_size}
}

@(private = "file")
fits :: proc(text_size, container_size: Vec2) -> bool {
	return text_size.x <= container_size.x && text_size.y <= container_size.y
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
get_token_cache :: proc(text_id: Id, text: string, opts: ^Text_Options) -> []Cached_Token {
	cache := get(
		id(text_id, opts.wrap, "cache"),
		Token_Cache,
		destroy = destroy_token_cache,
	)

	if !cache.valid {
		build_tokens(cache, text, opts)
		cache.valid = true
	}

	return cache.tokens[:]
}

// Marks the token cache as used without building it, so the store does not evict
// it on frames where the text fits and the fast path draws it in one call.
@(private = "file")
touch_token_cache :: proc(text_id: Id, wrap: Text_Wrap) {
	_ = get(id(text_id, wrap, "cache"), Token_Cache, destroy = destroy_token_cache)
}

@(private = "file")
build_tokens :: proc(cache: ^Token_Cache, text: string, opts: ^Text_Options) {
	space_size := ctx.callbacks.measure_text(
		opts.font,
		" ",
		opts.font_size,
		opts.letter_spacing,
	)

	idx := 0
	start := 0
	lead: f64

	if opts.wrap == .Word {
		// Words are tokens; the spaces before a word become its `lead`. That keeps
		// runs of spaces intact and leaves trailing whitespace out of the line
		// width, because a wrapped token drops its lead.
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
					append(&cache.tokens, Cached_Token{start, end, word_size, lead})
					lead = space_size.x
				} else {
					lead += space_size.x
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
			append(&cache.tokens, Cached_Token{start, idx, word_size, lead})
		}
	} else {
		// One token per rune. `letter_spacing` is the gap before the next rune, so
		// it behaves like a lead and disappears at a line break.
		for idx < len(text) {
			rune, rune_size := utf8.decode_rune(text[idx:])
			start = idx
			idx += rune_size

			size := space_size
			if rune != ' ' {
				size = ctx.callbacks.measure_text(
					opts.font,
					text[start:idx],
					opts.font_size,
					opts.letter_spacing,
				)
			}

			append(&cache.tokens, Cached_Token{start, idx, size, lead})
			lead = opts.letter_spacing
		}
	}
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

	// `AUTO` disables wrapping, like in `text`. A width of -1 cannot lay anything
	// out, so the unclamped single-line size is the only useful answer.
	if container_size.x == AUTO || opts.wrap == .None || fits(text_size, container_size) {
		if container_size.x != AUTO && opts.wrap != .None do touch_token_cache(text_id, opts.wrap)

		return {
			text_size.x + padding.left + padding.right,
			text_size.y + padding.top + padding.bottom,
		}
	}

	layout_size_id := id(text_id, opts.wrap, container_size.x, "layout_size")
	layout_size, just_created := get(layout_size_id, Vec2)
	if just_created {
		tokens := get_token_cache(text_id, text, opts)
		layout_size^ = run_layout(tokens, text, container_size, opts, draw = false)
	}

	return {
		layout_size.x + padding.left + padding.right,
		layout_size.y + padding.top + padding.bottom,
	}
}
