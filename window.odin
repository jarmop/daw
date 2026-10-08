#+feature dynamic-literals

package daw

import "base:runtime"
import "core:fmt"
import "core:math"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"

WINDOW_WIDTH: i32 = 800
WINDOW_HEIGHT: i32 = 600

window: glfw.WindowHandle

waveform_key_map := map[i32]Waveform {
	glfw.KEY_1 = .Sine,
	glfw.KEY_2 = .Square,
	glfw.KEY_3 = .Triangle,
	glfw.KEY_4 = .Sawtooth,
}

left_mouse_pressed := false
left_mouse_first_press := true
x_prev: f32 = 0

window_init :: proc() {
	glfw.Init()
	window = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "DAW", nil, nil)

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	glfw.MakeContextCurrent(window)

	gl.load_up_to(3, 3, glfw.gl_set_proc_address)
	// gl.Viewport(0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
	glfw.SetFramebufferSizeCallback(window, framebuffer_size_callback)
	glfw.SetKeyCallback(window, key_callback)
	glfw.SetMouseButtonCallback(window, mouse_button_callback)
	glfw.SetCursorPosCallback(window, cursor_pos_callback)
}

framebuffer_size_callback :: proc "c" (window: glfw.WindowHandle, width: i32, height: i32) {
	gl.Viewport(0, 0, width, height)
	WINDOW_WIDTH = width
	WINDOW_HEIGHT = height
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mode: i32) {
	context = runtime.default_context()

	if action != glfw.PRESS {
		return
	}

	if key in waveform_key_map {
		selected_waveform = waveform_key_map[key]
	} else if key == glfw.KEY_ESCAPE {
		glfw.SetWindowShouldClose(window, true)
	}

	track_key_callback(key, int(scancode), mode)
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	context = runtime.default_context()

	if button == glfw.MOUSE_BUTTON_LEFT {
		if action == glfw.PRESS {
			left_mouse_pressed = true

			button_on_left_click()
		} else {
			left_mouse_pressed = false
			left_mouse_first_press = true
		}
	}

	slider_mouse_button_callback(window, button, action)

	track_mouse_button_callback(window, button, action)
}

cursor_pos_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	context = runtime.default_context()

	if left_mouse_pressed {
		x := f32(xpos)
		if left_mouse_first_press {
			x_prev = x
			left_mouse_first_press = false
		}
		x_diff := x - x_prev
		x_prev = x

		slider_cursor_drag_callback(x, x_diff)

		track_cursor_drag_callback(x, x_diff)

	} else {
		is_cursor_set := slider_cursor_hover_callback(window)
		is_cursor_set = track_cursor_hover_callback(window) || is_cursor_set
		is_cursor_set = button_cursor_hover_callback(window) || is_cursor_set

		if !is_cursor_set {
			glfw.SetCursor(window, nil)
		}
	}
}
