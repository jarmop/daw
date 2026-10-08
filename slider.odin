package daw

import "core:fmt"
import "core:math/linalg/glsl"
import "core:os"
import gl "vendor:OpenGL"
import "vendor:glfw"

slider_bar_vao: u32
slider_bar_vertices: [6]Vertex

slider_handle_vao: u32
slider_handle_vertices: [6]Vertex

Slider :: struct {
	pos:              Vec2,
	value:            ^f32,
	max:              f32,
	on_value_changed: proc(),
}

bar_width: f32 = 100
bar_height: f32 = 2
handle_size :: font_size

slider_init :: proc() {
	// --------------
	// Slider bar
	// --------------

	gl.GenVertexArrays(1, &slider_bar_vao)
	gl.BindVertexArray(slider_bar_vao)

	slider_bar_vbo: u32
	vbo_init(&slider_bar_vbo)

	slider_bar_vertices = make_quad(bar_width, bar_height)
	vbo_update(&slider_bar_vbo, slider_bar_vertices[:])

	// --------------
	// Slider handle
	// --------------

	gl.GenVertexArrays(1, &slider_handle_vao)
	gl.BindVertexArray(slider_handle_vao)

	slider_handle_vbo: u32
	vbo_init(&slider_handle_vbo)

	x2: f32 = -handle_size / 2
	y2: f32 = (-handle_size + bar_height) / 2
	slider_handle_vertices = make_quad(handle_size, handle_size, x2, y2)
	vbo_update(&slider_handle_vbo, slider_handle_vertices[:])
}

slider_draw :: proc() {
	gl.UseProgram(ui_program)

	shader_set_vec2(ui_program, "screen_size", {f32(WINDOW_WIDTH), f32(WINDOW_HEIGHT)})

	for slider in sliders {
		shader_set_vec2(ui_program, "mesh_pos", slider.pos)
		c: f32 = 0.2
		shader_set_vec4(ui_program, "color", {c, c, c, 1})
		gl.BindVertexArray(slider_bar_vao)
		gl.DrawArrays(gl.TRIANGLES, 0, i32(len(slider_bar_vertices)))

		handle_x := slider.value^ / slider.max * bar_width
		handle_pos := slider.pos + {handle_x, 0}

		shader_set_vec2(ui_program, "mesh_pos", handle_pos)
		c = 0.3
		shader_set_vec4(ui_program, "color", {c, c, c, 1})
		gl.BindVertexArray(slider_handle_vao)
		gl.DrawArrays(gl.TRIANGLES, 0, i32(len(slider_handle_vertices)))
	}
}


// ------------------------------------------------
//
//                 WINDOW CALLBACKS
//
// ------------------------------------------------

slider_dragged: ^Slider
slider_hovered: ^Slider
is_slider_handle_hovered := false

slider_mouse_button_callback :: proc(window: glfw.WindowHandle, button, action: i32) {
	if button == glfw.MOUSE_BUTTON_LEFT {
		if action == glfw.PRESS && slider_hovered != nil {
			if is_slider_handle_hovered {
				// Grab handle
				slider_dragged = slider_hovered
			} else {
				// Move handle where the cursor is and then grab it
				x64, y64 := glfw.GetCursorPos(window)
				x := f32(x64)
				s := slider_hovered

				s.value^ = (x - s.pos.x) / bar_width * s.max
				s.on_value_changed()

				is_slider_handle_hovered = true
				slider_dragged = slider_hovered
			}
		} else {
			slider_dragged = nil
		}
	}
}

slider_cursor_drag_callback :: proc(x: f32, x_diff: f32) {
	if slider_dragged != nil {
		s := slider_dragged
		s_start := s.pos.x
		s_end := s.pos.x + bar_width
		if x < s_start {
			if x_diff > 0 {
				return
			} else if s.value^ != 0 {
				s.value^ = 0
			}
		} else if x > s_end {
			if x_diff < 0 {
				return
			} else if s.value^ != s.max {
				s.value^ = s.max
			}
		} else {
			s.value^ = s.value^ + (f32(x_diff) / bar_width * s.max)
		}

		s.on_value_changed()
	}
}

slider_cursor_hover_callback :: proc(window: glfw.WindowHandle) -> bool {
	slider_hovered = cursor_within_slider_bar()
	if slider_hovered != nil {
		x64, y64 := glfw.GetCursorPos(window)
		x := f32(x64)
		y := f32(y64)
		s := slider_hovered
		handle_x := s.value^ / s.max * bar_width - handle_size / 2
		handle_y := (-handle_size + bar_height) / 2
		handle_pos := s.pos + {handle_x, handle_y}
		is_slider_handle_hovered =
			x >= handle_pos.x &&
			x <= handle_pos.x + handle_size &&
			y >= handle_pos.y &&
			y <= handle_pos.y + handle_size

		glfw.SetCursor(window, glfw.CreateStandardCursor(glfw.POINTING_HAND_CURSOR))
		return true
	}

	is_slider_handle_hovered = false

	return false
}

cursor_within_slider_handle :: proc() -> ^Slider {
	x64, y64 := glfw.GetCursorPos(window)
	x := f32(x64)
	y := f32(y64)
	handle_y := (-handle_size + bar_height) / 2

	for &slider, i in sliders {
		handle_x := slider.value^ / slider.max * bar_width - handle_size / 2
		handle_pos := slider.pos + {handle_x, handle_y}

		if (x >= handle_pos.x &&
			   x <= handle_pos.x + handle_size &&
			   y >= handle_pos.y &&
			   y <= handle_pos.y + handle_size) {
			return &slider
		}
	}

	return nil
}

cursor_within_slider_bar :: proc() -> ^Slider {
	x64, y64 := glfw.GetCursorPos(window)
	x := f32(x64)
	y := f32(y64)
	handle_y := (-handle_size + bar_height) / 2

	for &s, i in sliders {
		y_start := s.pos.y - handle_size / 2
		y_end := y_start + handle_size
		if x >= s.pos.x && x <= s.pos.x + bar_width && y >= y_start && y < y_end {
			return &s
		}
	}

	return nil
}
