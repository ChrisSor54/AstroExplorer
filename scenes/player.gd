extends GBody
class_name Player

# Nodes
@export_category("Nodes")
@export var home_planet: GBody
@export var grounded_raycast: RayCast3D

@export_group("Camera")
@export var camera: Camera3D
@export var camera_pivot: Node3D

const CAMERA_ANGLE_LIMIT: float = 80
const JUMP_IMPULSE: float = 10
const MAX_GROUNDED_MOVE_SPEED: float = 10

@export_category("Properties")
@export var thrust_speed: float = 10.0
@export var move_speed: float = 10.0
@export var rotate_speed: float = 5.0
var is_grounded: bool = true
var in_zero_G: bool = true

var _ground: GBody
var strongest_gravitational_force: float = 0

var _move_velocity: Vector3 = Vector3.ZERO
var _thirdperson_enabled: bool = true
var _mouse_sensitivity := 0.003
var _mouse_delta = Vector2.ZERO
var _mouselook_enabled = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	system = get_parent()

func init():
	if home_planet:
		teleport_to_body(home_planet)

func teleport_to_body(body: GBody) -> void:
	var body_up_vector := body.global_transform.basis.y.normalized()
	global_position = body.global_position + body_up_vector*(body.radius + collision_shape.shape.height/2)
	linear_velocity = body.constant_linear_velocity

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
	pass
	#print(linear_velocity)


func _physics_process(delta: float) -> void:
	update_gravity()
	is_grounded = false
	in_zero_G = true
	angular_velocity = Vector3.ZERO
	
	if grounded_raycast.is_colliding() and grounded_raycast.get_collider() is GBody:
		is_grounded = true
		_ground = grounded_raycast.get_collider()
	if strongest_gravitational_force >= 1.0:
		in_zero_G = false
	
	_process_auto_orientation()
	_process_movement_inputs(delta)
	_process_camera_inputs(delta)
	
	#update_velocity()

func update_gravity() -> void:
	parent_body = null
	strongest_gravitational_force = -1
	if system.bodies:
		for body in system.bodies:
			if body.process_mode == ProcessMode.PROCESS_MODE_DISABLED: continue
			var gravitational_force = body.get_gravity_vector_from(global_position)
			if gravitational_force.length_squared() > strongest_gravitational_force:
				strongest_gravitational_force = gravitational_force.length_squared()
				parent_body = body
			apply_force(gravitational_force)


func _process_auto_orientation() -> void:
	var orientation_target = null
	if is_grounded:
		orientation_target = _ground
	elif !in_zero_G:
		orientation_target = parent_body
	if orientation_target != null:
		var up_vector = (global_position - orientation_target.global_position).normalized()
		var oriented_rotation = Quaternion(global_transform.basis.y, up_vector) * global_transform.basis.get_rotation_quaternion()
		global_rotation = oriented_rotation.normalized().get_euler()


func _process_movement_inputs(delta: float) -> void:
	var forward_vector = -global_transform.basis.z.normalized()
	var left_vector = -global_transform.basis.x.normalized()
	var up_vector = global_transform.basis.y.normalized()
	angular_damp = 10.0
	
	var input_vector = Vector3.ZERO
	var move_vector = Vector3.ZERO
	
	input_vector += Input.get_axis("backward", "forward") * forward_vector
	input_vector += Input.get_axis("right", "left") * left_vector
	if is_grounded:
		if Input.is_action_just_pressed("jump"):
			var impulse_vector = JUMP_IMPULSE*up_vector
			apply_central_impulse(impulse_vector)
	else:
		input_vector += Input.get_axis("fly_down", "fly_up") * up_vector
	#if is_grounded:
		#var colliding_body = grounded_raycast.get_collider()
		#if colliding_body is GBody:
			#angular_velocity = colliding_body.constant_angular_velocity.project(up_vector)
			#angular_damp = 0

	if input_vector != Vector3.ZERO:
		input_vector = input_vector.normalized()
		if is_grounded:
			move_vector = input_vector*move_speed
			var relative_velocity = linear_velocity - _ground.linear_velocity
			var forward_speed = relative_velocity.dot(input_vector)
			var capped_speed = clamp(MAX_GROUNDED_MOVE_SPEED-forward_speed, 0.0, move_speed)
			#if forward_speed > MAX_GROUNDED_MOVE_SPEED: capped_speed = 0.0
			#print(forward_speed, ", ", capped_speed)
			move_vector = input_vector*capped_speed
		else:
			move_vector = input_vector.normalized()*thrust_speed
		
		apply_central_force(move_vector)
		#_move_velocity += move_vector*delta


func _process_camera_inputs(delta: float) -> void:
	var left_vector = -global_transform.basis.x.normalized()
	var up_vector = -global_transform.basis.y.normalized()
	angular_velocity = Vector3.ZERO
	if _mouselook_enabled:
		if !in_zero_G:
			camera_pivot.rotation.x -= _mouse_delta.y*_mouse_sensitivity
			camera_pivot.rotation.x = clamp(camera_pivot.rotation.x, deg_to_rad(-CAMERA_ANGLE_LIMIT), deg_to_rad(CAMERA_ANGLE_LIMIT))
		else:
			camera_pivot.rotation.x = 0
			angular_velocity += left_vector*(_mouse_delta.y*_mouse_sensitivity)/delta
		if (_mouse_delta.x != 0):
			angular_velocity += up_vector*(_mouse_delta.x*_mouse_sensitivity)/delta
	_mouse_delta = Vector2.ZERO


func update_velocity():
	linear_velocity += acceleration
	acceleration = Vector3.ZERO
