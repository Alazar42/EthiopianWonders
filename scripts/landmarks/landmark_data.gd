class_name LandmarkData
extends Resource

@export var id: String = ""
@export var name: String = ""
@export var achievement_title: String = ""
@export_multiline var educational_fact: String = ""
@export var color: Color = Color(0.85, 0.65, 0.25)
@export var graybox_type: String = "monument"
@export var spawn_weight: float = 1.0
@export var discovered: bool = false

## Optional AI knowledge provider extension point (callable: func(landmark: LandmarkData) -> String)
var ai_insight_provider: Callable = Callable()

func get_fact() -> String:
	if ai_insight_provider.is_valid():
		var ai_result = ai_insight_provider.call(self)
		if ai_result is String and not ai_result.is_empty():
			return ai_result
	return educational_fact

func reset() -> void:
	discovered = false
