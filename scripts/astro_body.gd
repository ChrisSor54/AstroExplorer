class_name AstroBody
extends AnimatableBody3D


## Gravitational Constant
const G: float = StarSystem.G


@export
var enabled: bool = true:
	set(val):
		if val:
			process_mode = ProcessMode.PROCESS_MODE_INHERIT
		else:
			process_mode = ProcessMode.PROCESS_MODE_DISABLED
		enabled = val
		visible = val


@export var radius: float = 1.0
@export var mass: float = 1.0

@export_custom(PROPERTY_HINT_NONE, "suffix:m/s")
var linear_velocity: Vector3 = Vector3.ZERO
#var linear_velocity: Vector3 = Vector3.ZERO:
	#set(val):
		#linear_velocity = val
		##constant_linear_velocity = val

var _linear_acceleration: Vector3 = Vector3.ZERO
var _linear_impulse: Vector3 = Vector3.ZERO

## The gravitational acceleration experienced by the body this frame
var _current_gravitational_acceleration: Vector3 = Vector3.ZERO

@export_custom(PROPERTY_HINT_NONE, "radians_as_degrees,suffix:m/s")
var angular_velocity: Vector3 = Vector3.ZERO
#var angular_velocity: Vector3 = Vector3.ZERO:
	#set(val):
		#angular_velocity = val
		##constant_angular_velocity = val


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	#constant_linear_velocity = linear_velocity
	#constant_angular_velocity = angular_velocity
	constant_linear_velocity = Vector3.ZERO
	constant_angular_velocity = Vector3.ZERO


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	_process_forces(delta)
	var updated_origin = global_position + linear_velocity*delta
	var updated_basis = global_transform.basis
	if angular_velocity.length_squared() > 0.0:
		updated_basis *= Basis(Vector3.UP, angular_velocity.length()*delta).orthonormalized()
		#new_basis *= Basis(angular_velocity.normalized(), angular_velocity.length() * delta)
	global_transform = Transform3D(updated_basis.orthonormalized(), updated_origin)
	#constant_linear_velocity = Vector3.ZERO
	#constant_angular_velocity = Vector3.ZERO


## Applies acceleration buffers to linear velocity
func _process_forces(delta: float):
	linear_velocity += _linear_acceleration*delta + _linear_impulse
	_linear_acceleration = Vector3.ZERO
	_linear_impulse = Vector3.ZERO

## Called by the StarSystem at the start of each physics frame.
## Resets appropriate values
func _on_new_frame():
	_current_gravitational_acceleration = Vector3.ZERO

## Applies a given force in m/s
func apply_force(force_vector: Vector3):
	_linear_acceleration += force_vector/mass

## Applies a one time force impulse
func apply_impulse(impulse_vector: Vector3):
	_linear_impulse += impulse_vector/mass


## Applies a gravitational attraction
func apply_gravitational_force(gravity_vector: Vector3):
	apply_force(gravity_vector)
	_current_gravitational_acceleration += gravity_vector/mass
	

## Get the graviational acceleration this body produces on [param target_body].
## Returns a Vector3 pointing to the target body, whos magnitude is the resulting force.
func get_gravity_between_body(target_body: Variant) -> Vector3:
	if target_body is AstroBody or target_body is AstroRigidBody:
		return get_gravity_between(target_body.global_position, target_body.mass)
	else:
		push_error(target_body, " is not a valid body")
		return Vector3.ZERO
	
## Returns the gravitational acceleration this body would produce on an object at
## [param target_position] with a mass of [param target_mass].
## Returns a [Vector3] pointing to a target at [param target_position], whos magnitude is the resulting force.
func get_gravity_between(target_position: Vector3, target_mass: float = 1.0) -> Vector3:
	var normal := global_position - target_position
	var sqr_distance = normal.length_squared()
	var gravity_vector = Vector3.ZERO
	if is_zero_approx(sqr_distance):
		gravity_vector = Vector3.ZERO
	elif sqr_distance >= pow(radius, 2):
		gravity_vector = normal.normalized()*(G*mass*target_mass/sqr_distance)
	else:
		var distance = normal.length()
		gravity_vector = normal.normalized()*((G*mass*target_mass*distance)/(pow(radius, 3)))
	return gravity_vector
