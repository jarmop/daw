package daw

import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"

Vec2 :: [2]f32

Vertex :: struct {
	pos: Vec2,
}

padding :: 4

ui_run :: proc() {
	window_init()
	waveform_init()

	slider_init()
	sliders = {
		{pos = {110, line_height / 2}, value = &frequency, max = max_frequency},
		{pos = {110, line_height + line_height / 2}, value = &amplitude, max = max_amplitude},
		{
			pos = {110, 2 * line_height + line_height / 2},
			value = &envelope[0].duration,
			max = envelope_max_duration,
		},
	}

	button_init()
	buttons = {
		{pos = {WINDOW_WIDTH - button_width - padding, padding}, on_click = toggle_playback},
	}

	text_init()

	gl.ClearColor(0.5, 0.5, 0.5, 1)

	prev_playing := playing
	for !glfw.WindowShouldClose(window) {
		defer free_all(context.temp_allocator)

		glfw.PollEvents()

		if prev_playing != playing {
			prev_playing = playing
		}

		gl.Clear(gl.COLOR_BUFFER_BIT)

		ui_update()

		waveform_draw()
		slider_draw()
		button_draw()
		text_draw()

		glfw.SwapBuffers(window)
	}
}

waveform_vertices_update :: proc() {
	samples_count := 40
	waveform_vertices = make([]Vertex, samples_count)
	defer delete(waveform_vertices)

	for i in 0 ..< samples_count {
		phase := f32(i) / f32(samples_count - 1)
		sample := waveform_function_map[selected_waveform](phase)

		// Flip Y by using negative sample. Also divide Y by two so the total
		// height of the waveform is equal to the length.
		waveform_vertices[i].pos = Vec2{phase, -sample / 2} * waveform_size
	}

	vbo_update(&waveform_vbo, waveform_vertices[:])
}

ui_update :: proc() {
	clear(&text_vertices)

	width :: 120
	x :: padding
	y: f32

	y = font_size
	text_add_vertices(fmt.tprintf("Frequency: %d", int(frequency)), {x, y}, width)

	y += line_height
	text_add_vertices(fmt.tprintf("Amplitude: %.2f", amplitude), {x, y}, width)

	y += line_height
	text_add_vertices(fmt.tprintf("Attack: %.2f", envelope[0].duration), {x, y}, width)

	y += line_height
	text_add_vertices(fmt.tprintf("Decay: %.2f", envelope[1].duration), {x, y}, width)

	y += line_height
	text_add_vertices(fmt.tprintf("Sustain: %.2f", envelope[2].duration), {x, y}, width)

	y += line_height
	text_add_vertices(fmt.tprintf("Release: %.2f", envelope[3].duration), {x, y}, width)

	y += line_height
	waveform_text_width, _ := text_add_vertices(
		"Waveform: ",
		// fmt.tprintf("Waveform: %s", selected_waveform),
		{x, y},
		width,
	)
	wave_form_pos = {x + waveform_text_width, y - waveform_size.y / 2}
	waveform_vertices_update()

	play_button_text := playing ? "Stop" : "Play"
	play_button_text_max_width: f32 = button_width - 2 * button_padding_x

	text_width, text_height := get_text_dimensions(play_button_text, play_button_text_max_width)

	button_padding :: padding
	play_button := buttons[0]
	play_button_text_x_offset := (button_width - text_width) / 2
	play_button_text_pos :=
		play_button.pos + {play_button_text_x_offset, button_padding + font_size}
	text_add_vertices(play_button_text, play_button_text_pos, play_button_text_max_width)

	text_set_buffer_data()
}

make_quad :: proc(w, h: f32, x: f32 = 0, y: f32 = 0) -> [6]Vertex {
	bottom_left: Vec2 = {x, y}
	bottom_right: Vec2 = {x + w, y}
	top_left: Vec2 = {x, y + h}
	top_right: Vec2 = {x + w, y + h}

	// triangles
	return {
		{pos = bottom_left},
		{pos = bottom_right},
		{pos = top_left},
		{pos = top_left},
		{pos = top_right},
		{pos = bottom_right},
	}
}

make_quad_outline :: proc(w, h: f32, x: f32 = 0, y: f32 = 0) -> [4]Vertex {
	bottom_left: Vec2 = {x, y}
	bottom_right: Vec2 = {x + w, y}
	top_left: Vec2 = {x, y + h}
	top_right: Vec2 = {x + w, y + h}

	// outline
	return {{pos = bottom_left}, {pos = bottom_right}, {pos = top_right}, {pos = top_left}}
}


vbo_init :: proc(vbo: ^u32) {
	gl.GenBuffers(1, vbo)
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo^)

	gl.VertexAttribPointer(
		0,
		size_of(Vertex) / size_of(f32),
		gl.FLOAT,
		gl.FALSE,
		size_of(Vertex),
		0,
	)
	gl.EnableVertexAttribArray(0)
}

vbo_update :: proc(vbo: ^u32, vertices: []Vertex) {
	gl.BindBuffer(gl.ARRAY_BUFFER, vbo^)
	gl.BufferData(
		gl.ARRAY_BUFFER,
		len(vertices) * size_of(Vertex),
		raw_data(vertices),
		gl.STATIC_DRAW,
	)
}
