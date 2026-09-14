@tool
extends Area3D
class_name GravityField


@export var local_gravity_direction: Vector3 = Vector3.UP:
	set(val):
		if val != Vector3.ZERO:
			val = val.normalized()
		local_gravity_direction = val
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s²") var gravity_strength: float = 9.8:
	set(val):
		gravity_strength = val
		gravity = gravity_strength

#@export var redirect_only: bool = false:
	#set(val):
		#redirect_only = val
		#

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	gravity_direction = (global_transform.basis * local_gravity_direction).normalized()
