@tool
class_name OrbitalBody
extends AstroBody




@export
var body_name: String

@export_custom(PROPERTY_HINT_NONE, "suffix:m")
var surface_height: float = 1.0: 
	set(new_radius):
		radius = new_radius
		if collision_shape and mesh:
			collision_shape.shape.radius = new_radius
			mesh.mesh.radius = new_radius
			mesh.mesh.height = 2*new_radius
		calculate_mass()
	get(): return radius

@export_custom(PROPERTY_HINT_NONE, "suffix:m/s²")
var surface_gravity: float = 1.0:
	set(new_gravity):
		surface_gravity = new_gravity
		calculate_mass()
		

@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var rotational_period: float = 0.0:
	set(new_val):
		rotational_period = new_val
		if rotational_period == 0.0:
			angular_velocity = Vector3.ZERO
		else:
			var up_vector = transform.basis.y.normalized()
			#print(up_vector, ", ", global_rotation)
			var rotation_speed = 2*PI/rotational_period
			angular_velocity = up_vector*rotation_speed

@export_group("Nodes")
@export var collision_shape: CollisionShape3D
@export var mesh: MeshInstance3D
@export_group("")




@export var orbit: Orbit:
	set(new_orbit):
		if orbit != null and orbit.changed.is_connected(update_orbit):
			_parent_body = null
			orbit.changed.disconnect(update_orbit)
		orbit = new_orbit
		if orbit != null:
			orbit.changed.connect(update_orbit)
			if !orbit.parent_body.is_empty():
				update_orbit()


# ONLY TO BE MODIFIED INTERNALLY
var _parent_body: OrbitalBody:
	set(new_parent):
		if _parent_body and _parent_body.child_bodies:
			_parent_body.child_bodies.erase(self)
		_parent_body = new_parent
		if _parent_body != null:
			_parent_body.child_bodies[self] = true

var parent_body: OrbitalBody:
	set(new_parent):
		if parent_body != null:
			orbit.parent_body = parent_body.get_path()
		else:
			orbit = Orbit.new()

	get():
		if orbit:
			return get_node_or_null(orbit.parent_body)
		else:
			return null


@export_tool_button("Recalculate Orbit", "Trackball")
var recalculate_orbit_button: Callable = recalculate_orbit

@export
var child_bodies: Dictionary[OrbitalBody, bool] = {}

@export_tool_button("Validate Child Bodies", "Environment")
var validate_child_bodies_button: Callable = validate_child_bodies



#@export_custom(PROPERTY_HINT_NONE, "radians_as_degrees,suffix:°/s") var angular_velocity: Vector3 = Vector3.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	var notify_transform = Engine.is_editor_hint()
	set_notify_transform(notify_transform)
	if collision_shape:
		collision_shape.shape.radius = radius
		mesh.mesh.radius = radius
		mesh.mesh.height = 2*radius
	print(self.name, " initialized")

func _notification(what: int) -> void:
	if Engine.is_editor_hint():
		if what == NOTIFICATION_TRANSFORM_CHANGED:
			if orbit and parent_body:
				var original_position = orbit.get_position()
				if global_position != original_position:
					orbit._ignore_update = true
					update_orbital_properties_from_translation()
					orbit._ignore_update = false
					linear_velocity = orbit.get_orbital_velocity(G*parent_body.mass)

					generate_orbital_path_visualization(360)
			for child in child_bodies:
				child.update_orbit()
				#update_orbit()

func _exit_tree() -> void:
	_parent_body = null
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if !enabled: return
	super._physics_process(delta)
	
	var orbital_path = get_node_or_null("./OrbitalPath")
	if orbital_path != null:
		orbital_path.global_position = parent_body.global_position


func get_surface_velocity_from(from_position: Vector3) -> Vector3:
	var r = from_position - global_position
	var speed = angular_velocity.length()
	var world_angular_velocity = global_transform.basis.y.normalized() * speed
	return world_angular_velocity.cross(r)


func calculate_mass():
	mass = max(surface_gravity*pow(radius, 2)/G, 0.01)
	for body in child_bodies:
		body.update_orbit()








# Orbit ------------------------------------------------------------------------

#func _on_orbit_parent_body_changed():
	#var parent_body_node = get_node_or_null(orbit.parent_body)
	#if parent_body_node and parent_body_node.child_bodies:
			#parent_body_node.child_bodies.erase(self)
		#_parent_body = new_parent
		#if _parent_body != null:
			#orbit.parent_body = _parent_body.get_path()
			#_parent_body.child_bodies[self] = true
		#else:
			#orbit = Orbit.new()

func update_orbit():
	if !enabled: return
	if orbit != null:
		var parent_body_node = get_node_or_null(orbit.parent_body)
		if parent_body_node == self:
			orbit._ignore_update = true
			orbit.parent_body = ""
			orbit._ignore_update = false
			push_error("Cannot set body as its own parent")
			return
		if _parent_body != parent_body_node:
			_parent_body = parent_body_node
		if parent_body_node == null or !parent_body_node.is_inside_tree():
			return
		print(parent_body_node.name, ", ", parent_body.name)
		
		if orbit.semi_major_axis == 0:
			orbit._semi_major_axis = max(0, 2*(radius+parent_body.radius))
		#print("Updating Orbit for: ", name)
		#var sync_setting = sync_to_physics
		sync_to_physics = false
		set_ignore_transform_notification(true)
		
		if orbit.synchronous:
			if parent_body.rotational_period == 0:
				push_error("Parent body '", parent_body.name, "' is not valid for synchronous orbit")
				orbit._synchronous = false
			else:
				var target_a = orbit.get_sma_for_orbital_period(parent_body.rotational_period, G*parent_body.mass)
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
			rotational_period = orbit.get_orbital_period(G*parent_body.mass)

		sync_to_physics = true
		set_ignore_transform_notification(false)
		generate_orbital_path_visualization(360)
		
	for child_body in child_bodies:
		child_body.update_orbit()
		
	
func recalculate_orbit():
		if orbit == null or parent_body == null:
				return
		var relative_position = global_position - parent_body.global_position
		var relative_velocity = linear_velocity - parent_body.linear_velocity
		var gravitational_parameter = G*parent_body.mass
		orbit.recalculate_orbital_properties(relative_position, relative_velocity, gravitational_parameter)


func validate_child_bodies():
	for child_body in child_bodies:
		if !child_body or child_body.parent_body != self:
			child_bodies.erase(child_body)

func clear_child_bodies():
	for child_body in child_bodies:
		if child_body and child_body.parent_body == self:
			child_body.parent_body = null
			child_bodies.erase(child_body)


@onready var ascending_texture = preload("res://assets/normal.png")
@onready var descending_texture = preload("res://assets/anti_normal.png")
@onready var apoapsis_texture = preload("res://assets/radial_out.png")
@onready var periapsis_texture = preload("res://assets/radial_in.png")

func generate_orbital_path_visualization(num_points: int = 360):
	var orbital_path: MeshInstance3D = get_node_or_null("./OrbitalPath")
	if !orbital_path:
		orbital_path = MeshInstance3D.new()
		orbital_path.set_layer_mask_value(1, false)
		orbital_path.set_layer_mask_value(2, false)
		orbital_path.set_layer_mask_value(3, true)
		add_child(orbital_path)
	
	if orbit == null or !parent_body:
		orbital_path.visible = false
		return
	#print("Generating mesh")

	orbital_path.visible = true
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
	
	var ascending_node = orbit.get_position_at_true_anomaly(-orbit.argument_of_periapsis)
	ascending_node.y = 0
	var descending_node = orbit.get_position_at_true_anomaly(-orbit.argument_of_periapsis + PI)
	descending_node.y = 0
	var apoapsis = orbit.get_position_at_true_anomaly(PI)
	var periapsis = orbit.get_position_at_true_anomaly(0)

	var orbit_origin = parent_body.global_position
	
	var marker_data = {
		"AscendingNode": [ascending_texture, ascending_node],
		"DescendingNode": [descending_texture, descending_node],
		"Apoapsis": [apoapsis_texture, apoapsis],
		"Periapsis": [periapsis_texture, periapsis],
	}
	
	for marker_name in marker_data:
		var hide_node = ((marker_name == "AscendingNode" or marker_name == "DescendingNode") and orbit.inclination == 0) \
		or ((marker_name == "Apoapsis" or marker_name == "Periapsis") and orbit.eccentricity == 0)
		var node_path = "./OrbitalPath/" + marker_name
		
		var sprite: Sprite3D = get_node_or_null(node_path)
		if !sprite:
			var texture = marker_data[marker_name][0]
			
			sprite = Sprite3D.new()
			sprite.name = marker_name
			sprite.texture = texture
			orbital_path.add_child(sprite)
		sprite.set_layer_mask_value(1, false)
		sprite.set_layer_mask_value(2, false)
		sprite.set_layer_mask_value(3, true)
		sprite.visible = !hide_node
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.scale = Vector3(1,1,1)*radius
		sprite.no_depth_test = true
		sprite.global_position = marker_data[marker_name][1] + orbit_origin


func update_orbital_properties_from_translation():
	var relative_position = global_position - parent_body.global_position
	var r = relative_position.length()
	if r == 0:
		return
	var e = orbit.eccentricity
	var w = orbit.argument_of_periapsis
	var previous_position = orbit.get_position()
	var delta = relative_position - previous_position
	var delta_len = delta.length()
	var lateral_delta_len = Vector2(delta.x, delta.z).length()
	var is_lateral_only = delta_len > 0 and absf(delta.y) <= 1e-6 * delta_len
	var is_vertical_only = delta_len > 0 and lateral_delta_len <= 1e-6 * delta_len
	var p_hat = relative_position / r
	var i = orbit._inclination
	var new_i = i
	var new_om = orbit._longitude_of_ascending_node
	var plane_found = false
	var sin_i = sin(i)
	var cos_i = cos(i)
	if not is_vertical_only:
		if absf(sin_i) > 1e-6:
			var a_coef = -relative_position.x
			var b_coef = relative_position.z
			var c_coef = -(cos_i / sin_i) * relative_position.y
			var amplitude = sqrt(a_coef*a_coef + b_coef*b_coef)
			if amplitude > 1e-9 and (is_lateral_only or absf(c_coef) <= amplitude + 1e-6):
				var c_clamped = clamp(c_coef, -amplitude, amplitude)
				var phi = atan2(b_coef, a_coef)
				var delta_angle = acos(clamp(c_clamped / amplitude, -1.0, 1.0))
				var candidate_a = phi + delta_angle
				var candidate_b = phi - delta_angle
				var diff_a = absf(wrapf(candidate_a - orbit._longitude_of_ascending_node, -PI, PI))
				var diff_b = absf(wrapf(candidate_b - orbit._longitude_of_ascending_node, -PI, PI))
				new_om = candidate_a if diff_a <= diff_b else candidate_b
				plane_found = true
		else:
			if is_lateral_only or absf(relative_position.y) <= 1e-4 * max(r, 1.0):
				plane_found = true
	if not plane_found:
		var old_normal = orbit.get_orbital_plane_normal()
		var component = old_normal - old_normal.dot(p_hat) * p_hat
		var new_normal: Vector3
		if component.length_squared() > 1e-9:
			new_normal = component.normalized()
		else:
			var reference = Vector3.UP if absf(p_hat.dot(Vector3.UP)) < 0.9 else Vector3.RIGHT
			new_normal = p_hat.cross(reference).normalized()
		new_i = acos(clamp(new_normal.y, -1.0, 1.0))
		if sin(new_i) > 1e-6:
			new_om = atan2(new_normal.z, -new_normal.x)
		else:
			new_om = orbit._longitude_of_ascending_node
	orbit._inclination = new_i
	orbit._longitude_of_ascending_node = wrapf(new_om, -PI, PI)
	var cos_om2 = cos(orbit._longitude_of_ascending_node)
	var sin_om2 = sin(orbit._longitude_of_ascending_node)
	var cos_i2 = cos(new_i)
	var sin_i2 = sin(new_i)
	var p0 = Vector3(sin_om2, 0.0, cos_om2)
	var q0 = Vector3(cos_om2 * cos_i2, sin_i2, -sin_om2 * cos_i2)
	var u = atan2(relative_position.dot(q0), relative_position.dot(p0))
	var new_nu = wrapf(u - w, -PI, PI)
	orbit._true_anomaly = new_nu
	var denom = 1.0 - e * e
	if absf(denom) > 1e-9:
		orbit._semi_major_axis = r * (1.0 + e * cos(new_nu)) / denom
	for body in child_bodies:
		body.update_orbit()
