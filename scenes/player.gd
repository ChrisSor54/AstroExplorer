class_name Player
extends AstroRigidBody


const MAX_GROUNDED_MOVE_SPEED: float = 15.0
const JUMP_IMPULSE: float = 100.0
const CAMERA_ANGLE_LIMIT: float = 75
const ZERO_G_THRESHOLD: float = 0.1**2

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

@export var spawn_point: Marker3D:
	set(val):
		spawn_point = val
		if spawn_point and is_inside_tree() and spawn_point.is_inside_tree() and spawn_point.get_parent().is_inside_tree():
			var home_planet: OrbitalBody = spawn_point.get_parent()
			if spawn_point.global_position == home_planet.global_position: return
			var up_vector = (global_position - home_planet.global_position).normalized()
			var current_quat = global_transform.basis.get_rotation_quaternion()
			var target_quat = (Quaternion(global_transform.basis.y, up_vector) * current_quat).normalized()
			var up_basis = Basis(target_quat)
			var new_transform = Transform3D(up_basis, spawn_point.global_transform.origin)
			global_transform = new_transform
			linear_velocity = home_planet.linear_velocity + home_planet.get_surface_velocity_from(spawn_point.global_position)


var is_grounded: bool = false
var in_zero_G: bool = false
var is_ragdoll: bool = false

var _ground: PhysicsBody3D = null
var _is_stuck_to_surface: bool = false
var _surface_position: Vector3 = Vector3.ZERO
#var _is_jumping: bool = false
var _lock_relative_camera_rotation: bool = false
var _is_reorienting: bool = false
var _mouselook_enabled = false:
	set(val):
		if !get_window(): return
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
#var _rotation_buffer: Vector3 = Vector3.ZERO


signal map_opened(is_open: bool, target_position: Vector3, camera_distance: float)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_mouselook_enabled = false


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("toggle_mouselook"):
		_mouselook_enabled = false
	if Input.is_action_just_pressed("toggle_firstperson"):
		_thirdperson_enabled = !_thirdperson_enabled
		if _thirdperson_enabled:
			camera.position = Vector3(0,0,2.5)
			camera.set_cull_mask_value(2, true)
		else:
			camera.position = Vector3.ZERO
			camera.set_cull_mask_value(2, false)
	if Input.is_action_just_pressed("open_map"):
		_is_map_open = !_is_map_open
		#print(global_position)
		map_opened.emit(_is_map_open)
		camera.current = !_is_map_open
		#print(camera.current)
		
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		_mouselook_enabled = true
	if event is InputEventMouseMotion and _mouselook_enabled:
		_mouse_delta = event.relative


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	_ground = ground_raycast.get_collider()
	if (_current_strongest_tidal_force/mass).length() >= ZERO_G_THRESHOLD:
		if in_zero_G:
			_is_reorienting = true
		in_zero_G = false
	else:
		#print("zero G")
		if !in_zero_G:
			_is_reorienting = true
		in_zero_G = true
	if !is_ragdoll and ground_raycast.is_colliding() and _ground != null:
		var up_vector = (global_position-_ground.global_position).normalized()
		var relative_velocity = linear_velocity - _ground.linear_velocity
		if relative_velocity.dot(up_vector) <= 0.2:
		##global_position += (ground_raycast.global_position - ground_raycast.get_collision_point())
			is_grounded = true
		else:
			is_grounded = false
		#is_grounded = true
	else:
		#if is_grounded:
			#_is_reorienting = true
		is_grounded = false
	if Input.is_action_just_pressed("ragdoll"):
		is_ragdoll = !is_ragdoll
	
	_process_look_input(delta)
	if !is_ragdoll:
		lock_rotation = true
		angular_velocity = Vector3.ZERO
		#var up_vector = global_transform.basis.y.normalized()
		#var forward_vector = -global_transform.basis.z.normalized()
		#var left_vector = -global_transform.basis.x.normalized()
		#angular_velocity = angular_velocity.project(forward_vector) + angular_velocity.project(left_vector)
		#angular_velocity = Vector3.ZERO
		#lock_rotation = true
		_process_orientation(delta)
		_process_movement(delta)
	else:
		lock_rotation = false
		_is_stuck_to_surface = false
	super._physics_process(delta)


#func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	#if _is_stuck_to_surface and _ground:
		#state.transform.origin = _ground.to_global(_surface_position)

#func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	##print(Global.physics_count, " | Integrate Forces => Pos: ", Global.pretty_vector(state.transform.origin), ", Vel: ", Global.pretty_vector(state.linear_velocity))
	#var delta = state.step
	#_ground = ground_raycast.get_collider()
	#if (_current_strongest_tidal_force/mass).length() >= ZERO_G_THRESHOLD:
		#if in_zero_G:
			#_is_reorienting = true
		#in_zero_G = false
	#else:
		##print("zero G")
		#if !in_zero_G:
			#_is_reorienting = true
		#in_zero_G = true
	#if !is_ragdoll and ground_raycast.is_colliding() and _ground != null:
		#var up_vector = (state.transform.origin-_ground.global_position).normalized()
		#var relative_velocity = state.linear_velocity - _ground.linear_velocity
		#if relative_velocity.dot(up_vector) <= 0.2:
		###global_position += (ground_raycast.global_position - ground_raycast.get_collision_point())
			#is_grounded = true
		#else:
			#is_grounded = false
		##is_grounded = true
	#else:
		##if is_grounded:
			##_is_reorienting = true
		#is_grounded = false
	#if Input.is_action_just_pressed("ragdoll"):
		#is_ragdoll = !is_ragdoll
	#
	##print("Look =>         Pos: ", get_vector_string(state.transform.origin), ", Vel: ", get_vector_string(state.linear_velocity))
	##_process_look_input(delta)
	#if !is_ragdoll:
		#lock_rotation = true
		#angular_velocity = Vector3.ZERO
		##print("Orient =>       Pos: ", get_vector_string(state.transform.origin), ", Vel: ", get_vector_string(state.linear_velocity))
		##_process_state_orientation(state, delta)
		#
		##print("Move =>         Pos: ", get_vector_string(state.transform.origin), ", Vel: ", get_vector_string(state.linear_velocity))
		#_process_state_movement(state, delta)
	#else:
		#lock_rotation = false
		#_is_stuck_to_surface = false
	##print("Integrate =>    Pos: ", get_vector_string(state.transform.origin), ", Vel: ", get_vector_string(state.linear_velocity))
	#if _rotation_buffer != Vector3.ZERO:
		#var rotation_angle = _rotation_buffer.length()
		#var rotation_axis = _rotation_buffer / rotation_angle
		#state.transform.basis = state.transform.basis.rotated(rotation_axis, rotation_angle)
		#_rotation_buffer = Vector3.ZERO
	#if custom_integrator:
		#state.transform.origin += state.linear_velocity * delta
	##print(Global.physics_count, " | End Integrate Forces => Pos: ", Global.pretty_vector(state.transform.origin), ", Vel: ", Global.pretty_vector(state.linear_velocity))
	

func _process_movement(delta: float) -> void:
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
		#if parent_body:
			#up_vector = (global_position - parent_body.global_position).normalized()
		
		if input_vector != Vector3.ZERO:
			input_vector = input_vector.normalized()
		var is_jumping = Input.is_action_just_pressed("jump")
		if is_jumping:
			var impulse_vector = jump_strength*up_vector*mass
			impulse_applied.emit(self, impulse_vector)
			impulse_applied.emit(_ground, -impulse_vector)
			_is_stuck_to_surface = false
			is_grounded = false
		

		if !_ignore_spin:
			global_rotate(up_vector, _ground.angular_velocity.dot(up_vector)*delta)
			#angular_velocity +=  _ground.angular_velocity.project(up_vector)
		
		var surface_velocity = _ground.linear_velocity
		if _ground is AstroBody:
			surface_velocity += _ground.get_surface_velocity_from(ground_raycast.get_collision_point())
		var relative_velocity = linear_velocity - surface_velocity
		var upwards_relative_velocity = relative_velocity.project(up_vector)
		var surface_relative_velocity = relative_velocity - upwards_relative_velocity
		#relative_velocity -= upwards_relative_velocity
		var forward_speed = surface_relative_velocity.dot(input_vector)
		var target_force = max(walk_speed-forward_speed, 0)
		if input_vector != Vector3.ZERO:
			move_vector = input_vector*(target_force*walk_acceleration*mass)
			_is_stuck_to_surface = false
		else:
			if !is_jumping and relative_velocity.length_squared() <= 0.2:
				
				# Check for overlap before getting surface position
				var overlap = get_overlap_with_ground()
				if overlap < 0.01:
					if _is_stuck_to_surface:
						var position_delta = global_position - _ground.to_global(_surface_position)
						impulse_applied.emit(self, -position_delta*mass)
					else:
						_is_stuck_to_surface = true
						_surface_position = _ground.to_local(global_position)
					impulse_applied.emit(self, -surface_relative_velocity*mass)
			else:
				_is_stuck_to_surface = false
		if !is_jumping:
			var relative_speed = surface_relative_velocity.length()
			var deceleration_speed = clampf(walk_acceleration, relative_speed/10, relative_speed)
			move_vector -= (relative_velocity.normalized()-input_vector)*deceleration_speed*mass/delta
		#if relative_velocity.length() != 0: print(relative_velocity.length())
	else:
		if input_vector != Vector3.ZERO:
			move_vector = input_vector*thrust_strength*mass
	if move_vector != Vector3.ZERO:
		force_applied.emit(self, move_vector)
	if rotation_axis != 0:
		global_rotate(forward_vector, rotation_axis*thrust_strength*delta*delta)


func _process_look_input(_delta: float) -> void:
	#var left_vector = -global_transform.basis.x.normalized()
	#var up_vector = -global_transform.basis.y.normalized()
	#angular_velocity = Vector3.ZERO
	if _mouselook_enabled:
		#if !in_zero_G:
		camera_pivot.rotation.x -= _mouse_delta.y*_mouse_sensitivity
		if !is_ragdoll or !_thirdperson_enabled:
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-CAMERA_ANGLE_LIMIT), deg_to_rad(CAMERA_ANGLE_LIMIT))
		#else:
			#angular_velocity += left_vector*(_mouse_delta.y*_mouse_sensitivity)/delta
		camera_pivot.rotation.y += _mouse_delta.x*_mouse_sensitivity
		#global_rotate(up_vector, _mouse_delta.x*_mouse_sensitivity)
	_mouse_delta = Vector2.ZERO


func _process_orientation(delta: float) -> void:
	var lerp_speed = 6.0
	_lock_relative_camera_rotation = _is_reorienting
	if camera_pivot.rotation.y != 0.0:
		var up_vector = -global_transform.basis.y.normalized()
		global_rotate(up_vector, camera_pivot.rotation.y)
		camera_pivot.rotation.y = 0
	if !in_zero_G:
		#var target = _ground if is_grounded else parent_body
		var target = parent_body
		var up_vector = (global_position-target.global_position).normalized()
		#var up_vector = -parent_gravity.normalized()
		if get_gravity() != Vector3.ZERO:
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
		if _lock_relative_camera_rotation:
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
		var new_quat = rotation_delta * global_transform.basis.get_rotation_quaternion()
		global_transform.basis = Basis(new_quat)


#func _process_state_orientation(state: PhysicsDirectBodyState3D, delta: float) -> void:
	#var lerp_speed = 6.0
	#_lock_relative_camera_rotation = _is_reorienting
	#if camera_pivot.rotation.y != 0.0:
		#var up_vector = -global_transform.basis.y.normalized()
		#queue_rotation(up_vector, camera_pivot.rotation.y)
		#camera_pivot.rotation.y = 0
	#if !in_zero_G:
		##var target = _ground if is_grounded else parent_body
		#var target = parent_body
		#var up_vector = (global_position-target.global_position).normalized()
		##var up_vector = -parent_gravity.normalized()
		#if get_gravity() != Vector3.ZERO:
			#up_vector = -get_gravity().normalized()
		#var current_quat = global_transform.basis.get_rotation_quaternion()
		#var target_quat = (Quaternion(global_transform.basis.y, up_vector) * current_quat).normalized()
		#var angle_offset = current_quat.angle_to(target_quat)
		#if angle_offset >= deg_to_rad(1):
			#lerp_speed = rad_to_deg(1/angle_offset)/10
		#else:
			#lerp_speed = 1/delta
		##if is_grounded:
			##lerp_speed = 1/delta
		#var new_quat = current_quat.slerp(target_quat, min(lerp_speed*delta, 1.0))
		#if _lock_relative_camera_rotation:
			#if angle_offset <= 0.02:
				#new_quat = target_quat
				#_is_reorienting = false
			#var camera_right_axis = camera_pivot.global_transform.basis.x
			#var old_forward = current_quat * Vector3.FORWARD
			#var new_forward = new_quat * Vector3.FORWARD
			#var pitch_delta = old_forward.signed_angle_to(new_forward, camera_right_axis)
			#camera_pivot.rotation.x -= pitch_delta
		#state.transform.basis = Basis(new_quat)
	#else:
		##_is_reorienting = false
		##if _is_reorienting:
		#var left_vector = global_transform.basis.x.normalized()
		#var old_pitch = camera_pivot.rotation.x
		#var new_pitch = lerp_angle(old_pitch, 0.0, min(lerp_speed*delta, 1.0))
		#if abs(new_pitch) <= 0.001:
			##new_pitch = 0.0
			#_is_reorienting = false
		#var pitch_to_transfer = old_pitch - new_pitch
		#camera_pivot.rotation.x = new_pitch
		#var rotation_delta = Quaternion(left_vector, pitch_to_transfer)
		#var new_quat = rotation_delta * global_transform.basis.get_rotation_quaternion()
		#state.transform.basis = Basis(new_quat)


func get_overlap_with_ground():
	if _ground == null:
		return 0.0
	var params = PhysicsTestMotionParameters3D.new()
	params.from = global_transform
	params.motion = Vector3.ZERO
	var result = PhysicsTestMotionResult3D.new()
	if PhysicsServer3D.body_test_motion(get_rid(), params, result):
		if result.get_collider_rid() == _ground.get_rid():
			return result.get_collision_depth()
	return 0.0

#
#func stick_to_surface(surface: PhysicsBody3D):
	##var up_vector = (global_position - surface.lobal_position).normalized()
	#if _is_stuck_to_surface:
		##var target_position = _ground.to_global(_surface_position)
		##var position_delta = target_position - global_position
		##if position_delta.length_squared() > 0:
			##var corrective_velocity = position_delta/delta
			##corrective_velocity -= corrective_velocity.project(up_vector)
		###print(corrective_velocity.dot(up_vector))
			##apply_force(corrective_velocity*mass)
		#force_applied.emit()
		##global_position = surface.to_global(_surface_position)
	#else:
		#_is_stuck_to_surface = true
		#_surface_position = surface.to_local(global_position)

#
#func queue_rotation(axis: Vector3, angle: float):
	#_rotation_buffer += axis*angle
	
