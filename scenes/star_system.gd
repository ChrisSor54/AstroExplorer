@tool
class_name StarSystem
extends Node3D



const G: float = 1.0

@export_group("Nodes")
@export var player: Player
@export var world_origin_controller: Node3D
@export var map_camera: Camera3D
@export var map_camera_origin: Marker3D
@export_group("")

@export var enable_n_body_calculations: bool = false
@export var child_bodies_produce_gravity_on_parent: bool = false
@export var rigidbodies_produce_gravity: bool = false

var all_bodies: Array[PhysicsBody3D]
var orbital_bodies: Array[OrbitalBody]
var rigidbodies: Array[AstroRigidBody]


@export_range(1.0, 64.0, 1.0, "Time Scale")
var time_scale: float = 1.0

@export_tool_button("Validate Orbits", "Trackball")
var validate_orbits_button: Callable = validate_orbits

@export_tool_button("Print Tree")
var print_tree_button: Callable = print_tree_pretty


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for node in world_origin_controller.get_children():
		if (node is AstroBody and node.enabled) or node is AstroRigidBody:
			all_bodies.append(node)
	
	# Sort to put highest mass bodies first
	var is_heavier := func (obj1: PhysicsBody3D, obj2: PhysicsBody3D) -> bool: return obj1.mass > obj2.mass
	all_bodies.sort_custom(is_heavier)
	for body in all_bodies:
		if body is AstroBody:
			orbital_bodies.append(body)
			if !Engine.is_editor_hint() and enable_n_body_calculations:
				body.show_orbit = false
		elif body is AstroRigidBody:
			rigidbodies.append(body)
	validate_orbits()
	world_origin_controller.center_reference_body()
	print_debug("Star System ready")
	
	if !Engine.is_editor_hint() and enable_n_body_calculations:
		for body in orbital_bodies:
			body.show_orbit = false
		Engine.time_scale = time_scale
		#Engine.physics_ticks_per_second *= sqrt(time_scale)
		print("Ready: ", player.global_position)




# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		if player and player.spawn_point:
			#update_relative_velocities(player.linear_velocity)
			var home_planet: OrbitalBody = player.spawn_point.get_parent()
			if player.spawn_point.global_position == home_planet.global_position:
				return
			var up_vector = (player.global_position - home_planet.global_position).normalized()
			var current_quat = player.global_transform.basis.get_rotation_quaternion()
			var target_quat = (Quaternion(player.global_transform.basis.y, up_vector) * current_quat).normalized()
			var up_basis = Basis(target_quat)
			var new_transform = Transform3D(up_basis, player.spawn_point.global_transform.origin)
			player.global_transform = new_transform
			player.linear_velocity = home_planet.linear_velocity + home_planet.get_surface_velocity_from(player.spawn_point.global_position)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	process_gravity(delta)


func process_gravity(delta: float) -> void:
	for body in all_bodies:
		body._on_new_frame()
	
	if enable_n_body_calculations:
		for body in all_bodies:
			apply_n_body_gravity(body)
	else:
		for body in orbital_bodies:
			apply_2_body_gravity(body)
		for rigidbody in rigidbodies:
			apply_n_body_gravity(rigidbody)


func apply_n_body_gravity(target: PhysicsBody3D) -> void:
	if target is not AstroBody and target is not AstroRigidBody: return
	var source_bodies = all_bodies if rigidbodies_produce_gravity else orbital_bodies
	for source_body in source_bodies:
		if source_body == target: continue
		if source_body is AstroBody and !source_body.enabled: continue
		var gravity_vector = target.get_gravity_from_body(source_body)
		target.apply_gravitational_force(source_body, gravity_vector)


func apply_2_body_gravity(target: PhysicsBody3D) -> void:
	if target is not AstroBody and target is not AstroRigidBody: return
	#var source_bodies = all_bodies if rigidbodies_produce_gravity else orbital_bodies
	var gravity_vector = Vector3.ZERO
	var current_body = target
	while current_body.parent_body != null: # Applies the acceleration from gravity of all parents up the heirarchy
		gravity_vector += current_body.get_gravity_from_body(current_body.parent_body)*(target.mass/current_body.mass)
		current_body = current_body.parent_body
	if gravity_vector != Vector3.ZERO:
		target.apply_gravitational_force(target.parent_body, gravity_vector)
		if child_bodies_produce_gravity_on_parent:
			if target is AstroBody or (target is AstroRigidBody and rigidbodies_produce_gravity):
				target.parent_body.apply_gravitational_force(target, -gravity_vector)


func _on_player_map_opened(is_open: bool, target_position: Vector3 = Vector3.ZERO, camera_distance: float = 8000) -> void:
	if is_open:
		var largest_apoapsis = 0.0
		for body in orbital_bodies:
			if body.orbit:
				largest_apoapsis = max(largest_apoapsis, body.orbit.apoapsis)
		map_camera.current = true
		var camera_forward = -map_camera.global_transform.basis.z.normalized()
		#print("Target: ", target_position, ", Origin: ", map_camera_origin.global_position, ", Position: ", map_camera.position)
		map_camera.global_position = map_camera_origin.global_position - camera_forward*(largest_apoapsis*(1.15))
		#map_camera.global_position = map_camera_origin.global_position - camera_forward*(camera_distance)
	else:
		map_camera.current = false
		map_camera.position = Vector3.ZERO



func validate_orbits():
	for body in orbital_bodies:
		if body.parent_body:
			if !body.parent_body.child_bodies:
				body.parent_body.child_bodies = {}
			body.parent_body.child_bodies[body] = true
		if body.child_bodies:
			body.validate_child_bodies()
	
	for body in orbital_bodies:
		if Engine.is_editor_hint(): print_debug(body.name, ": Validating")
		body.update_orbit()
	
	if player and player.spawn_point:
		var spawn_point: Marker3D = player.spawn_point
		if !spawn_point.is_inside_tree():
			player.spawn_point = null


func set_all_stable_orbits():
	pass
			
