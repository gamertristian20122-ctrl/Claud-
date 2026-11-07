extends Node
## Passes digit / Backspace / keypad-Enter presses to the Callable in meta "cb" (the title's seed
## keypad: a keyboard can type the number straight in, whichever keypad button has focus).


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var kc: int = event.keycode
		if (kc >= KEY_0 and kc <= KEY_9) or (kc >= KEY_KP_0 and kc <= KEY_KP_9) or kc == KEY_BACKSPACE or kc == KEY_KP_ENTER:
			(get_meta("cb") as Callable).call(event)
			get_viewport().set_input_as_handled()
