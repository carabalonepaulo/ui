package demo

import "core:fmt"
import "core:math"
import "core:os"
import ui "../ui"
import fs "vendor:fontstash"
import rl "vendor:raylib"

// Fontstash keeps a single-channel (alpha) atlas. Raylib's default shader
// expects RGBA, so we expand the dirty region into white RGB + glyph alpha and
// upload that. Uploads only happen when a new glyph is rasterized.
ATLAS_INIT_SIZE :: 1024
MAX_FONTS :: 8

Renderer :: struct {
	fs:           fs.FontContext,
	atlas:        rl.Texture2D,
	scratch:      []u8,
	font_ids:     [MAX_FONTS]int,
	font_count:   int,
	default_font: ui.Font,
}

renderer_init :: proc(r: ^Renderer) {
	fs.Init(&r.fs, ATLAS_INIT_SIZE, ATLAS_INIT_SIZE, .TOPLEFT)
	renderer_ensure_atlas(r)

	r.default_font = renderer_load_font(
		r,
		"regular",
		asset_path("assets/fonts/StrichpunktSans-Regular.ttf"),
	)
	renderer_load_font(r, "bold", asset_path("assets/fonts/StrichpunktSans-Bold.ttf"))
}

// Works from the repository root (`odin run demo`) and from `demo/` (`just run`).
asset_path :: proc(relative: string) -> string {
	from_demo := fmt.aprintf("demo/%s", relative, allocator = context.temp_allocator)
	if os.exists(from_demo) do return from_demo
	return relative
}

renderer_deinit :: proc(r: ^Renderer) {
	if r.atlas.id != 0 {
		rl.UnloadTexture(r.atlas)
		r.atlas = {}
	}
	delete(r.scratch)
	r.scratch = nil
	fs.Destroy(&r.fs)
}

renderer_load_font :: proc(r: ^Renderer, name, path: string) -> ui.Font {
	assert(r.font_count < MAX_FONTS, "too many fonts")

	id := fs.AddFontPath(&r.fs, name, path)
	assert(id >= 0, "failed to load font")

	r.font_ids[r.font_count] = id
	font := ui.Font(r.font_count)
	r.font_count += 1
	return font
}

renderer_font_index :: proc(r: ^Renderer, font: ui.Font) -> int {
	index := int(u64(font))
	if index >= 0 && index < r.font_count {
		return r.font_ids[index]
	}
	return r.font_ids[0]
}

// (Re)creates the GPU atlas if fontstash grew it. The new mirror texture starts
// empty; the pending dirty rectangle from fontstash re-uploads the used area
// before it is sampled.
renderer_ensure_atlas :: proc(r: ^Renderer) {
	w := r.fs.width
	h := r.fs.height

	if r.atlas.id != 0 && int(r.atlas.width) == w && int(r.atlas.height) == h {
		return
	}

	if r.atlas.id != 0 {
		rl.UnloadTexture(r.atlas)
	}

	data := make([]u8, w * h * 4)
	for i in 0 ..< w * h {
		data[i * 4 + 0] = 0xff
		data[i * 4 + 1] = 0xff
		data[i * 4 + 2] = 0xff
		data[i * 4 + 3] = 0
	}

	image := rl.Image {
		data    = raw_data(data),
		width   = i32(w),
		height  = i32(h),
		mipmaps = 1,
		format  = .UNCOMPRESSED_R8G8B8A8,
	}
	r.atlas = rl.LoadTextureFromImage(image)
	delete(data)

	assert(r.atlas.id != 0, "failed to create the font atlas")
	rl.SetTextureFilter(r.atlas, .BILINEAR)
}

renderer_flush_atlas :: proc(r: ^Renderer) {
	renderer_ensure_atlas(r)

	dirty: [4]f32
	if !fs.ValidateTexture(&r.fs, &dirty) do return

	w := r.fs.width
	h := r.fs.height

	x0 := clamp(int(math.floor(f64(dirty[0]))), 0, w)
	y0 := clamp(int(math.floor(f64(dirty[1]))), 0, h)
	x1 := clamp(int(math.ceil(f64(dirty[2]))), 0, w)
	y1 := clamp(int(math.ceil(f64(dirty[3]))), 0, h)

	dw := x1 - x0
	dh := y1 - y0
	if dw <= 0 || dh <= 0 do return

	if len(r.fs.textureData) != w * h {
		fmt.eprintln(
			"font atlas mismatch: dirty", dirty,
			"w/h", w, h,
			"data", len(r.fs.textureData),
			"atlas", r.atlas.width, r.atlas.height,
			"fs", r.fs.width, r.fs.height,
		)
		return
	}

	// UpdateTextureRec expects tightly packed pixels for the sub-rectangle.
	// This can be larger than the UI frame arena, so keep a persistent scratch
	// buffer on the normal allocator instead of allocating it per frame.
	needed := dw * dh * 4
	if len(r.scratch) < needed {
		delete(r.scratch)
		r.scratch = make([]u8, needed)
	}
	pixels := r.scratch[:needed]
	if len(pixels) != needed {
		fmt.eprintln("font atlas: out of memory for staging buffer", needed)
		return
	}

	for y in 0 ..< dh {
		source := r.fs.textureData[(y0 + y) * w + x0:]
		if len(source) < dw {
			fmt.eprintln("font atlas short row", y, "len", len(source), "dw", dw)
			return
		}
		dest := pixels[y * dw * 4:]
		for x in 0 ..< dw {
			dest[x * 4 + 0] = 0xff
			dest[x * 4 + 1] = 0xff
			dest[x * 4 + 2] = 0xff
			dest[x * 4 + 3] = source[x]
		}
	}

	rec := rl.Rectangle{f32(x0), f32(y0), f32(dw), f32(dh)}
	rl.UpdateTextureRec(r.atlas, rec, raw_data(pixels))
}

// Measures text in physical pixels.
renderer_measure :: proc(
	r: ^Renderer,
	font: ui.Font,
	text: string,
	pixel_size: f64,
	pixel_spacing: f64,
) -> ui.Vec2 {
	fs.PushState(&r.fs)
	fs.SetFont(&r.fs, renderer_font_index(r, font))
	fs.SetSize(&r.fs, f32(pixel_size))
	fs.SetSpacing(&r.fs, f32(pixel_spacing))
	fs.SetBlur(&r.fs, 0)
	fs.SetAlignHorizontal(&r.fs, .LEFT)
	fs.SetAlignVertical(&r.fs, .TOP)

	width := fs.TextBounds(&r.fs, text)

	fs.PopState(&r.fs)

	// Match the UI's line advance (font_size + line_spacing). The exact glyph
	// bounds can be taller because of descenders; that is what clipping and
	// line_spacing are for.
	return {f64(width), pixel_size}
}

// Draws text in physical pixels. Fontstash rasterizes glyphs at the requested
// pixel size, so this stays crisp at any UI scale and supersampling factor.
renderer_draw_text :: proc(
	r: ^Renderer,
	font: ui.Font,
	text: string,
	x, y: f64,
	pixel_size, pixel_spacing: f64,
	color: ui.Color,
) {
	if len(text) == 0 do return

	font_index := renderer_font_index(r, font)
	tint := transmute(rl.Color)(color)

	// Growing the atlas changes normalized UVs. Rasterize again with the new
	// size; the glyphs are already cached, so the second pass cannot grow again.
	for _ in 0 ..< 4 {
		atlas_w := r.fs.width
		atlas_h := r.fs.height

		fs.PushState(&r.fs)
		fs.SetFont(&r.fs, font_index)
		fs.SetSize(&r.fs, f32(pixel_size))
		fs.SetSpacing(&r.fs, f32(pixel_spacing))
		fs.SetBlur(&r.fs, 0)
		fs.SetAlignHorizontal(&r.fs, .LEFT)
		fs.SetAlignVertical(&r.fs, .TOP)

		quads := make([dynamic]fs.Quad, 0, max(1, len(text)), ui.get_temp_allocator())
		iter := fs.TextIterInit(&r.fs, f32(x), f32(y), text)
		quad: fs.Quad
		for fs.TextIterNext(&r.fs, &iter, &quad) {
			if iter.previousGlyphIndex == -1 {
				continue // glyph missing or atlas exhausted
			}
			append(&quads, quad)
		}
		fs.PopState(&r.fs)

		if r.fs.width != atlas_w || r.fs.height != atlas_h {
			continue
		}

		renderer_flush_atlas(r)

		aw := f32(atlas_w)
		ah := f32(atlas_h)
		for q in quads {
			w := q.x1 - q.x0
			h := q.y1 - q.y0
			if w <= 0 || h <= 0 do continue

			source := rl.Rectangle {
				q.s0 * aw,
				q.t0 * ah,
				(q.s1 - q.s0) * aw,
				(q.t1 - q.t0) * ah,
			}
			dest := rl.Rectangle{q.x0, q.y0, w, h}
			rl.DrawTexturePro(r.atlas, source, dest, {0, 0}, 0, tint)
		}

		return
	}
}
