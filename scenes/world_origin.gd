@tool
class_name WorldOriginController
extends Node3D


@export var reference_body: PhysicsBody3D:
	set(new_reference_body):
		reference_body = new_reference_body
		if Engine.is_editor_hint() and is_inside_tree():
			center_reference_body()

@export var virtual_origin: Marker3D
@export var origin_shifting: bool = true
@export var relative_velocities: bool = false

@onready var star_system = get_parent()

## The "virtual" velocity of the reference body, relative to the original world origin
@export var virtual_reference_velocity: Vector3 = Vector3.ZERO

@export_tool_button("Center Reference Body", "Environment")
var center_reference_body_button: Callable = center_reference_body


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# WorldOriginController is in charge of all forces to maintain relative velocities and positions
	for node in get_children():
		if node is AstroBody or node is AstroRigidBody:
			if !node.is_connected("force_applied", apply_controlled_force):
				node.connect("force_applied", apply_controlled_force)
			if !node.is_connected("impulse_applied", apply_controlled_impulse):
				node.connect("impulse_applied", apply_controlled_impulse)
			#if !node.is_connected("position_shifted", apply_controlled_shift):
				#node.connect("position_shifted", apply_controlled_shift)
			node.top_level = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if Input.is_action_just_pressed("debug"):
		if reference_body:
			if relative_velocities:
				reference_body.global_position += Vector3.UP*20
			else:
				reference_body.apply_force(Vector3.UP*20*reference_body.mass)
				
			
	if origin_shifting and reference_body:
		if reference_body is Player:
			if reference_body.in_zero_G:
				change_velocity_reference_frame(reference_body.linear_velocity)
				float_origin(reference_body.global_position)
			elif reference_body.parent_body:
				change_velocity_reference_frame(reference_body.parent_body.linear_velocity)
	
	if virtual_origin:
		virtual_origin.global_position += virtual_reference_velocity*delta


func on_physics_processed(_emitter: PhysicsBody3D):
	if reference_body is AstroBody and relative_velocities:
		var relative_velocity = reference_body.linear_velocity
		for node in get_children():
			if node is not PhysicsBody3D: continue
			node.apply_impulse(-relative_velocity*node.mass)
		#reference_body.linear_velocity = Vector3.ZERO
		virtual_reference_velocity -= relative_velocity


func apply_controlled_force(target: PhysicsBody3D, force: Vector3, _offset: Vector3 = Vector3.ZERO):
	if target == reference_body and relative_velocities:
		var acceleration = force/target.mass
		for node in get_children():
			if node == reference_body or (node is not AstroBody and node is not RigidBody3D): continue
			node.apply_force(-acceleration*node.mass)
	else:
		target.apply_force(force)


func apply_controlled_impulse(target: PhysicsBody3D, impulse: Vector3, _offset: Vector3 = Vector3.ZERO):
	if target == reference_body and relative_velocities:
		var acceleration = impulse/target.mass
		for node in get_children():
			if node == reference_body or (node is not AstroBody and node is not RigidBody3D): continue
			node.apply_impulse(-acceleration*node.mass)
	else:
		target.apply_impulse(impulse)


func change_velocity_reference_frame(new_reference_velocity: Vector3):
	for node in get_children():
		#if node == reference_body: continue
		if node is AstroBody or node is AstroRigidBody:
			#node.shift_position(-new_origin)
			node.apply_impulse(-new_reference_velocity*node.mass)
	virtual_reference_velocity -= new_reference_velocity


func center_reference_body():
	if !reference_body: return
	print("Centering reference body")
	var new_origin = reference_body.global_position
	var relative_velocity = Vector3.ZERO
	if reference_body is AstroRigidBody:
		relative_velocity = reference_body.linear_velocity
	for node in get_children():
		if node is AstroBody and !Engine.is_editor_hint():
			node._shift_buffer -= new_origin
		else:
			node.global_position -= new_origin
	reference_body.global_position = Vector3.ZERO

	if Engine.is_editor_hint():
		for body in star_system.orbital_bodies:
			if body.orbit:
				body.update_orbit()
				if body.show_orbit:
					body.redraw_orbital_visualizations()
	
	if relative_velocities:
		for node in get_children():
			if node is AstroBody or node is RigidBody3D:
				node.linear_velocity -= relative_velocity
		
		if reference_body is RigidBody3D or reference_body is AstroBody:
			reference_body.linear_velocity = Vector3.ZERO
		
		virtual_reference_velocity -= relative_velocity


func float_origin(new_origin: Vector3):
	for node in get_children():
		if node is AstroBody or node is AstroRigidBody:
			node._shift_buffer -= new_origin
		else:
			node.global_transform.origin -= new_origin
