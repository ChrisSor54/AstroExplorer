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
			orbit.changed.connect(update_orbit)
			update_orbit()

var parent_body: GravBody:
	set(new_parent):
		if new_parent == self: return
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
	var notify_transform = Engine.is_editor_hint()
	set_notify_transform(notify_transform)

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			if orbit and parent_body and global_position != orbit.get_position():
				generate_orbital_path_visualization(360)
				#update_orbit()


func init() -> void:
	print(self.name, " initialized")
	if collision_shape:
		collision_shape.shape.radius = radius
		mesh.mesh.radius = radius
		mesh.mesh.height = 2*radius


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	


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
	if has_node("./OrbitalPath"):
		get_node("./OrbitalPath").global_position = parent_body.global_position


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




# Orbit ------------------------------------------------------------------------

@onready var ascending_texture = preload("res://assets/normal.png")
@onready var descending_texture = preload("res://assets/anti_normal.png")
@onready var apoapsis_texture = preload("res://assets/radial_out.png")
@onready var periapsis_texture = preload("res://assets/radial_in.png")

var _orbit_markers: Dictionary[String, Sprite3D]

func update_orbit():
	if !enabled: return
	if orbit != null:
		var parent_body_node = get_node_or_null(orbit.parent_body)
		if parent_body == self:
			orbit._ignore_update = true
			orbit.parent_body = ""
			orbit._ignore_update = false
			push_error("Cannot set body as its own parent")
			return
		if parent_body_node == null or !parent_body_node.is_inside_tree():
			return
		
		if orbit.semi_major_axis == 0:
			orbit._semi_major_axis = max(orbit._semi_major_axis, radius+parent_body.radius)
		print("Updating Orbit for: ", name)
		#var sync_setting = sync_to_physics
		sync_to_physics = false
		set_ignore_transform_notification(true)
		
		if orbit.synchronous:
			if parent_body.day_length == 0:
				push_error("Parent body '", parent_body.name, "' is not valid for synchronous orbit")
				orbit._synchronous = false
			else:
				var target_a = orbit.get_sma_for_orbital_period(parent_body.day_length, G*parent_body.mass)
				if target_a <= radius + parent_body.radius:
					push_error("Parent body '", parent_body.name, "' is not valid for synchronous orbit")
					orbit._synchronous = false
				elif parent_body.orbit and parent_body.orbit.periapsis <= target_a:
					push_error("Parent body '", parent_body.name, "' is not valid for synchronous orbit")
					orbit._synchronous = false # Synchronous orbit is too far from parent
				else:
					orbit._semi_major_axis = target_a

		var orbital_velocity = orbit.get_orbital_velocity(G*parent_body.mass)
		var current_parent = parent_body_node
		
		while current_parent != null and current_parent.enabled and current_parent.orbit != null:
			orbital_velocity += current_parent.linear_velocity
			current_parent = get_node_or_null(current_parent.orbit.parent_body)
		
		if orbit.periapsis <= parent_body.radius:
			push_warning(name, ": Periapsis intersects with parent body!")
		var orbital_position = parent_body_node.global_position + orbit.get_position()
		if global_position != orbital_position:
			global_position = orbital_position
		linear_velocity = orbital_velocity

		if orbit.tidally_locked:
			day_length = orbit.get_orbital_period(G*parent_body.mass)

		sync_to_physics = true
		set_ignore_transform_notification(false)
		generate_orbital_path_visualization(360)
		
	for child_body in child_bodies:
		child_body.update_orbit()
		
	


func get_surface_velocity_from(from_position: Vector3) -> Vector3:
	var r = from_position - global_position
	var speed = angular_velocity.length()
	var world_angular_velocity = global_transform.basis.y.normalized() * speed
	return world_angular_velocity.cross(r)

func calculate_mass():
	mass = max(surface_gravity*pow(radius, 2)/G, 0.01)
	for body in child_bodies:
		body.update_orbit()

func generate_orbital_path_visualization(num_points: int = 360):
	var orbital_path: MeshInstance3D = get_node_or_null("./OrbitalPath")
	if !orbital_path:
		return
	print("Generating mesh")

	var vertices = orbit.get_orbital_path(num_points)
	
	# Initialize the ArrayMesh.
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices

	# Create the Mesh.
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	orbital_path.mesh = arr_mesh
	orbital_path.global_position = parent_body.global_position
	
	# Visualize nodes
	var orbit_normal = orbit.get_orbital_plane_normal()
	var orbit_in = (parent_body.global_position - global_position).normalized()
	var ascending_true_anomaly = -orbit.argument_of_periapsis
	
	var ascending = orbit.get_position_at_true_anomaly(ascending_true_anomaly)
	var ascending_node = ascending - ascending.project(Vector3.UP)
	var descending_node = orbit.get_position_at_true_anomaly(ascending_true_anomaly + PI) - ascending.project(Vector3.UP)
	var apoapsis = orbit.get_position_at_true_anomaly(PI)
	var periapsis = orbit.get_position_at_true_anomaly(0)

	var orbit_origin = parent_body.global_position
	
	var marker_data = {
		"AscendingNode": [ascending_texture, ascending_node],
		"DescendingNode": [descending_texture, descending_node],
		"Apoapsis": [apoapsis_texture, apoapsis],
		"Periapsis": [periapsis_texture, periapsis],
	}
	
	if _orbit_markers == null: _orbit_markers = {}

	for marker_name in marker_data:
		var texture = marker_data[marker_name][0]
		var local_pos = marker_data[marker_name][1]
		
		if !has_node("./OrbitalPath/" + marker_name):
			var sprite = Sprite3D.new()
			sprite.name = marker_name
			sprite.texture = texture
			sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			sprite.scale = Vector3(100,100,100)
			sprite.owner = orbital_path.owner
			orbital_path.add_child(sprite)
			
		_orbit_markers[marker_name].global_position = local_pos + orbit_origin
		
