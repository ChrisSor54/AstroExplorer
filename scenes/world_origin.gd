@tool
extends Node3D
class_name WorldOriginController

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

@onready var star_system = get_parent()


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	float_origin()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	pass
	#print(reference_body.global_position, ", ", reference_body.linear_velocity)


func _integrate_relative_forces(emitter: PhysicsBody3D, state: PhysicsDirectBodyState3D):
	var relative_velocity = state.linear_velocity
	var state_transform = state.transform
	var relative_position = state.transform.origin
	#print("integrating relative forces, ", relative_velocity, ", ", relative_position)
	
	state.linear_velocity = Vector3.ZERO # Zero out velocity
	
	emitter.reset_physics_interpolation()
	
	for node in get_children():
		if node == emitter or node is not PhysicsBody3D: continue
		node.linear_velocity -= relative_velocity
	if reference_body is Player and !reference_body.is_grounded:
		float_origin()

func float_origin():
	if !reference_body: return
	var new_origin = reference_body.global_position
	reference_body.global_position = Vector3.ZERO
	for node in star_system.bodies:
		node.sync_to_physics = false
	global_position -= new_origin
	for node in star_system.bodies:
		node.sync_to_physics = true
