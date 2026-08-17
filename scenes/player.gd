extends RigidBody3D
class_name Player

# Nodes
@export_category("Nodes")
@export var grounded_raycast: RayCast3D

@export_group("Camera")
@export var camera: Camera3D
@export var camera_pivot: Node3D

# GBody properties
var acceleration: Vector3 = Vector3.ZERO


const CAMERA_ANGLE_LIMIT: float = 80
const JUMP_IMPULSE: float = 100

@export_category("Properties")
@export var thrust_speed: float = 200.0
@export var move_speed: float = 500.0
@export var rotate_speed: float = 5.0
var is_grounded: bool = true
var in_zero_G: bool = true

var parent_body: GBody
var strongest_gravitational_force_squared: float = 0

var _thirdperson_enabled: bool = true
var _mouse_sensitivity := 0.003
var _mouse_delta = Vector2.ZERO
var _mouselook_enabled = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_mouselook"):
		_mouselook_enabled = false
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.is_action_just_pressed("toggle_firstperson"):
		_thirdperson_enabled = !_thirdperson_enabled
		if _thirdperson_enabled:
			camera.position = Vector3(0,0,2.5)
		else:
			camera.position = Vector3.ZERO
		
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_mouselook_enabled = true
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseMotion and _mouselook_enabled:
		_mouse_delta = event.relative

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	print(strongest_gravitational_force_squared)


func _physics_process(delta: float) -> void:
	is_grounded = false
	in_zero_G = true
	angular_velocity = Vector3.ZERO
	
	if grounded_raycast.is_colliding():
		is_grounded = true
	if strongest_gravitational_force_squared >= 1.0:
		in_zero_G = false
		
	
	_process_auto_orientation()
	_process_movement_inputs(delta)
	_process_camera_inputs(delta)
	
	#var rotation_axis = Input.get_axis("rotate_right", "rotate_left")
	#if input_dir != Vector2.ZERO:
		#var move_vector = Vector3(input_dir.x, 0, input_dir.y).normalized()*move_speed*delta
		#linear_velocity = move_vector.rotated(Vector3.UP, rotation.y)
	#else:
		#linear_velocity.x = 0
		#linear_velocity.z = 0
	update_velocity()
	#move_and_slide()
	
func _process_auto_orientation() -> void:
	var orientation_target = null
	if is_grounded:
		var colliding_body = grounded_raycast.get_collider()
		if colliding_body is GBody:
			orientation_target = colliding_body
	elif !in_zero_G:
		orientation_target = parent_body
	if orientation_target != null:
		var up_vector = (global_position - parent_body.global_position).normalized()
		var oriented_rotation = Quaternion(global_transform.basis.y, up_vector) * global_transform.basis.get_rotation_quaternion()
		global_rotation = oriented_rotation.normalized().get_euler()


func _process_movement_inputs(delta: float) -> void:
	var forward_vector = -global_transform.basis.z
	var left_vector = -global_transform.basis.x
	var up_vector = global_transform.basis.y
	angular_damp = 10.0
	
	var input_vector = Vector3.ZERO
	
	input_vector += Input.get_axis("backward", "forward") * forward_vector
	input_vector += Input.get_axis("right", "left") * left_vector
	if is_grounded:
		if Input.is_action_just_pressed("jump"):
			apply_central_impulse(JUMP_IMPULSE * up_vector)
	else:
		input_vector += Input.get_axis("fly_down", "fly_up") * up_vector
	
	
	if is_grounded:
		var colliding_body = grounded_raycast.get_collider()
		if colliding_body is GBody:
			angular_velocity = colliding_body.constant_angular_velocity.project(up_vector)
			angular_damp = 0
	
	if input_vector != Vector3.ZERO:
		var move_vector = Vector3.ZERO
		if is_grounded:
			move_vector = input_vector.normalized()*move_speed
		else:
			move_vector = input_vector.normalized()*thrust_speed
		apply_central_force(move_vector*delta)


func _process_camera_inputs(delta: float) -> void:
	var left_vector = -global_transform.basis.x
	if _mouselook_enabled:
		if !in_zero_G:
			camera_pivot.rotation.x -= _mouse_delta.y*_mouse_sensitivity
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-CAMERA_ANGLE_LIMIT), deg_to_rad(CAMERA_ANGLE_LIMIT))
		else:
			camera_pivot.rotation.x = 0
			angular_velocity = (_mouse_delta.y * _mouse_sensitivity * left_vector)/delta
		if (_mouse_delta.x != 0):
			angular_velocity.y = (-_mouse_delta.x*_mouse_sensitivity)/delta
	_mouse_delta = Vector2.ZERO


func update_velocity():
	linear_velocity += acceleration
	acceleration = Vector3.ZERO
