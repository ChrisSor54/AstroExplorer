extends Node3D
class_name StarSystem

@export var player: Player

var bodies: Array[GravBody]



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for node in get_children():
		if node is GravBody:
			bodies.append(node)
			node.init()
	if player:
		player.teleport_to_body($Planet)
		apply_force_to_player($Planet.linear_velocity)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if player: player.parent_body = null
	var current_strongest_scaled_gravity = Vector3.ZERO
	for body1 in bodies:
		if body1.process_mode == ProcessMode.PROCESS_MODE_DISABLED: continue
		for body2 in bodies:
			if body2.process_mode == ProcessMode.PROCESS_MODE_DISABLED: continue
			if body1 == body2: continue
			var grav_vector = body2.get_gravity_vector_between(body1)
			body1.apply_force(grav_vector)
		if player:
			var grav_vector = body1.get_gravity_vector_from(player.global_position, player.mass)
			var scaled_grav = body1.get_gravity_vector_from(player.global_position, player.mass, 3)
			if scaled_grav.length_squared() > current_strongest_scaled_gravity.length_squared():
				player.parent_body = body1
				current_strongest_scaled_gravity = scaled_grav
				player.parent_gravity = grav_vector
				#print((grav_vector/player.mass).length())
			apply_force_to_player(grav_vector)
			print(player.linear_velocity)
	#if player and player.global_position.length() >= 5:
		#player.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
		#player.freeze = true
		#global_transform.origin -= player.global_transform.origin
		#player.freeze = false
		
		#if player.is_grounded:
			#float_origin(player._ground.global_position)
		#else:
			#float_origin(player.global_position)

func update_player_forces():
	for node in get_tree().get_nodes_in_group("rebaseable"):
		node.linear_velocity -= player.linear_velocity
	player.linear_velocity = Vector3.ZERO


func apply_force_to_player(force: Vector3):
	var scaled_force = force/player.mass
	for node in get_tree().get_nodes_in_group("rebaseable"):
		node.apply_force(-scaled_force, true)


func _on_player_update_linear_velocity() -> void:
	update_player_forces()
