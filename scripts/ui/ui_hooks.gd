extends Node
## Autoload. Gives every button in the game the hover and press spring from UiMotion, so no screen
## has to remember to wire it up. (Button sounds are handled by GameAudio.)

func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		UiMotion.hook_button(node as BaseButton)
