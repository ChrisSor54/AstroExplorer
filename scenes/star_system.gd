@tool
class_name StarSystem
extends Node3D



const G: float = 1.0

@export var enable_n_body_calculations: bool = false
@export var enable_symmetrical_gravitational_forces: bool = false
@export var rigidbodies_produce_gravity: bool = false

@export_group("Nodes")
@export var player: Player
@export var world_origin: Node3D
@export var map_camera: Camera3D
@export var map_camera_origin: Marker3D
@export_group("")

@export var pause_in_editor: bool = false
var bodies: Array[OrbitalBody]
var rigid_bodies: Array[AstroRigidBody]

@export_tool_button("Validate Orbits", "Trackball")
var validate_orbits_button: Callable = validate_orbits

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if !Engine.is_editor_hint():
		for node in world_origin.get_children():
			if node is AstroBody:
				bodies.append(node)
				node.show_orbit = !enable_n_body_calculations
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
	
	if enable_n_body_calculations:
		var source_bodies = world_nodes if rigidbodies_produce_gravity else bodies
		for body in world_nodes:
			if body is not AstroBody and body is not AstroRigidBody: continue
			if body is AstroBody and !body.enabled: continue
			for other_body in source_bodies:
				if body == other_body: continue
				if other_body is not AstroBody and other_body is not AstroRigidBody: continue
				if other_body is AstroBody and !other_body.enabled: continue
				var gravity_vector = other_body.get_gravity_between_body(body)
				if body is AstroBody:
					body.apply_gravitational_force(gravity_vector)
				if body is AstroRigidBody:
					body.apply_gravitational_force(other_body, gravity_vector)
	else:
		for body in bodies:
			if !body.enabled: continue
			var parent_body = body.parent_body
			if parent_body != null and parent_body.enabled:
				var gravity_vector = parent_body.get_gravity_between_body(body)
				var current_body = parent_body
				while current_body.parent_body != null:
					gravity_vector += current_body.parent_body.get_gravity_between_body(current_body)*(body.mass/current_body.mass)
					current_body = current_body.parent_body
				body.apply_gravitational_force(gravity_vector)
				if enable_symmetrical_gravitational_forces:
					parent_body.apply_gravitational_force(-gravity_vector)
			for node in rigid_bodies:
				var gravity_vector = body.get_gravity_between_body(node)
				node.apply_gravitational_force(body, gravity_vector)
				if rigidbodies_produce_gravity:
					body.apply_gravitational_force(-gravity_vector)




func _on_player_map_opened(is_open: bool, target_position: Vector3 = Vector3.ZERO, camera_distance: float = 2000) -> void:
	if is_open:
		map_camera.current = true
		var camera_forward = -map_camera.global_transform.basis.z.normalized()
		#print("Target: ", target_position, ", Origin: ", map_camera_origin.global_position, ", Position: ", map_camera.position)
		map_camera.global_position = map_camera_origin.global_position - camera_forward*(camera_distance)
	else:
		map_camera.current = false
		map_camera.position = Vector3.ZERO


func _on_player_spawn_point_set() -> void:
	if player.spawn_point == null: return
	if !player.spawn_point.is_inside_tree():
		player.spawn_point = null
		return
	var home_planet: OrbitalBody = player.spawn_point.get_parent()
	player.global_position = player.spawn_point.global_position
	player.global_rotation = player.spawn_point.global_rotation
	player.linear_velocity = home_planet.linear_velocity + home_planet.get_surface_velocity_from(player.spawn_point.global_position)


func validate_orbits():
	for body in bodies:
		if body.parent_body:
			if !body.parent_body.child_bodies:
				body.parent_body.child_bodies = {}
			body.parent_body.child_bodies[body] = true
		if body.child_bodies:
			body.validate_child_bodies()
	if player and player.spawn_point:
		var spawn_point: Marker3D = player.spawn_point
		if !spawn_point.is_inside_tree():
			player.spawn_point = null

	
	
