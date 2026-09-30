#+feature dynamic-literals

package daw

import "base:runtime"
import "core:fmt"
import gl "vendor:OpenGL"
import glfw "vendor:glfw"

WINDOW_WIDTH :: 800
WINDOW_HEIGHT :: 600

window: glfw.WindowHandle

waveform_key_map := map[i32]Waveform {
	glfw.KEY_1 = .Sine,
	glfw.KEY_2 = .Square,
	glfw.KEY_3 = .Triangle,
	glfw.KEY_4 = .Sawtooth,
}

left_mouse_pressed := false
left_mouse_first_press := true
xpos_prev: f64 = 0
slider_dragged: ^Slider
slider_hovered: ^Slider
button_hovered: ^Button

window_init :: proc() {
	glfw.Init()
	window = glfw.CreateWindow(WINDOW_WIDTH, WINDOW_HEIGHT, "DAW", nil, nil)

	glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
	glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)

	glfw.MakeContextCurrent(window)

	gl.load_up_to(3, 3, glfw.gl_set_proc_address)
	// gl.Viewport(0, 0, INITIAL_WINDOW_WIDTH, INITIAL_WINDOW_HEIGHT)

	glfw.SetKeyCallback(window, key_callback)
	glfw.SetMouseButtonCallback(window, mouse_button_callback)
	glfw.SetCursorPosCallback(window, cursor_pos_callback)
}

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode, action, mode: i32) {
	context = runtime.default_context()

	if action != glfw.PRESS {
		return
	}

	if key == glfw.KEY_ESCAPE {
		glfw.SetWindowShouldClose(window, true)
	} else if key in waveform_key_map {
		selected_waveform = waveform_key_map[key]
	} else if key == glfw.KEY_SPACE {
		toggle_playback()
	}
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	context = runtime.default_context()

	if button == glfw.MOUSE_BUTTON_LEFT {
		if action == glfw.PRESS {
			left_mouse_pressed = true

			if slider_hovered != nil {
				slider_dragged = slider_hovered
			} else if button_hovered != nil {
				button_hovered.on_click()
			}
		} else {
			left_mouse_pressed = false
			left_mouse_first_press = true
			slider_dragged = nil
		}
	}
}

cursor_pos_callback :: proc "c" (window: glfw.WindowHandle, xpos, ypos: f64) {
	context = runtime.default_context()

	if left_mouse_pressed && slider_dragged != nil && cursor_within_slider_bar() {
		if left_mouse_first_press {
			xpos_prev = xpos
			left_mouse_first_press = false
		}

		x_diff := xpos - xpos_prev
		xpos_prev = xpos

		new_value := slider_dragged.value^ + (f32(x_diff) / bar_width * slider_dragged.max)
		slider_dragged.value^ = min(slider_dragged.max, max(0, new_value))

	} else if !left_mouse_pressed {
		slider_hovered = cursor_within_slider_handle()
		button_hovered = cursor_within_button()
		if slider_hovered != nil || button_hovered != nil {
			glfw.SetCursor(window, glfw.CreateStandardCursor(glfw.POINTING_HAND_CURSOR))
		} else {
			glfw.SetCursor(window, nil)
		}
	}
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

cursor_within_slider_bar :: proc() -> bool {
	x64, y64 := glfw.GetCursorPos(window)
	x := f32(x64)
	y := f32(y64)
	slider := slider_dragged
	return x >= slider.pos.x && x <= slider.pos.x + bar_width
}

cursor_within_button :: proc() -> ^Button {
	x64, y64 := glfw.GetCursorPos(window)
	x := f32(x64)
	y := f32(y64)

	for &button in buttons {
		if x >= button.pos.x &&
		   x <= button.pos.x + button_width &&
		   y >= button.pos.y &&
		   y <= button.pos.y + button_height {
			return &button
		}
	}

	return nil
}
