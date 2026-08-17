extends Node3D
class_name SolarSystem

@export var player: Player
var bodies: Array[GBody]

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for node in get_children():
		if node is GBody:
			bodies.append(node)
			node.init()
	if player:
		player.init()
	#$Planet.set_orbit($Star, 700)
	#player.teleport_to_body($Planet)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	update_gravity()
	#if player:
		#update_relative_velocities(player.linear_velocity)
		#update_relative_positions(player.global_position)

func update_gravity() -> void:
	for body in bodies:
		if body.process_mode == PROCESS_MODE_DISABLED: continue
		body.update_gravity()
		
	#if player:
		#player.update_gravity(delta)

func update_relative_positions(origin: Vector3):
	for body in bodies:
		body.global_position -= origin
	if player:
		player.global_position -= origin

func update_relative_velocities(reference_velocity: Vector3):
	for body in bodies:
		body.constant_linear_velocity -= reference_velocity
	if player:
		player.linear_velocity -= reference_velocity
