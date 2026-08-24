extends CharacterBody3D
class_name PlayerCharacter

const MAX_GROUNDED_MOVE_SPEED: float = 15.0
const JUMP_IMPULSE: float = 100.0
const CAMERA_ANGLE_LIMIT: float = 75
const ZERO_G_THRESHOLD: float = 0.2**2

@export var mass: float = 7.0

@export_group("Movement")
@export var walk_speed: float = 15.0
@export var walk_acceleration: float = 1.0
@export var thrust_strength: float = 10.0
@export var jump_strength: float = 100.0
@export_group("")

@export_group("Nodes")
@export var collision_shape: CollisionShape3D
@export var ground_raycast: RayCast3D
@export var camera_pivot: Node3D
@export var camera: Camera3D
@export_group("")

var is_grounded: bool = false
var in_zero_G: bool = false
var _ground: GravBody
var parent_body: GravBody
var parent_gravity: Vector3 = Vector3.ZERO
var _strongest_gravity: Vector3 = Vector3.ZERO
var radius: float = 1.0

var _current_grav_vector: Vector3 = Vector3.ZERO
var _surface_position: Vector3 = Vector3.ZERO
var _is_stuck_to_surface: bool = false
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
var _is_map_open: bool = false
@export var _ignore_spin: bool = false


signal map_opened(is_open: bool, target_position: Vector3, camera_distance: float)

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
	if Input.is_action_just_pressed("open_map"):
		_is_map_open = !_is_map_open
		print(global_position)
		if !in_zero_G:
			map_opened.emit(_is_map_open, parent_body.global_position)
		else:
			map_opened.emit(_is_map_open, global_position)
		camera.current = !_is_map_open
		print(camera.current)
		
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_mouselook_enabled = true
	if event is InputEventMouseMotion and _mouselook_enabled:
		_mouse_delta = event.relative


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	_ground = ground_raycast.get_collider()
	if (parent_gravity/mass).length() >= ZERO_G_THRESHOLD:
		if in_zero_G:
			_is_reorienting = true
		in_zero_G = false
	else:
		#print("zero G")
		if !in_zero_G:
			_is_reorienting = true
		in_zero_G = true
	
	if ground_raycast.is_colliding():
		var up_vector = (global_position - _ground.global_position).normalized()
		if velocity.dot(up_vector) <= 0.2:
			if !is_grounded:
				var relative_velocity = velocity - _ground.velocity
				var upwards_relative_velocity = relative_velocity.project(up_vector)
				if upwards_relative_velocity.length_squared() <= 0.2**2:
					print(upwards_relative_velocity.length())
					velocity -= upwards_relative_velocity
		#global_position += (ground_raycast.global_position - ground_raycast.get_collision_point())
			is_grounded = true
		else:
			is_grounded = false
	else:
		#if is_grounded:
			#_is_reorienting = true
		is_grounded = false
	_process_look_input(delta)
	_process_orientation(delta)
	_process_movement_input(delta)
	move_and_slide()
	#update_velocity.emit(velocity)
	#velocity = Vector3.ZERO



func _process_movement_input(delta: float) -> void:
	var forward_vector = -global_transform.basis.z.normalized()
	var left_vector = -global_transform.basis.x.normalized()
	var up_vector = global_transform.basis.y.normalized()
	
	var input_vector = Vector3.ZERO
	var rotation_axis = 0.0
	input_vector += Input.get_axis("backward", "forward") * forward_vector
	input_vector += Input.get_axis("right", "left") * left_vector
	if !is_grounded:
		_is_stuck_to_surface = false
		input_vector += Input.get_axis("fly_down", "fly_up") * up_vector
	if in_zero_G:
		_is_stuck_to_surface = false
		rotation_axis = Input.get_axis("rotate_left", "rotate_right")
		#print(input_vector)

	var move_vector = Vector3.ZERO
	if is_grounded:
		var is_jumping = Input.is_action_just_pressed("jump")
		if is_jumping:
			var impulse_vector = jump_strength*up_vector
			#move_vector = up_vector
			#velocity += impulse_vector/mass
			apply_impulse(impulse_vector)
			_is_stuck_to_surface = false
			is_grounded = false
		#if (ground_raycast.global_position - ground_raycast.get_collision_point() )
		#print(_ground.angular_velocity)
		
		if !_ignore_spin:
			rotation += _ground.angular_velocity.project(up_vector)*delta
		#r = r.normalized()*(r.length() + radius)
		var surface_velocity = _ground.velocity + _ground.get_surface_velocity_from(ground_raycast.get_collision_point())
		var relative_velocity = velocity - surface_velocity
		var upwards_relative_velocity = relative_velocity.project(up_vector)
		var surface_relative_velocity = relative_velocity - upwards_relative_velocity
		#relative_velocity -= upwards_relative_velocity
		var forward_speed = relative_velocity.dot(input_vector)
		var target_force = max(walk_speed-forward_speed, 0)
		if input_vector != Vector3.ZERO:
			input_vector = input_vector.normalized()
			move_vector = input_vector*(target_force*walk_acceleration*mass)
			#if relative_velocity.length_squared() <= 0.2:
				#move_vector = Vector3.ZERO
				#velocity = surface_velocity #+ _ground.angular_velocity*radius
				#relative_velocity = velocity - surface_velocity
				#relative_velocity -= relative_velocity.project(up_vector)
			#else:
			_is_stuck_to_surface = false
		else:
			if !is_jumping and relative_velocity.length_squared() <= 0.2:
				if _is_stuck_to_surface:
					global_position = _ground.to_global(_surface_position)
				else:
					_is_stuck_to_surface = true
					var ground_offset = (ground_raycast.global_position - ground_raycast.get_collision_point()).dot(up_vector)
					_surface_position = _ground.to_local(global_position)
				velocity = surface_velocity
			else:
				_is_stuck_to_surface = false
		if !_is_stuck_to_surface and !is_jumping:
			var deceleration_speed = relative_velocity.length()*mass
			move_vector -= (surface_relative_velocity.normalized() - input_vector)*deceleration_speed*mass
		#if relative_velocity.length() != 0: print(relative_velocity.length())
	else:
		if input_vector != Vector3.ZERO:
			input_vector = input_vector.normalized()
			move_vector = input_vector.normalized()*thrust_strength
	if move_vector != Vector3.ZERO:
		apply_force(move_vector, delta)
	if rotation_axis != 0:
		rotation += (forward_vector*rotation_axis*thrust_strength)*delta*delta


func _process_look_input(delta: float) -> void:
	#var left_vector = -global_transform.basis.x.normalized()
	var up_vector = -global_transform.basis.y.normalized()
	if _mouselook_enabled:
		#if !in_zero_G:
		camera_pivot.rotation.x -= _mouse_delta.y*_mouse_sensitivity
		camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-CAMERA_ANGLE_LIMIT), deg_to_rad(CAMERA_ANGLE_LIMIT))
		#else:
			#angular_velocity += left_vector*(_mouse_delta.y*_mouse_sensitivity)/delta
		rotation += up_vector*(_mouse_delta.x*_mouse_sensitivity)
	_mouse_delta = Vector2.ZERO


func _process_orientation(delta: float) -> void:
	var lerp_speed = 6.0
	if is_grounded or !in_zero_G:
		#var target = _ground if is_grounded else parent_body
		var target = parent_body
		#var up_vector = (global_position - target.global_position).normalized()
		var up_vector = -_current_grav_vector.normalized()
		if get_gravity() != Vector3.ZERO:
			print("custom gravity")
			up_vector = -get_gravity().normalized()
		var current_quat = global_transform.basis.get_rotation_quaternion()
		var target_quat = (Quaternion(global_transform.basis.y, up_vector) * current_quat).normalized()
		var angle_offset = current_quat.angle_to(target_quat)
		if angle_offset >= deg_to_rad(1):
			lerp_speed = rad_to_deg(1/angle_offset)/10
		else:
			lerp_speed = 1/delta
		#if is_grounded:
			#lerp_speed = 1/delta
		var new_quat = current_quat.slerp(target_quat, min(lerp_speed*delta, 1.0))
		if _is_reorienting:
			if angle_offset <= 0.02:
				new_quat = target_quat
				_is_reorienting = false
			var camera_right_axis = camera_pivot.global_transform.basis.x
			var old_forward = current_quat * Vector3.FORWARD
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
	global_position = target_body.global_position + body_forward_vector*(target_body.radius + 5)
	velocity = target_body.velocity + target_body.get_surface_velocity_from(global_position)


func apply_impulse(impulse_vector: Vector3):
	velocity += impulse_vector/mass
	
func apply_force(force_vector: Vector3, delta: float):
	velocity += (force_vector/mass)*delta
