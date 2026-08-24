@tool
extends AnimatableBody3D
class_name GravBody

const G: float = 1.0
var mass: float = 1.0
var acceleration: Vector3 = Vector3.ZERO

@export var body_name: String = "Gravitational Body"

@export var enabled: bool = true:
	set(val):
		if val:
			process_mode = ProcessMode.PROCESS_MODE_INHERIT
		else:
			process_mode = ProcessMode.PROCESS_MODE_DISABLED
		enabled = val

@export var radius: float = 1.0: 
	set(new_radius):
		radius = new_radius
		if collision_shape and mesh:
			collision_shape.shape.radius = new_radius
			mesh.mesh.radius = new_radius
			mesh.mesh.height = 2*new_radius
		calculate_mass()

@export var surface_gravity: float = 1.0:
	set(new_gravity):
		surface_gravity = new_gravity
		calculate_mass()
		

@export_custom(PROPERTY_HINT_NONE, "suffix:seconds") var day_length: float = 0.0:
	set(new_val):
		day_length = new_val
		if day_length == 0.0:
			angular_velocity = Vector3.ZERO
		else:
			var up_vector = transform.basis.y.normalized()
			#print(up_vector, ", ", global_rotation)
			var rotation_speed = 2*PI/day_length
			angular_velocity = up_vector*rotation_speed

@export_group("Nodes")
@export var collision_shape: CollisionShape3D
@export var mesh: MeshInstance3D
@export_group("")


@export var orbit: Orbit:
	set(new_orbit):
		if orbit != null and orbit.changed.is_connected(update_orbit):
			orbit.changed.disconnect(update_orbit)
		orbit = new_orbit
		if orbit != null:
			print("Test 1")
			orbit.changed.connect(update_orbit)
			update_orbit()

var parent_body: GravBody:
	set(new_parent):
		if parent_body and parent_body.child_bodies:
			parent_body.child_bodies.erase(self)
		orbit.parent_body = new_parent.get_path()
		if new_parent != null:
			parent_body.child_bodies[self] = true
			#print(parent_body.child_bodies)
	get():
		if orbit:
			return get_node_or_null(orbit.parent_body)
		else:
			return null
@export var child_bodies: Dictionary[GravBody, bool] = {}

@export_custom(PROPERTY_HINT_NONE, "suffix:m/s") var linear_velocity: Vector3 = Vector3.ZERO
var angular_velocity: Vector3 = Vector3.ZERO

#@export_custom(PROPERTY_HINT_NONE, "radians_as_degrees,suffix:°/s") var angular_velocity: Vector3 = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.

func init() -> void:
	print(self.name, " initialized")
	if collision_shape:
		collision_shape.shape.radius = radius
		mesh.mesh.radius = radius
		mesh.mesh.height = 2*radius


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		pass
		#print(self.name, " rotation: ", rotation, " global: ", global_rotation)
		#if parent_body == null:
			#update_orbit()
	


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if !enabled: return
	apply_acceleration(delta)
	var new_position = global_position + linear_velocity * delta
	var new_basis = global_transform.basis
	if angular_velocity.length_squared() > 0.0:
		new_basis *= Basis(Vector3.UP, angular_velocity.length() * delta).orthonormalized()
		#new_basis *= Basis(angular_velocity.normalized(), angular_velocity.length() * delta)
	
	global_transform = Transform3D(new_basis, new_position)
	#var new_position = global_position + linear_velocity*delta
	#var new_basis = Basis.from_euler(global_rotation + angular_velocity*delta)
	#global_transform = Transform3D(new_basis, new_position)
	
	#var new_position = global_position + linear_velocity*delta
	#var new_basis = global_transform.basis * Basis(Vector3.UP, angular_velocity.length()*delta)
	#global_transform = Transform3D(new_basis, new_position)


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


func update_orbit():
	if orbit != null:
		print("Test")
		var parent_body_node = get_node_or_null(orbit.parent_body)
		if parent_body_node == null or !parent_body_node.is_inside_tree():
			return
		print("Updating Orbit for: ", name)
		var sync_setting = sync_to_physics
		sync_to_physics = false

		var orbital_velocity = orbit.get_orbital_velocity(G*parent_body.mass)
		var current_parent = parent_body_node
		
		while current_parent != null and current_parent.enabled and current_parent.orbit != null:
			orbital_velocity += current_parent.linear_velocity
			current_parent = get_node_or_null(current_parent.orbit.parent_body)
		
		if orbit.periapsis <= parent_body.radius:
			push_warning("Warning: Periapsis intersects with parent body!")
		
		global_position = parent_body_node.global_position + orbit.get_position()
		linear_velocity = orbital_velocity

		if orbit.tidally_locked:
			day_length = get_orbital_period()
			#var new_orbit_up = Vector3.UP.rotated(Vector3.FORWARD, orbit.inclination)
			#var orbit_normal = orbit.get_orbital_plane_normal()
			#var current_up = global_transform.basis.y.normalized()
			#var rotation_axis = current_up.cross(orbit_normal)
			#if rotation_axis.length_squared() > 0.0001:
				#var rotation_angle = current_up.angle_to(orbit_normal)
				#global_transform.basis = Basis(rotation_axis.normalized(), rotation_angle) * global_transform.basis

		sync_to_physics = sync_setting

	for child_body in child_bodies:
		child_body.update_orbit()


func get_orbital_period() -> float:
	if parent_body == null:
		return 0.0
	#var orbital_velocity = (linear_velocity-parent_body.linear_velocity).length()
	var a3 = pow(orbit.apoapsis, 3)
	return 2*PI*sqrt(a3/(G*parent_body.mass))


func get_surface_velocity_from(from_position: Vector3) -> Vector3:
	var r = from_position - global_position
	var speed = angular_velocity.length()
	var world_angular_velocity = global_transform.basis.y.normalized() * speed
	return world_angular_velocity.cross(r)

func calculate_mass():
	mass = max(surface_gravity*pow(radius, 2)/G, 0.01)
	for body in child_bodies:
		body.update_orbit()
	
