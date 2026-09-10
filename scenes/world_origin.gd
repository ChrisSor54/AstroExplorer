@tool
class_name WorldOriginController
extends Node3D


@export var reference_body: PhysicsBody3D:
	set(new_reference_body):
		if reference_body:
			if reference_body.is_connected("physics_processed", on_physics_processed):
				reference_body.disconnect("physics_processed", on_physics_processed)
			if reference_body is AstroRigidBody:
				reference_body.custom_integrator = false
				var rid = reference_body.get_rid()
				PhysicsServer3D.body_set_force_integration_callback(rid, Callable())
				#if reference_body.is_connected("integrated_forces", on_integrate_forces):
					#reference_body.disconnect("integrated_forces", on_integrate_forces)
			reference_body.top_level = false
		reference_body = new_reference_body
		if reference_body:
			reference_body.connect("physics_processed", on_physics_processed)
			if reference_body is AstroRigidBody:
				reference_body.custom_integrator = true
				var rid = reference_body.get_rid()
				PhysicsServer3D.body_set_force_integration_callback(rid, integrate_force)
				#reference_body.connect("integrated_forces", on_integrate_forces)
			reference_body.top_level = true
		if Engine.is_editor_hint() and is_inside_tree():
			center_reference_body()

@export var virtual_origin: Marker3D
@export var origin_shifting: bool = true

@onready var star_system = get_parent()

## The "virtual" velocity of the reference body, relative to the original world origin
@export var virtual_reference_velocity: Vector3 = Vector3.ZERO

## Holds objects that maintain a fixed position regardless of the floating origin
@export var stationary_nodes: Array[Node3D]

@export_tool_button("Center Reference Body", "Environment")
var center_reference_body_button: Callable = center_reference_body


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if virtual_origin and virtual_origin in stationary_nodes:
		stationary_nodes.erase(virtual_origin)
	# WorldOriginController is in charge of all forces to maintain relative velocities and positions
	for node in get_children():
		if node is AstroBody or node is AstroRigidBody:
			if !node.is_connected("force_applied", apply_controlled_force):
				node.connect("force_applied", apply_controlled_force)
			if !node.is_connected("impulse_applied", apply_controlled_impulse):
				node.connect("impulse_applied", apply_controlled_impulse)
			if !node.is_connected("position_shifted", apply_controlled_shift):
				node.connect("position_shifted", apply_controlled_shift)
			node.top_level = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if Input.is_action_just_pressed("debug"):
		if reference_body:
			reference_body.global_position += Vector3.UP*20
	if origin_shifting:
		float_origin()
	
	if virtual_origin:
		virtual_origin.global_position += virtual_reference_velocity*delta
	#for node in stationary_nodes:
		#if node != null:
			#node.global_position += reference_body.linear_velocity*delta



func integrate_force(state: PhysicsDirectBodyState3D):
	var relative_velocity = state.linear_velocity
	#state.linear_velocity = Vector3.ZERO # Zero out velocity
	state.linear_velocity = Vector3.ZERO
	
	# Since velocity is relative, the players position is only offset by collisions,
	# however it's still best to try and keep them near the origin during times where
	# repositioning won't cause issues
	for node in get_children():
		if node == reference_body or node is not PhysicsBody3D: continue
		#if node is not PhysicsBody3D: continue
		if node is RigidBody3D:
			node.apply_force(-relative_velocity*node.mass)
		else:
			node.linear_velocity -= relative_velocity
	virtual_reference_velocity -= relative_velocity
	
	# Apply angular velocity
	state.angular_velocity *= max(1.0 - reference_body.angular_damp * state.step, 0.0)
	var angle = state.angular_velocity.length()
	if angle > 0.0001:
		var axis = state.angular_velocity / angle
		state.transform.basis = state.transform.basis.rotated(axis, angle * state.step)
	#if origin_shifting:
		#float_origin(state)
	#float_origin(state)

func on_physics_processed(_emitter: PhysicsBody3D):
	if reference_body is AstroBody:
		var relative_velocity = reference_body.linear_velocity
		for node in get_children():
			if node is not PhysicsBody3D: continue
			node.linear_velocity -= relative_velocity
		virtual_reference_velocity -= relative_velocity


func apply_controlled_force(target: PhysicsBody3D, force: Vector3, _offset: Vector3 = Vector3.ZERO):
	if target == reference_body:
		var acceleration = force/target.mass
		for node in get_children():
			if node == reference_body or (node is not AstroBody and node is not RigidBody3D): continue
			node.apply_force(-acceleration*node.mass)
	else:
		target.apply_force(force)


func apply_controlled_impulse(target: PhysicsBody3D, impulse: Vector3, _offset: Vector3 = Vector3.ZERO):
	if target == reference_body:
		var acceleration = impulse/target.mass
		for node in get_children():
			if node == reference_body or (node is not AstroBody and node is not RigidBody3D): continue
			node.apply_impulse(-acceleration*node.mass)
	else:
		target.apply_impulse(impulse)


func apply_controlled_shift(target: PhysicsBody3D, position_delta: Vector3):
	if target == reference_body:
		#var position_delta = new_position - reference_body.global_position # This should probably always be Vector3.ZERO
		for node in get_children():
			if node == reference_body or (node is not AstroBody and node is not RigidBody3D): continue
			if node is AstroBody:
				node.shift_position(-position_delta)
			else:
				node.global_position -= position_delta
	else:
		if target is AstroBody:
			target.shift_position(position_delta)
		else:
			target.global_position += position_delta


func center_reference_body():
	if !reference_body: return
	print("Centering reference body")
	var new_origin = reference_body.global_position
	var relative_velocity = Vector3.ZERO
	if reference_body is AstroRigidBody:
		relative_velocity = reference_body.linear_velocity
	for node in get_children():
		if node in stationary_nodes: continue
		#if node == reference_body: continue
		if node is AstroBody and !Engine.is_editor_hint():
			node.shift_position(-new_origin)
		else:
			node.global_position -= new_origin
		if node is AstroBody or node is AstroRigidBody:
			node.linear_velocity -= relative_velocity
	reference_body.global_position = Vector3.ZERO
	if reference_body is AstroRigidBody or reference_body is AstroBody:
		reference_body.linear_velocity = Vector3.ZERO
	
	virtual_reference_velocity -= relative_velocity
	
	#for node in stationary_nodes:
		#if node != null:
			#node.global_position -= new_origin
			#if node.has_method("reset_physics_interpolation"):
				#node.reset_physics_interpolation()
	
	for body in star_system.orbital_bodies:
		if body.orbit:
			body.update_orbit()
			if body.show_orbit:
				body.redraw_orbital_visualizations()


func float_origin():
	if !reference_body: return
	var new_origin = reference_body.global_position

	for node in get_children():
		#if node == reference_body: continue
		if node is AstroBody:
			node.shift_position(-new_origin)
		else:
			node.global_transform.origin -= new_origin
	
	
	#for node in stationary_nodes:
		#if node != null:
			#node.global_position -= new_origin
			#if node.has_method("reset_physics_interpolation"):
				#node.reset_physics_interpolation()
		#if node.has_method("reset_physics_interpolation"):
			#node.reset_physics_interpolation()
	#reference_body.global_position = Vector3.ZERO
	#if reference_body.has_method("reset_physics_interpolation"):
		#reference_body.reset_physics_interpolation()
