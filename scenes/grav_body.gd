@tool
extends AnimatableBody3D
class_name GravBody

@export_group("Nodes")
@export var collision_shape: CollisionShape3D
@export var mesh: MeshInstance3D
@export_group("")

@export var radius: float: 
	set(new_radius):
		radius = new_radius
		if collision_shape and mesh:
			collision_shape.shape.radius = new_radius
			mesh.mesh.radius = new_radius
			mesh.mesh.height = 2*new_radius
@export var surface_gravity: float = 1.0:
	set(new_gravity):
		surface_gravity = new_gravity
		mass = max(surface_gravity*pow(radius, 2)/G, 1.0)

@export_group("Orbit")
@export var parent_body: GravBody:
	set(new_parent):
		parent_body = new_parent
		set_orbit(parent_body, orbit_distance, orbit_inclination)
@export var orbit_distance: float:
	set(new_distance):
		orbit_distance = new_distance
		set_orbit(parent_body, orbit_distance, orbit_inclination)
@export_range(-1.0, 1.0, 0.01) var orbit_inclination: float = 0.0:
	set(new_inclination):
		orbit_inclination = new_inclination
		set_orbit(parent_body, orbit_distance, orbit_inclination)
@export_group("")


const G: float = 1.0
var mass: float
var acceleration: Vector3 = Vector3.ZERO
@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var linear_velocity: Vector3 = Vector3.ZERO
@export_custom(PROPERTY_HINT_NONE, "radians_as_degrees,suffix:°/s") var angular_velocity: Vector3 = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func init() -> void:
	print("init")
	collision_shape.shape.radius = radius
	mesh.mesh.radius = radius
	mesh.mesh.height = 2*radius
	if parent_body:
		print("setting orbit")
		set_orbit(parent_body, orbit_distance, orbit_inclination)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	apply_acceleration(delta)
	var new_position = global_position + linear_velocity*delta
	var new_basis = Basis.from_euler(global_rotation + angular_velocity*delta)
	global_transform = Transform3D(new_basis, new_position)


func get_gravity_vector_between(target_body: GravBody, distance_power: int = 2) -> Vector3:
	return get_gravity_vector_from(target_body.global_position, target_body.mass, distance_power)


func get_gravity_vector_from(target_position: Vector3, target_mass: float = 1.0, distance_power: int = 2) -> Vector3:
	var normal := global_position - target_position
	var distance_factor
	if distance_power == 2:
		distance_factor = normal.length_squared()
	else:
		distance_factor = pow(normal.length(), abs(distance_power))
	if abs(distance_factor) <= 0.001:
		return Vector3.ZERO
	return normal.normalized()*(G*mass*target_mass/distance_factor)


func apply_force(force_vector: Vector3, ignore_mass: bool = false):
	acceleration += force_vector if ignore_mass else force_vector/mass


func apply_acceleration(delta: float):
	linear_velocity += acceleration*delta
	acceleration = Vector3.ZERO


func set_orbit(orbit_parent: GravBody, distance: float, inclination: float = 0.0) -> void:
	if orbit_parent == null or !orbit_parent.is_inside_tree():
		return
	var sync_setting = sync_to_physics
	sync_to_physics = false
	var forward_vector = orbit_parent.global_transform.basis.z.normalized()
	var left_vector = orbit_parent.global_transform.basis.x.normalized()
	var M := orbit_parent.mass
	var orbital_speed = sqrt((G*M)/distance)
	global_position = orbit_parent.global_position + forward_vector*distance
	linear_velocity = orbit_parent.linear_velocity + (left_vector*orbital_speed).rotated(forward_vector, inclination*(PI/2))
	sync_to_physics = sync_setting


func get_surface_velocity_from(from_position: Vector3) -> Vector3:
	var r = from_position - global_position
	var surface_velocity = angular_velocity.cross(r)
	return surface_velocity
