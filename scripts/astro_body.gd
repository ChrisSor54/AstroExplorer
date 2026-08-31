class_name AstroBody
extends AnimatableBody3D


## Gravitational Constant
const G: float = StarSystem.G

var _current_strongest_gravity_source: PhysicsBody3D
var _current_strongest_gravity: Vector3 = Vector3.ZERO
var _current_strongest_tidal_source: PhysicsBody3D
var _current_strongest_tidal_force: Vector3 = Vector3.ZERO

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

## Called by the StarSystem at the start of each physics frame.
## Resets appropriate values
func _on_new_frame():
	_current_gravitational_acceleration = Vector3.ZERO
	_current_strongest_gravity_source = null
	_current_strongest_gravity = Vector3.ZERO
	_current_strongest_tidal_source = null
	_current_strongest_tidal_force = Vector3.ZERO

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
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

## Applies a given force in m/s
func apply_force(force_vector: Vector3):
	if is_zero_approx(mass): return
	_linear_acceleration += force_vector/mass

## Applies a one time force impulse
func apply_impulse(impulse_vector: Vector3):
	if is_zero_approx(mass): return
	_linear_impulse += impulse_vector/mass


## Applies a gravitational attraction
func apply_gravitational_force(source_body: PhysicsBody3D, gravity_vector: Vector3):
	if is_zero_approx(mass): return
	apply_force(gravity_vector)
	_current_gravitational_acceleration += gravity_vector/mass
	if gravity_vector.length_squared() > _current_strongest_gravity.length_squared():
		_current_strongest_gravity = gravity_vector
		_current_strongest_gravity_source = source_body
	var distance = global_position.distance_to(source_body.global_position)
	if !is_zero_approx(distance):
		#if source_body.mass <= mass/3.0: # Since this is used for orbital parenting, don't parent to child bodies
		if source_body.mass <= mass:
			return
		var tidal_force = gravity_vector/distance
		if tidal_force.length_squared() > _current_strongest_tidal_force.length_squared():
			_current_strongest_tidal_source = source_body
			_current_strongest_tidal_force = tidal_force
	else:
		_current_strongest_tidal_source = source_body
		_current_strongest_tidal_force = gravity_vector*99999
	

## Get the gravitational attraction this body experiences from [param target_body]
##
## Calculates the gravitational force this body experiences from [param target_body].
## Returns a [Vector3] pointing to the [param target_body]'s relative position, with a magnitude of the resulting force.
func get_gravity_from_body(target_body: Variant) -> Vector3:
	if target_body is AstroBody:
		return get_gravity_from(target_body.global_position, target_body.mass, target_body.radius)
	elif target_body is AstroRigidBody:
		return get_gravity_from(target_body.global_position, target_body.mass)
	else:
		push_error(target_body, " is not a valid body")
		return Vector3.ZERO


## Get the gravitational attraction this body experiences from an object at [param target_position] with a mass of [param target_mass] and
## a radius of [param target_radius].
##
## Calculates the gravitational force this body would experience from on an object at
## [param target_position] with a mass of [param target_mass].
## Returns a [Vector3] pointing to the relative [param target_position], with a magnitude of the resulting force.
## If [param target_radius] is provided, the gravitational force will be reduced according to the shell theorem, provided
## that [self] is inside the [param target_radius].
func get_gravity_from(target_position: Vector3, target_mass: float = 1.0, target_radius: float = 0.0) -> Vector3:
	var normal := target_position - global_position
	var sqr_distance = normal.length_squared()
	var gravity_vector = Vector3.ZERO
	if is_zero_approx(sqr_distance):
		gravity_vector = Vector3.ZERO
	elif is_zero_approx(target_radius) or sqr_distance >= target_radius*target_radius:
		gravity_vector = normal.normalized()*(G*mass*target_mass/sqr_distance)
	else:
		var distance = normal.length()
		gravity_vector = normal.normalized()*((G*mass*target_mass*distance)/(target_radius*target_radius*target_radius))
	return gravity_vector
