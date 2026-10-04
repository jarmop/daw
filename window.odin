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
x_prev: f32 = 0
slider_dragged: ^Slider
slider_hovered: ^Slider
is_slider_handle_hovered := false
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

key_callback :: proc "c" (window: glfw.WindowHandle, key, scancode_i32, action, mode: i32) {
	context = runtime.default_context()

	if action != glfw.PRESS {
		return
	}

	scancode := int(scancode_i32)

	music_key := 0 // C = 0, C# = 1, B = 11
	octave := 4 // -1 - 9
	midi := (octave + 1) * 12 + music_key

	music_key_scancode_start := 16 // "Q"
	music_key_scancode_end := music_key_scancode_start + 11 // The key after "Å"

	if scancode >= music_key_scancode_start && scancode <= music_key_scancode_end {
		// scale_i := key - glfw.KEY_1
		scale_i := scancode - music_key_scancode_start
		// fmt.println(scancode, key, scale_i)
		midi := (octave + 1) * 12 + scale_i
		frequency = midi_to_freq(midi)
		toggle_playback()
		// fmt.println(midi)
		midi_to_text(midi)
	} else if key in waveform_key_map {
		selected_waveform = waveform_key_map[key]
	} else if key == glfw.KEY_ESCAPE {
		glfw.SetWindowShouldClose(window, true)
	} else if key == glfw.KEY_SPACE {
		toggle_playback()
	} else if key == glfw.KEY_S {
		wav_save()
	}
}

mouse_button_callback :: proc "c" (window: glfw.WindowHandle, button, action, mods: i32) {
	context = runtime.default_context()

	if button == glfw.MOUSE_BUTTON_LEFT {
		if action == glfw.PRESS {
			left_mouse_pressed = true

			if slider_hovered != nil {
				// slider_dragged = slider_hovered
				// slider_dragged.value^ = s.value^ + (f32(x_diff) / bar_width * s.max)
				x64, y64 := glfw.GetCursorPos(window)
				x := f32(x64)
				s := slider_hovered
				s.value^ = (x - s.pos.x) / bar_width * s.max
				s.on_value_changed()

				if is_slider_handle_hovered {
					slider_dragged = slider_hovered
				}
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

	if left_mouse_pressed && slider_dragged != nil {
		s := slider_dragged
		x := f32(xpos)
		if left_mouse_first_press {
			x_prev = x
			left_mouse_first_press = false
		}

		x_diff := x - x_prev
		x_prev = x

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

	} else if !left_mouse_pressed {
		// slider_hovered = cursor_within_slider_handle()
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
		} else {
			is_slider_handle_hovered = false
		}
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
