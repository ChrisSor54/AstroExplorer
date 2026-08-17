extends RigidBody3D
class_name GBody

const G: float = 1.0

@export var collision_shape: CollisionShape3D

@export var surface_gravity: float = 1.0


@export_group("Orbit")
@export var parent_body: GBody
@export var orbit_distance: float
@export_range(-180, 180, 1, "degrees") var orbit_angle: float = 0.0
@export_range(-1.0, 1.0, 0.01) var orbit_inclination: float = 0.0


var system: SolarSystem

var acceleration: Vector3 = Vector3.ZERO
var radius:
	get(): return collision_shape.shape.radius
#var mass: float = 1.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	system = get_parent()
	mass = (surface_gravity*pow(radius, 2))/G

func init():
	if parent_body:
		set_orbit(parent_body, orbit_distance, deg_to_rad(orbit_angle), orbit_inclination)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	pass
	#global_position += constant_linear_velocity*delta

func update_velocity():
	pass
	#constant_linear_velocity += acceleration
	#acceleration = Vector3.ZERO


func get_gravity_vector_from(from_global_position: Vector3):
	var normal = global_position - from_global_position
	if normal.length_squared() == 0:
		return Vector3.ZERO
	var normalDir = normal.normalized()
	#print(normal.length())
	return normalDir * (G*mass/normal.length_squared())

func update_gravity():
	for body in system.bodies:
		if body.process_mode == ProcessMode.PROCESS_MODE_DISABLED: continue
		var gravitational_force = body.get_gravity_vector_from(global_position)
		apply_force(gravitational_force)

func set_orbit(parent: GBody, distance: float, angle_rad: float = 0.0, inclination: float = 0.0, eccentricity: float = 0.0) -> void:
	var parent_left_vector: Vector3 = parent.global_transform.basis.x.normalized()
	var parent_up_vector: Vector3 = parent.global_transform.basis.y.normalized()
	var parent_forward_vector: Vector3 = parent.global_transform.basis.z.normalized()
	var position_vector: Vector3 = parent_forward_vector.rotated(parent_up_vector, angle_rad)*distance
	
	var orbit_vector: Vector3 = (parent_left_vector.rotated(parent_forward_vector, inclination*(PI/2))).rotated(parent_up_vector, angle_rad)
	var M = parent.mass
	orbit_vector *= sqrt((G*M)/distance)
	
	global_position = position_vector + parent.global_position
	linear_velocity = parent.linear_velocity + orbit_vector
