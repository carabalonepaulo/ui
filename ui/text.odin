package ui

import "core:unicode/utf8"

@(private = "file")
Token_Kind :: enum {
	// A drawable token: a word (`.Word`) or a rune (`.Letter`).
	Text,
	// A hard line break (`\n` or `\r\n`). Draws nothing.
	Break,
}

@(private = "file")
Cached_Token :: struct {
	kind:       Token_Kind,
	start, end: int,
	// Ink size of the token. Zero for a break.
	size:       Vec2,
	// Horizontal gap before this token: the spaces that precede a word, or the
	// letter spacing between two runes. A wrapped token drops its gap, so a line
	// never starts with whitespace and line widths never include trailing
	// whitespace. A hard break keeps the gap, which preserves indentation.
	lead:       f64,
}

// A tab advances this many spaces. `Text_Options.tab_spaces` overrides it.
@(private = "file")
TAB_SPACES :: 4

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
	// Width of a tab in spaces. Zero (the zero value) means `TAB_SPACES`.
	tab_spaces:     int,
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

	if !needs_token_layout(text) && (fits(text_size, container_size) || opts.wrap == .None) {
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
	wrap := opts.wrap != .None

	for token in tokens {
		if token.kind == .Break {
			max_width = max(max_width, x)
			x = 0
			y += line_height
			available = container_size.x
			continue
		}

		if wrap && x > 0 && available - token.lead - token.size.x < 0 {
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
	if wrap && container_size.x != AUTO do width = clamp(width, 0, container_size.x)

	return {width, y + opts.font_size}
}

// True when the text cannot be drawn with a single backend call: a hard break
// needs a new line, and a tab needs the expanded advance.
@(private = "file")
needs_token_layout :: proc(text: string) -> bool {
	for i in 0 ..< len(text) {
		switch text[i] {
		case '\n', '\r', '\t':
			return true
		}
	}
	return false
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

	spaces_per_tab := opts.tab_spaces > 0 ? opts.tab_spaces : TAB_SPACES
	tab_width := f64(spaces_per_tab) * space_size.x

	idx := 0
	word_start := 0
	lead: f64

	if opts.wrap != .Letter {
		// Words are tokens; the spaces before a word become its `lead`. That keeps
		// runs of spaces intact and leaves trailing whitespace out of the line
		// width, because a wrapped token drops its lead. A hard break keeps it, so
		// indentation after `\n` survives. `.None` uses the same tokenizer; only
		// the automatic wrap is disabled.
		for idx < len(text) {
			rune, rune_size := utf8.decode_rune(text[idx:])

			if rune == ' ' || rune == '\t' {
				if word_start < idx {
					append_word(cache, text, word_start, idx, lead, opts)
					lead = 0
				}

				lead += rune == '\t' ? tab_width : space_size.x
				idx += rune_size
				word_start = idx
				continue
			}

			if rune == '\n' || rune == '\r' {
				if word_start < idx {
					append_word(cache, text, word_start, idx, lead, opts)
				}

				// Whitespace before a break is invisible.
				lead = 0

				idx += rune_size
				if rune == '\r' && idx < len(text) && text[idx] == '\n' do idx += 1

				append_break(cache)

				word_start = idx
				continue
			}

			idx += rune_size
		}

		if word_start < idx {
			append_word(cache, text, word_start, idx, lead, opts)
		}
	} else {
		// One token per rune. `letter_spacing` is the gap before the next rune, so
		// it behaves like a lead and disappears at a wrapped line break.
		for idx < len(text) {
			rune, rune_size := utf8.decode_rune(text[idx:])

			if rune == '\n' || rune == '\r' {
				lead = 0

				idx += rune_size
				if rune == '\r' && idx < len(text) && text[idx] == '\n' do idx += 1

				append_break(cache)
				continue
			}

			start := idx
			idx += rune_size

			if rune == '\t' {
				lead += tab_width
				continue
			}

			size := space_size
			if rune != ' ' {
				size = ctx.callbacks.measure_text(
					opts.font,
					text[start:idx],
					opts.font_size,
					opts.letter_spacing,
				)
			}

			append(
				&cache.tokens,
				Cached_Token {
					kind = .Text,
					start = start,
					end = idx,
					size = size,
					lead = lead,
				},
			)
			lead = opts.letter_spacing
		}
	}
}

@(private = "file")
append_word :: proc(
	cache: ^Token_Cache,
	text: string,
	start, end: int,
	lead: f64,
	opts: ^Text_Options,
) {
	if start >= end do return

	size := ctx.callbacks.measure_text(
		opts.font,
		text[start:end],
		opts.font_size,
		opts.letter_spacing,
	)

	append(
		&cache.tokens,
		Cached_Token{kind = .Text, start = start, end = end, size = size, lead = lead},
	)
}

@(private = "file")
append_break :: proc(cache: ^Token_Cache) {
	append(&cache.tokens, Cached_Token{kind = .Break})
}

get_text_id :: #force_inline proc(uid: Id, text: string, opts: ^Text_Options) -> Id {
	return id(
		uid,
		text,
		opts.font,
		opts.font_size,
		opts.letter_spacing,
		opts.line_spacing,
		opts.tab_spaces,
	)
}

measure_text :: proc(
	uid: Id,
	container_size: Vec2,
	text: string,
	opts: ^Text_Options,
	padding: Padding = {},
) -> Vec2 {
	options := opts^
	if container_size.x == AUTO do options.wrap = .None

	text_id := get_text_id(uid, text, &options)
	text_size := get_text_size(text_id, text, &options)

	// `AUTO` disables wrapping, like in `text`. A width of -1 cannot lay anything
	// out, so the unclamped single-line size is the only useful answer.
	if !needs_token_layout(text) && (options.wrap == .None || fits(text_size, container_size)) {
		if options.wrap != .None do touch_token_cache(text_id, options.wrap)

		return {
			text_size.x + padding.left + padding.right,
			text_size.y + padding.top + padding.bottom,
		}
	}

	layout_size_id := id(text_id, options.wrap, container_size.x, "layout_size")
	layout_size, just_created := get(layout_size_id, Vec2)
	if just_created {
		tokens := get_token_cache(text_id, text, &options)
		layout_size^ = run_layout(tokens, text, container_size, &options, draw = false)
	}

	return {
		layout_size.x + padding.left + padding.right,
		layout_size.y + padding.top + padding.bottom,
	}
}
