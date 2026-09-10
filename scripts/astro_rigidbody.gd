class_name AstroRigidBody
extends RigidBody3D

@export var disable_gravity: bool = false

var parent_body: AstroBody = null
var parent_gravity: Vector3 = Vector3.ZERO
var _current_gravity: Vector3 = Vector3.ZERO
var _current_strongest_gravity: Vector3 = Vector3.ZERO
var _current_strongest_tidal_force: Vector3 = Vector3.ZERO
#var _ground: PhysicsBody3D = null
#var _is_stuck_to_surface: bool = false
#var _surface_position: Vector3 = Vector3.ZERO


signal force_applied(emitter: PhysicsBody3D, force: Vector3, offset: Vector3)
signal impulse_applied(emitter: PhysicsBody3D, impulse: Vector3, offset: Vector3)
signal position_shifted(emitter: PhysicsBody3D, position_delta: Vector3)
signal integrated_forces(emitter: PhysicsBody3D, state: PhysicsDirectBodyState3D)
signal physics_processed(emitter: PhysicsBody3D)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

## Called by the StarSystem at the start of each physics frame.
## Resets appropriate values
func _on_new_frame():
	parent_body = null
	parent_gravity = Vector3.ZERO
	_current_strongest_gravity = Vector3.ZERO
	_current_gravity = get_gravity()
	_current_strongest_tidal_force = Vector3.ZERO

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	physics_processed.emit(self)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	integrated_forces.emit(self, state)


func apply_gravitational_force(source_body: PhysicsBody3D, gravity_vector: Vector3):
	if disable_gravity: return
	force_applied.emit(self, gravity_vector)
	_current_gravity += gravity_vector
	var distance = global_position.distance_to(source_body.global_position)
	if source_body is AstroBody:
		if gravity_vector.length_squared() > _current_strongest_gravity.length_squared():
			_current_strongest_gravity = gravity_vector
		if !is_zero_approx(distance):
			#if source_body.mass <= mass/3.0: # Since this is used for orbital parenting, don't parent to child bodies
			var tidal_force = gravity_vector/distance
			if tidal_force.length_squared() > _current_strongest_tidal_force.length_squared():
				parent_body = source_body
				parent_gravity = gravity_vector
				_current_strongest_tidal_force = tidal_force
		else:
			parent_body = source_body
			parent_gravity = gravity_vector
			_current_strongest_tidal_force = gravity_vector*INF
		#if (distance <= (source_body.radius/2) and parent_gravity == Vector3.ZERO) \
		#or (distance <= 2*source_body.radius and gravity_vector.length_squared() >= _current_strongest_gravity.length_squared()):
			#_current_strongest_gravity = gravity_vector
			#parent_gravity = gravity_vector
			#parent_body = source_body

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
	var G = StarSystem.G
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
