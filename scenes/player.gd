extends RigidBody3D
class_name Player

const MAX_GROUNDED_MOVE_SPEED: float = 15.0
const JUMP_IMPULSE: float = 50.0
const CAMERA_ANGLE_LIMIT: float = 80
const ZERO_G_THRESHOLD: float = 2.0

@export_group("Movement")
@export var walk_speed: float = 15.0
@export var walk_acceleration: float = 1.0
@export var thrust_speed: float = 10.0
@export_group("")

@export_group("Nodes")
@export var collision_shape: CollisionShape3D
@export var ground_raycast: RayCast3D
@export var camera_pivot: Node3D
@export var camera: Camera3D
@export var grounded_counter_spin: Marker3D
@export_group("")

var is_grounded: bool = false
var in_zero_G: bool = false
var _ground: GravBody
var parent_body: GravBody
var parent_gravity: Vector3 = Vector3.ZERO
var radius: float = 1.0

#var _surface_position: Vector3 = Vector3.ZERO
#var _is_stuck_to_surface: bool = false
var _is_reorienting: bool = false
var _mouselook_enabled = true:
	set(val):
		_mouselook_enabled = val
		if _mouselook_enabled:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		
var _thirdperson_enabled: bool = false
var _mouse_sensitivity: float = 0.003
var _mouse_delta: Vector2 = Vector2.ZERO


signal update_linear_velocity

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_mouselook_enabled = true
	radius = collision_shape.shape.height/2
	pass # Replace with function body.

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_mouselook"):
		_mouselook_enabled = false
	if Input.is_action_just_pressed("toggle_firstperson"):
		_thirdperson_enabled = !_thirdperson_enabled
		if _thirdperson_enabled:
			camera.position = Vector3(0,0,2.5)
		else:
			camera.position = Vector3.ZERO
		
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_mouselook_enabled = true
	if event is InputEventMouseMotion and _mouselook_enabled:
		_mouse_delta = event.relative


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	_ground = ground_raycast.get_collider()
	if (parent_gravity/mass).length() >= ZERO_G_THRESHOLD and global_position.distance_to(parent_body.global_position) <= 2*parent_body.radius:
		if in_zero_G:
			_is_reorienting = true
		in_zero_G = false
	else:
		#print("zero G")
		if !in_zero_G:
			_is_reorienting = true
		in_zero_G = true
		
	if ground_raycast.is_colliding():
		#if !is_grounded:
			#_is_reorienting = true
		is_grounded = true
	else:
		#if is_grounded:
			#_is_reorienting = true
		is_grounded = false
	
	_process_look_input(delta)
	_process_orientation(delta)
	_process_movement_input(delta)
	update_linear_velocity.emit()



func _process_movement_input(delta: float) -> void:
	var forward_vector = -global_transform.basis.z.normalized()
	var left_vector = -global_transform.basis.x.normalized()
	var up_vector = global_transform.basis.y.normalized()
	#angular_damp = 10.0
	
	var input_vector = Vector3.ZERO
	input_vector += Input.get_axis("backward", "forward") * forward_vector
	input_vector += Input.get_axis("right", "left") * left_vector
	if !is_grounded:
		input_vector += Input.get_axis("fly_down", "fly_up") * up_vector
		print(input_vector)

	var move_vector = Vector3.ZERO
	if is_grounded:
		angular_velocity += _ground.angular_velocity.project(up_vector)
		#r = r.normalized()*(r.length() + radius)
		var surface_velocity = _ground.linear_velocity + _ground.get_surface_velocity_from(grounded_counter_spin.global_position)
		var relative_velocity = linear_velocity - surface_velocity
		var forward_speed = relative_velocity.dot(input_vector)
		var target_force = max(walk_speed-forward_speed, 0)
		if input_vector != Vector3.ZERO:
			input_vector = input_vector.normalized()
			move_vector = input_vector*(target_force*walk_acceleration*mass)
		else:
			if relative_velocity.length_squared() <= 0.2:
				move_vector = Vector3.ZERO
				linear_velocity = surface_velocity #+ _ground.angular_velocity*radius
				relative_velocity = linear_velocity - surface_velocity
			else:
				var deceleration_speed = max(walk_acceleration, -relative_velocity.length())
				#move_vector = (-relative_velocity)
				move_vector = (-relative_velocity).normalized()*deceleration_speed*mass
		if Input.is_action_just_pressed("jump"):
			var impulse_vector = JUMP_IMPULSE*up_vector
			linear_velocity += impulse_vector/mass
		if relative_velocity.length() != 0: print(relative_velocity.length())
	else:
		if input_vector != Vector3.ZERO:
			input_vector = input_vector.normalized()
			move_vector = input_vector.normalized()*thrust_speed
	if move_vector != Vector3.ZERO:
		apply_central_force(move_vector)


func _process_look_input(delta: float) -> void:
	#var left_vector = -global_transform.basis.x.normalized()
	var up_vector = -global_transform.basis.y.normalized()
	angular_velocity = Vector3.ZERO
	if _mouselook_enabled:
		#if !in_zero_G:
		camera_pivot.rotation.x -= _mouse_delta.y*_mouse_sensitivity
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-CAMERA_ANGLE_LIMIT), deg_to_rad(CAMERA_ANGLE_LIMIT))
		#else:
			#angular_velocity += left_vector*(_mouse_delta.y*_mouse_sensitivity)/delta
		angular_velocity += up_vector*(_mouse_delta.x*_mouse_sensitivity)/delta
	_mouse_delta = Vector2.ZERO


func _process_orientation(delta: float) -> void:
	var lerp_speed = 6.0
	if is_grounded or !in_zero_G:
		var target = _ground if is_grounded else parent_body
		var up_vector = (global_position - target.global_position).normalized()
		var old_quat = global_transform.basis.get_rotation_quaternion()
		var target_quat = (Quaternion(global_transform.basis.y, up_vector) * old_quat).normalized()
		var new_quat = target_quat
		if _is_reorienting:
			new_quat = old_quat.slerp(target_quat, min(lerp_speed*delta, 1.0))
			if new_quat.angle_to(target_quat) <= 0.02:
				new_quat = target_quat
				_is_reorienting = false
			var camera_right_axis = camera_pivot.global_transform.basis.x
			var old_forward = old_quat * Vector3.FORWARD
			var new_forward = new_quat * Vector3.FORWARD
			var pitch_delta = old_forward.signed_angle_to(new_forward, camera_right_axis)
			camera_pivot.rotation.x -= pitch_delta
		global_transform.basis = Basis(new_quat)
	else:
		#_is_reorienting = false
		#if _is_reorienting:
		var left_vector = global_transform.basis.x.normalized()
		var old_pitch = camera_pivot.rotation.x
		var new_pitch = lerp_angle(old_pitch, 0.0, min(lerp_speed*delta, 1.0))
		if abs(new_pitch) <= 0.001:
			#new_pitch = 0.0
			_is_reorienting = false
		var pitch_to_transfer = old_pitch - new_pitch
		camera_pivot.rotation.x = new_pitch
		var rotation_delta = Quaternion(left_vector, pitch_to_transfer)
		global_transform.basis = Basis(rotation_delta * global_transform.basis.get_rotation_quaternion())

func teleport_to_body(target_body: GravBody) -> void:
	var body_forward_vector = -target_body.transform.basis.z.normalized()
	global_position = target_body.global_position + body_forward_vector*(target_body.radius)
	#linear_velocity = target_body.linear_velocity + target_body.get_surface_velocity_from(global_position)
