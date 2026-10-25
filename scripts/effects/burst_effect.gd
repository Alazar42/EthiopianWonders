class_name BurstEffect
extends GPUParticles3D
## A one-shot puff of sparks (pickups, shattering rocks). It removes itself when the sparks are gone.

## Colour of the sparks; set before the effect enters the tree.
@export var tint: Color = Color(1.0, 0.8, 0.3)

func _ready() -> void:
	var material := process_material as ParticleProcessMaterial
	if material:
		material.color = tint
	emitting = true
	# The particle server does not report "finished" everywhere (headless), so a timer backs it up.
	get_tree().create_timer(lifetime + 0.6).timeout.connect(queue_free)
