@tool
class_name StarSystem
extends Node3D



const G: float = 1.0

@export var n_body_enabled: bool = false

@export_group("Nodes")
@export var player: Player
@export var world_origin: Node3D
@export var map_camera: Camera3D
@export var map_camera_origin: Marker3D
@export_group("")

@export var pause_in_editor: bool = false
var bodies: Array[OrbitalBody]
var rigid_bodies: Array[AstroRigidBody]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !Engine.is_editor_hint():
		for node in world_origin.get_children():
			if node is AstroBody:
				bodies.append(node)
			elif node is AstroRigidBody:
				print(node.name)
				rigid_bodies.append(node)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Engine.is_editor_hint() and !pause_in_editor:
		if player:
			#update_relative_velocities(player.linear_velocity)
			if player.spawn_point and player.global_position != player.spawn_point.global_position:
				_on_player_spawn_point_set()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	process_gravity(delta)


func process_gravity(delta: float) -> void:
	var world_nodes = world_origin.get_children()
	for node in world_nodes:
		node._on_new_frame()
	
	for body in bodies:
		if !body.enabled: continue
		var gravity_vector = Vector3.ZERO
		if n_body_enabled: # N-Body system
			for other_body in bodies:
				if !other_body.enabled: continue
				if body == other_body: continue
				gravity_vector += other_body.get_gravity_vector_between(body)
		else: # 2-Body system
			var parent_body = body.parent_body
			if parent_body != null and parent_body.enabled:
				gravity_vector = parent_body.get_gravity_vector_between(body)
				body._linear_acceleration += parent_body._current_gravitational_acceleration
		body.apply_gravitational_force(gravity_vector)
		for node in rigid_bodies:
			gravity_vector = body.get_gravity_vector_from(node.global_position, node.mass)
			node.apply_gravitational_force(body, gravity_vector)




func _on_player_map_opened(is_open: bool, target_position: Vector3 = Vector3.ZERO, camera_distance: float = 2000) -> void:
	if is_open:
		map_camera.current = true
		var camera_forward = -map_camera.global_transform.basis.z.normalized()
		#print("Target: ", target_position, ", Origin: ", map_camera_origin.global_position, ", Position: ", map_camera.position)
		print(camera_forward)
		map_camera.global_position = map_camera_origin.global_position - camera_forward*camera_distance
	else:
		map_camera.current = false
		map_camera.position = Vector3.ZERO


func _on_player_spawn_point_set() -> void:
	if player.spawn_point == null: return
	var home_planet: AstroBody = player.spawn_point.get_parent()
	player.global_position = player.spawn_point.global_position
	player.global_rotation = player.spawn_point.global_rotation
	player.linear_velocity = home_planet.linear_velocity + home_planet.get_surface_velocity_from(player.spawn_point.global_position)

	#for node in world_origin.get_children():
		#print("REPOSITIONING")
		#if node != player:
			#node.global_transform.origin -= 2*new_position
