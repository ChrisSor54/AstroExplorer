class_name FakeOmniLight
extends SpotLight3D


@export var target: Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if target:
		look_at_from_position(global_position, target.global_position)
