class_name LandmarkData
extends Resource
## One Ethiopian wonder. Gameplay never reads wonder-specific details anywhere else, so adding a
## wonder means adding a record to the catalog and a scene at `scene_path`.

@export var id: String = ""
@export var name: String = ""
@export var achievement_title: String = ""
@export_multiline var educational_fact: String = ""
## Scenery shown beside the route. Replace the graybox scene with the final model here.
@export_file("*.tscn") var scene_path: String = ""
@export var icon: Texture2D
@export var spawn_weight: float = 1.0
@export var discovered: bool = false

## Optional extension point for a future offline-first AI knowledge provider.
## Signature: func(landmark: LandmarkData) -> String. Unset by default; the game never requires it.
var ai_insight_provider: Callable = Callable()

func get_fact() -> String:
	if ai_insight_provider.is_valid():
		var insight: Variant = ai_insight_provider.call(self)
		if insight is String and not (insight as String).is_empty():
			return insight
	return educational_fact

func load_scene() -> PackedScene:
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return null
	return load(scene_path) as PackedScene

func reset() -> void:
	discovered = false
