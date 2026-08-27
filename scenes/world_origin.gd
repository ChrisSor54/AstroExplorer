@tool
class_name WorldOriginController
extends Node3D


@export var reference_body: PhysicsBody3D:
	set(new_reference_body):
		if reference_body:
			if reference_body is AstroRigidBody and reference_body.has_connections("integrating_forces"):
				reference_body.disconnect("integrating_forces", _integrate_relative_forces)
			reference_body.top_level = false
		reference_body = new_reference_body
		if reference_body:
			if reference_body is AstroRigidBody:
				reference_body.connect("integrating_forces", _integrate_relative_forces)
			reference_body.top_level = true
		if Engine.is_editor_hint():
			center_reference_body_in_editor()

@onready var star_system = get_parent()


@export_tool_button("Center Reference Body", "Environment")
var center_reference_body_button: Callable = center_reference_body_in_editor
	


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
	#float_origin()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	pass
	#if !Engine.is_editor_hint():
		#print(reference_body.global_position, ", ", reference_body.linear_velocity)
	#print(reference_body.global_position, ", ", reference_body.linear_velocity)


func _integrate_relative_forces(emitter: PhysicsBody3D, state: PhysicsDirectBodyState3D):
	var relative_velocity = state.linear_velocity
	#print("integrating relative forces, ", relative_velocity, ", ", relative_position)
	
	state.linear_velocity = Vector3.ZERO # Zero out velocity
	
	# Since velocity is relative, the players position is only offset by collisions,
	# However it's still best to try and keep them near the origin when doing so
	# won't cause issues
	for node in get_children():
		if node == emitter or node is not PhysicsBody3D: continue
		node.linear_velocity -= relative_velocity
	if reference_body is Player:
		# Avoid repositioning while close to any surfaces to avoid any clipping
		var parent_body = reference_body.parent_body
		if reference_body.in_zero_G or parent_body == null:
			float_origin(state)
		else:
			var distance_from_surface = reference_body.global_position.distance_to(parent_body.global_position) - parent_body.radius
			if distance_from_surface >= 5.0: 
				float_origin(state)
			# Reposition if the player somehow gets too far, regardless of collision.
			elif reference_body.global_position.length_squared() >= 1000:
				float_origin(state)
	else:
		float_origin(state)

#func float_origin():
	#if !reference_body: return
	#var new_origin = reference_body.global_position
	#reference_body.global_position = Vector3.ZERO
	#for node in star_system.bodies:
		#node.sync_to_physics = false
	#global_position -= new_origin
	#for node in star_system.bodies:
		#node.sync_to_physics = true

func center_reference_body_in_editor():
	if !Engine.is_editor_hint(): return
	if !reference_body: return
	var spawn_point
	if reference_body is Player and reference_body.spawn_point:
		spawn_point = reference_body.spawn_point
		reference_body.spawn_point = null
	var new_origin = reference_body.global_position
	for node in get_children():
		#if node == reference_body: continue
		if node is AstroBody:
			node.sync_to_physics = false
			node.global_position -= new_origin
			node.sync_to_physics = true
		else:
			node.global_position -= new_origin
	reference_body.global_position = Vector3.ZERO
	if reference_body is Player:
		reference_body.spawn_point = spawn_point
	
	for body in star_system.bodies:
		body.update_orbit()


func float_origin(state: PhysicsDirectBodyState3D):
	if !reference_body: return
	var new_origin = state.transform.origin
	var t = state.transform
	t.origin = Vector3.ZERO
	state.transform = t
	#reference_body.global_position = Vector3.ZERO
	for node in get_children():
		if node == reference_body: continue
		if node is AstroBody:
			node.sync_to_physics = false
			node.global_position -= new_origin
			node.sync_to_physics = true
		else:
			node.global_position -= new_origin
		
	
