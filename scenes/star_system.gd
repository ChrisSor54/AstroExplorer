@tool
extends Node3D
class_name StarSystem

@export var n_body_enabled: bool = false

@export_group("Nodes")
@export var player: Player
@export var world_origin: Node3D
@export var map_camera: Camera3D
@export var map_camera_origin: Marker3D
@export_group("")

var bodies: Array[GravBody]
var rigid_bodies: Array[RigidBody3D]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for node in world_origin.get_children():
		if node is GravBody:
			bodies.append(node)
			node.init()
		elif node is RigidBody3D:
			rigid_bodies.append(node)
	#if player:
		#player.apply_central_force($WorldOrigin/Planet.linear_velocity*player.mass)
		#player.teleport_to_body($WorldOrigin/Planet)
		#float_origin(player.global_position)
		#update_relative_velocities(player.linear_velocity)
		#player.linear_velocity = $WorldOrigin/Planet.linear_velocity


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if player:
			#update_relative_velocities(player.linear_velocity)
			float_origin(player.global_position)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	
	# Floating Origin
	if player:
		update_relative_velocities(player.linear_velocity)
		float_origin(player.global_position)
	apply_gravity(delta)


func apply_gravity(delta: float) -> void:
	for node in world_origin.get_children():
		if node is Player:
			node.parent_body = null
			node._strongest_scaled_gravity = Vector3.ZERO
	
	for body in bodies:
		if !body.enabled: continue
		var grav_vector = Vector3.ZERO
		if n_body_enabled: # N-Body system
			for other_body in bodies:
				if !other_body.enabled: continue
				if body == other_body: continue
				grav_vector += other_body.get_gravity_vector_between(body)
		else: # 2-Body system
			var parent_body = body.parent_body
			if parent_body != null and parent_body.enabled:
				grav_vector = parent_body.get_gravity_vector_between(body)
				while parent_body.parent_body != null and parent_body.parent_body.enabled:
					grav_vector += parent_body.parent_body.get_gravity_vector_between(parent_body)*(body.mass/parent_body.mass)
					parent_body = parent_body.parent_body
		body.apply_force(grav_vector)
			
		for node in rigid_bodies:
			grav_vector = body.get_gravity_vector_from(node.global_position, node.mass)
			if node is Player:
				var scaled_grav = body.get_gravity_vector_from(node.global_position, node.mass, 3)
				if scaled_grav.length_squared() > node._strongest_scaled_gravity.length_squared():
					node.parent_body = body
					node._strongest_scaled_gravity = scaled_grav
					node.parent_gravity = grav_vector
					#print((grav_vector/player.mass).length())
			node.apply_central_force(grav_vector)
			#apply_force_to_player(grav_vector)
			#print(player.global_position)
	

func update_relative_velocities(offset_velocity):
	for node in world_origin.get_children():
		node.linear_velocity -= offset_velocity


func float_origin(offset: Vector3):
	world_origin.global_transform.origin -= offset


func _on_player_map_opened(is_open: bool, target_position: Vector3 = Vector3.ZERO, camera_distance: float = 2000) -> void:
	if is_open:
		map_camera.current = true
		var camera_forward = -map_camera.global_transform.basis.z.normalized()
		#print("Target: ", target_position, ", Origin: ", map_camera_origin.global_position, ", Position: ", map_camera.position)
		#map_camera.global_position = target_position - camera_forward*camera_distance
	else:
		map_camera.current = false
		map_camera.position = Vector3.ZERO
