package daw

import "core:fmt"
import "core:os"

import gl "vendor:OpenGL"

import stbtt "vendor:stb/truetype"

FONT_BITMAP_W :: 512
FONT_BITMAP_H :: 512
GLYPH_COUNT :: 96
FIRST_PRINTABLE_ASCII :: 32
LAST_PRINTABLE_ASCII :: 127

Glyph :: struct {
	x0, y0:   f32,
	x1, y1:   f32,
	s0, t0:   f32,
	s1, t1:   f32,
	xadvance: f32,
}

// baked_chars := make([96]stbtt.bakedchar)
// baked_chars: [GLYPH_COUNT]stbtt.bakedchar
packed_chars: [GLYPH_COUNT]stbtt.packedchar

text_program: u32
text_texture: u32
text_vao: u32
text_vbo: u32

text_vertices: [dynamic]f32

font_size :: 14
line_height :: font_size + 2

text_init :: proc() {
	gl.Enable(gl.BLEND)
	gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA)

	// -----------------------------------------
	// Load shaders
	// -----------------------------------------

	shaders_ok: bool
	text_program, shaders_ok = gl.load_shaders_file("./shaders/text.vs", "./shaders/text.fs")
	if !shaders_ok {
		fmt.println("Shaders not ok")
		os.exit(-1)
	}

	// -----------------------------------------
	// Load font
	// -----------------------------------------

	font_file := "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf"
	// font_file := "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"

	font_data, err := os.read_entire_file_from_path(font_file, context.allocator)

	assert(err == nil)

	bitmap := make([]u8, FONT_BITMAP_W * FONT_BITMAP_H)

	pc: stbtt.pack_context

	stbtt.PackBegin(&pc, raw_data(bitmap), FONT_BITMAP_W, FONT_BITMAP_H, 0, 1, nil)
	stbtt.PackSetOversampling(&pc, 2, 2)
	stbtt.PackFontRange(&pc, raw_data(font_data), 0, font_size, 32, 95, &packed_chars[0])
	stbtt.PackEnd(&pc)

	// -----------------------------------------
	// Upload texture
	// -----------------------------------------

	gl.GenTextures(1, &text_texture)
	gl.BindTexture(gl.TEXTURE_2D, text_texture)

	// gl.PixelStorei(gl.UNPACK_ALIGNMENT, 1)

	gl.TexImage2D(
		gl.TEXTURE_2D,
		0,
		gl.RED,
		FONT_BITMAP_W,
		FONT_BITMAP_H,
		0,
		gl.RED,
		gl.UNSIGNED_BYTE,
		raw_data(bitmap),
	)

	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR)
	gl.TexParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR)


	// -----------------------------------------
	// Vertex setup
	// -----------------------------------------

	gl.GenVertexArrays(1, &text_vao)
	gl.BindVertexArray(text_vao)

	gl.GenBuffers(1, &text_vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, text_vbo)

	gl.EnableVertexAttribArray(0)
	gl.VertexAttribPointer(0, 2, gl.FLOAT, false, 4 * size_of(f32), uintptr(0))

	gl.EnableVertexAttribArray(1)
	gl.VertexAttribPointer(1, 2, gl.FLOAT, false, 4 * size_of(f32), uintptr(2 * size_of(f32)))
}

text_add_vertices :: proc(text: string, start: [2]f32, max_width: f32) -> (f32, f32) {
	x := start.x
	y := start.y

	height: f32 = font_size
	for c in text {
		if x > start.x + max_width {
			x = start.x
			y = y + font_size + 4
			height = height + font_size + 4
		}

		if c < FIRST_PRINTABLE_ASCII || c > LAST_PRINTABLE_ASCII {
			continue
		}

		q: stbtt.aligned_quad

		stbtt.GetPackedQuad(
			&packed_chars[0],
			FONT_BITMAP_W,
			FONT_BITMAP_H,
			i32(c - FIRST_PRINTABLE_ASCII),
			&x,
			&y,
			&q,
			false,
		)

		append(
			&text_vertices,
			q.x0,
			q.y0,
			q.s0,
			q.t0,
			q.x1,
			q.y0,
			q.s1,
			q.t0,
			q.x1,
			q.y1,
			q.s1,
			q.t1,
			q.x0,
			q.y0,
			q.s0,
			q.t0,
			q.x1,
			q.y1,
			q.s1,
			q.t1,
			q.x0,
			q.y1,
			q.s0,
			q.t1,
		)
	}

	return x - start.x, height
}

get_text_dimensions :: proc(text: string, max_width: f32) -> (f32, f32) {
	start: [2]f32 = {0, 0}
	x := start.x
	y := start.y

	height: f32 = font_size
	for c in text {
		if x > start.x + max_width {
			x = start.x
			y = y + font_size + 4
			height = height + font_size + 4
		}

		if c < FIRST_PRINTABLE_ASCII || c > LAST_PRINTABLE_ASCII {
			continue
		}

		q: stbtt.aligned_quad

		stbtt.GetPackedQuad(
			&packed_chars[0],
			FONT_BITMAP_W,
			FONT_BITMAP_H,
			i32(c - FIRST_PRINTABLE_ASCII),
			&x,
			&y,
			&q,
			false,
		)
	}

	return x - start.x, height
}

text_set_buffer_data :: proc() {
	// gl.BindVertexArray(text_vao)
	gl.BindBuffer(gl.ARRAY_BUFFER, text_vbo)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(text_vertices) * size_of(f32),
		raw_data(text_vertices),
		gl.DYNAMIC_DRAW,
		// gl.STATIC_DRAW,
	)
}

text_draw :: proc() {
	gl.UseProgram(text_program)

	shader_set_vec2(ui_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})

	gl.ActiveTexture(gl.TEXTURE0)
	gl.BindTexture(gl.TEXTURE_2D, text_texture)

	gl.BindVertexArray(text_vao)
	gl.DrawArrays(gl.TRIANGLES, 0, i32(len(text_vertices) / 4))
}
