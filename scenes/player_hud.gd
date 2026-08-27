extends CanvasLayer
class_name PlayerHUD

@onready var player: Player = get_parent()

@export var control: Control
@export var gravity_label: Label
@export var debug_label: Label



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var up_vector = player.global_transform.basis.y.normalized()
	gravity_label.text = str(player._current_gravity.project(-up_vector).length()/player.mass).pad_decimals(2)
	if player._is_stuck_to_surface:
		debug_label.text = "Stuck to surface"
	else:
		var relative_velocity = Vector3.ZERO
		if player.is_grounded:
			var surface_velocity = player._ground.linear_velocity
			if player._ground is AstroBody:
				surface_velocity += player._ground.get_surface_velocity_from(player.ground_raycast.get_collision_point())
			relative_velocity = player.linear_velocity - surface_velocity
			debug_label.text = "Not stuck" + str(relative_velocity) + ", " + str(relative_velocity.length())
		else:
			debug_label.text = "Not grounded"
			
