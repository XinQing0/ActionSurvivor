extends Object

## Registers gameplay actions at runtime.
##
## The bindings live here rather than in `project.godot` because Godot's
## serialized `InputEventKey` layout has changed between 4.x minor releases,
## and a hand-written input map silently breaks on the versions it does not
## match. Registering them in code keeps the action-based API while staying
## version independent. Actions already present in the project are left alone
## so a future remapping UI can override them.

const ACTIONS := {
    "move_left": [KEY_A, KEY_LEFT],
    "move_right": [KEY_D, KEY_RIGHT],
    "move_forward": [KEY_W, KEY_UP],
    "move_back": [KEY_S, KEY_DOWN],
}


static func ensure_actions() -> void:
    for action_name in ACTIONS:
        if InputMap.has_action(action_name):
            continue
        InputMap.add_action(action_name, 0.2)
        for physical_keycode in ACTIONS[action_name]:
            var event := InputEventKey.new()
            event.physical_keycode = physical_keycode
            InputMap.action_add_event(action_name, event)
