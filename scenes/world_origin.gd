@tool
class_name WorldOriginController
extends Node3D


@export var reference_body: PhysicsBody3D:
	set(new_reference_body):
		if reference_body:
			if reference_body is AstroRigidBody and reference_body.is_connected("integrating_forces", _integrate_relative_forces):
				reference_body.disconnect("integrating_forces", _integrate_relative_forces)
			reference_body.top_level = false
		reference_body = new_reference_body
		if reference_body:
			if reference_body is AstroRigidBody:
				reference_body.connect("integrating_forces", _integrate_relative_forces)
			reference_body.top_level = true
		if Engine.is_editor_hint() and is_inside_tree():
			center_reference_body()

@export var virtual_origin: Marker3D

@onready var star_system = get_parent()

### The "virtual" position of the reference body, relative to the original world origin
#var virtual_reference_position: Vector3 = Vector3.ZERO
## The "virtual" velocity of the reference body, relative to the original world origin
var virtual_reference_velocity: Vector3 = Vector3.ZERO

## Holds objects that maintain a fixed position regardless of the floating origin
@export var stationary_nodes: Array[Node3D]

@export_tool_button("Center Reference Body", "Environment")
var center_reference_body_button: Callable = center_reference_body


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if virtual_origin and virtual_origin in stationary_nodes:
		stationary_nodes.erase(virtual_origin)
	
	#float_origin()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if reference_body:
		float_origin(delta)
	if virtual_origin:
		virtual_origin.global_position += virtual_reference_velocity*delta
	for node in stationary_nodes:
		if node != null:
			node.global_position += virtual_reference_velocity*delta
		#if reference_body.global_position != Vector3.ZERO:
			#float_origin()
	#if !Engine.is_editor_hint():
		#print(reference_body.global_position, ", ", reference_body.linear_velocity)
	#print(reference_body.global_position, ", ", reference_body.linear_velocity)

func center_reference_body():
	if !reference_body: return
	print("Centering reference body")
	var spawn_point
	if reference_body is Player and reference_body.spawn_point:
		spawn_point = reference_body.spawn_point
		reference_body.spawn_point = null
	var new_origin = reference_body.global_position
	for node in get_children():
		if node in stationary_nodes: continue
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
	
	for node in stationary_nodes:
		if node != null:
			node.global_position -= new_origin
			if node.has_method("reset_physics_interpolation"):
				node.reset_physics_interpolation()
	
	for body in star_system.orbital_bodies:
		if body.orbit:
			body.update_orbit()
			if body.show_orbit:
				body.redraw_orbital_visualizations()


func _integrate_relative_forces(emitter: PhysicsBody3D, state: PhysicsDirectBodyState3D):
	var relative_velocity = state.linear_velocity
	#print("integrating relative forces, ", relative_velocity, ", ", relative_position)
	
	state.linear_velocity = Vector3.ZERO # Zero out velocity
	
	# Since velocity is relative, the players position is only offset by collisions,
	# however it's still best to try and keep them near the origin during times where
	# repositioning won't cause issues
	for node in get_children():
		if node == emitter or node is not PhysicsBody3D: continue
		if node is RigidBody3D:
			node.apply_force(-relative_velocity*node.mass)
		else:
			node.linear_velocity -= relative_velocity
	
	virtual_reference_velocity -= relative_velocity

func float_origin(delta: float):
	if !reference_body: return
	var new_origin = reference_body.global_position

	for node in get_children():
		if node is AstroBody:
			node.sync_to_physics = false
			node.global_position -= new_origin
			node.sync_to_physics = true
		else:
			node.global_position -= new_origin
		if node.has_method("reset_physics_interpolation"):
			node.reset_physics_interpolation()
