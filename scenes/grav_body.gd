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
@export var orbit_inclination: float = 0.0:
	set(new_inclination):
		orbit_inclination = new_inclination
		set_orbit(parent_body, orbit_distance, orbit_inclination)
@export_group("")



@onready var system: StarSystem = get_parent()

const G: float = 1.0
var mass: float
var acceleration: Vector3 = Vector3.ZERO
var linear_velocity: Vector3 = Vector3.ZERO
@export var angular_velocity: Vector3 = Vector3.ZERO



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
		set_orbit(parent_body, orbit_distance)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	apply_acceleration(delta)
	var new_position = global_position + linear_velocity*delta
	var new_basis = Basis.from_euler(global_rotation + constant_angular_velocity*delta)
	global_transform = Transform3D(new_basis, new_position)

func get_gravity_vector_between(target_body: GravBody) -> Vector3:
	return get_gravity_vector_from(target_body.global_position, target_body.mass)

func get_gravity_vector_from(target_position: Vector3, target_mass: float = 1.0) -> Vector3:
	var normal := global_position - target_position
	var sqr_distance = normal.length_squared()
	if abs(sqr_distance) <= 0.001:
		return Vector3.ZERO
	return normal.normalized()*(G*mass*target_mass/sqr_distance)

func apply_force(force_vector: Vector3):
	acceleration += force_vector/mass

func apply_acceleration(delta: float):
	linear_velocity += acceleration*delta
	acceleration = Vector3.ZERO

func set_orbit(orbit_parent: GravBody, distance: float, inclination: float = 0.0) -> void:
	if orbit_parent == null or !orbit_parent.is_inside_tree():
		return
	var sync_setting = sync_to_physics
	sync_to_physics = false
	#var forward_vector = orbit_parent.global_transform.basis.z.normalized()
	#var left_vector = orbit_parent.global_transform.basis.x.normalized()
	var M := orbit_parent.mass
	var orbital_speed = sqrt((G*M)/distance)
	global_position = orbit_parent.global_position + -Vector3.FORWARD*distance
	linear_velocity = orbit_parent.linear_velocity + (-Vector3.LEFT*orbital_speed).rotated(Vector3.FORWARD, inclination*(PI/2))
	sync_to_physics = sync_setting
