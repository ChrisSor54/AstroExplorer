extends Node3D
class_name SolarSystem

@onready var bodies = $Bodies
@onready var player = $Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_gravity(delta)

func update_gravity(delta: float) -> void:
	player.parent_body = null
	player.strongest_gravitational_force_squared = 0.0
	for body1 in bodies.get_children():
		if body1 is not GBody or body1.process_mode == PROCESS_MODE_DISABLED: continue
		for body2 in bodies.get_children():
			if body2 is not GBody or body2.process_mode == PROCESS_MODE_DISABLED: continue
			if body1 == body2: continue
			body1.acceleration += body2.get_gravity_vector_from(body1.global_position)*delta
		var player_gravity_vector = body1.get_gravity_vector_from(player.global_position)
		player.acceleration += player_gravity_vector*delta
		var gravity_force_squared = player_gravity_vector.length_squared()
		if player.parent_body == null or gravity_force_squared > player.strongest_gravitational_force_squared:
			player.parent_body = body1
			player.strongest_gravitational_force_squared = gravity_force_squared
