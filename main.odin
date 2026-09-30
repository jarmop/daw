package daw

import "core:thread"

main :: proc() {
	thread.run(play_sound)
	ui_run()
}
