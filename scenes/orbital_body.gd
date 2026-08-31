@tool
class_name OrbitalBody
extends AstroBody

@export_group("Nodes")
@export var collision_shape: CollisionShape3D
@export var mesh: MeshInstance3D
@export_subgroup("Orbital Visualization Nodes")
@export var orbital_line_visualization: MeshInstance3D
@export var gravity_well_visualization: MeshInstance3D
@export var barycenter_visualization: Sprite3D
@export_group("")


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
		if orbit and orbit.relative_to_barycenter:
			update_orbit()
		

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

@export_custom(PROPERTY_HINT_NONE, "suffix:m/s")
var initial_linear_velocity: Vector3 = Vector3.ZERO

var _initial_velocity_applied: bool = false


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
	_initialize_orbital_visualization_meshes()
	print_debug(name, " initialized")

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		parent_body = null
	#if Engine.is_editor_hint():
		#if what == NOTIFICATION_TRANSFORM_CHANGED:
			#if orbit and parent_body:
				#var r = 0.0
				#if orbit.relative_to_barycenter:
					#r = orbit.get_barycenter_distance_scalar(mass, parent_body.mass)
				#var original_position = orbit.get_position(r)
				#if global_position != original_position:
					#orbit._ignore_update = true
					#update_orbital_properties_from_translation()
					#orbit._ignore_update = false
					#linear_velocity = orbit.get_orbital_velocity(G*parent_body.mass)
					#
					#generate_orbital_path_visualization(360, r)
			#for child in child_bodies:
				#child.update_orbit()
				#update_orbit()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if orbit:
		redraw_orbital_visualizations()
	#if orbital_line_visualization:
		#if parent_body and orbit:
			#orbital_line_visualization.global_position = parent_body.global_position
		#elif orbital_line_visualization:
			#orbital_line_visualization.visible = false
		
	

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	if !enabled: return
	if !_initial_velocity_applied:
		linear_velocity += initial_linear_velocity
		_initial_velocity_applied = false
	super._physics_process(delta)
	
	
	
		#if orbit.relative_to_barycenter:
			#var barycenter = orbit.get_barycenter(global_position, mass, parent_body.global_position, parent_body.mass)
			#orbital_path.global_position = barycenter
		#else:
			#orbital_path.global_position = parent_body.global_position


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

#region Orbital Properties

const ORBITAL_STABILITY_COEFFICIENT: float = 0.5

@export_category("Orbital Properties")
@export var parent_body: OrbitalBody:
	set(new_parent):
		if new_parent == self:
			push_error("Cannot set body as its own parent")
			return
		if Engine.is_editor_hint(): print_debug("Setting new parent for ", name)
		if parent_body and parent_body.child_bodies:
			parent_body.child_bodies.erase(self)
		parent_body = new_parent
		if parent_body != null:
			parent_body.child_bodies[self] = true

			if orbit and is_inside_tree():
				update_orbit()

@export var orbit: Orbit:
	set(new_orbit):
		if orbit != null and orbit.changed.is_connected(update_orbit):
			orbit.changed.disconnect(update_orbit)
		orbit = new_orbit
		if orbit != null:
			set_meta("_edit_lock_", true) # Orbital bodies with an active orbit should only be positioned by their orbits
			orbit.changed.connect(update_orbit)
			if parent_body:
				update_orbit()
		else:
			set_meta("_edit_lock_", false)

@export
var child_bodies: Dictionary[OrbitalBody, bool] = {}


@export_tool_button("Apply Orbit to Position", "Trackball")
var refresh_orbit: Callable = update_orbit
#
#@export_tool_button("Validate Child Bodies", "Environment")
#var validate_child_bodies_button: Callable = validate_child_bodies

@export_tool_button("Recalculate Orbit From Position", "Trackball")
var recalculate_orbit_button: Callable = calculate_new_orbit

func calculate_new_orbit():
	if !Engine.is_editor_hint():
		if  !_current_strongest_tidal_source:
			orbit = null
			return
		parent_body = _current_strongest_tidal_source
	var relative_position = global_position - parent_body.global_position
	var relative_velocity = linear_velocity - parent_body.linear_velocity
	var gravitational_parameter = G*parent_body.mass
	var new_orbit = Orbit.calculate_orbit(relative_position, relative_velocity, gravitational_parameter)
	while !new_orbit:
		if !parent_body.parent_body or parent_body.parent_body == self:
			parent_body = null
			orbit = null
			return
		parent_body = parent_body.parent_body
		relative_position = global_position - parent_body.global_position
		relative_velocity = linear_velocity - parent_body.linear_velocity
		gravitational_parameter = G*parent_body.mass
		new_orbit = Orbit.calculate_orbit(relative_position, relative_velocity, gravitational_parameter)
	orbit = new_orbit


#@export_tool_button("Calculate Orbit", "Trackball")
#var calc_orbit_button: Callable = func():
	#if !parent_body: return
	#var r = global_position - parent_body.global_position
	#var v = linear_velocity - parent_body.linear_velocity
	#var new_orbit = Orbit.calculate_orbit(r, v, G*parent_body.mass)
	#if new_orbit:
		#print("\nCalculated Orbital Properties:\n",
		#"\n  Semi Major Axis: ", new_orbit.semi_major_axis,
		#"\n  Eccentricity: ", new_orbit.eccentricity,
		#"\n  Inclination: ", rad_to_deg(new_orbit.inclination),
		#"\n  Argument of Periapsis: ", rad_to_deg(new_orbit.argument_of_periapsis),
		#"\n  Longitude of Ascending Node: ", rad_to_deg(new_orbit.longitude_of_ascending_node),
		#"\n  True Anomaly: ", rad_to_deg(new_orbit.true_anomaly))
#
#@export_category("")


func update_orbit():
	if !Engine.is_editor_hint():
		redraw_orbital_visualizations()
		return
	if !enabled: return
	if orbit != null:
		if parent_body == null or !parent_body.is_inside_tree():
			linear_velocity = Vector3.ZERO
			return
		if Engine.is_editor_hint(): print_debug("Updating orbit for: ", name)
		
		if orbit.semi_major_axis == 0.0 and parent_body:
			var stable_orbital_distance = calculate_most_stable_semi_major_axis()
			orbit.semi_major_axis = stable_orbital_distance
			#elif orbit.semi_major_axis == 0:
				#orbit._semi_major_axis = max(0, 2*(radius+parent_body.radius))
		var mass_ratio = parent_body.mass/mass
		#var barycenter = Orbit.get_barycenter(global_position, mass, parent_body.global_position, parent_body.mass) 
		#if barycenter.distance_to(parent_body.global_position) > (0.5*parent_body.radius):\
		if mass_ratio <= 50.0:
			push_warning(name, ": Unstable mass ratio in orbit with ", parent_body.name, ": (", parent_body.mass, ":", mass, ") => ", mass_ratio)
		sync_to_physics = false
		set_ignore_transform_notification(true)
		
		if orbit.synchronous:
			if parent_body.rotational_period == 0:
				push_error("Parent body '", parent_body.name, "' is not valid for synchronous orbit")
				orbit._synchronous = false
			else:
				var target_a = Orbit.get_sma_for_orbital_period(parent_body.rotational_period, G*parent_body.mass)
				if target_a <= radius + parent_body.radius:
					push_error("Parent body '", parent_body.name, "' is not valid for synchronous orbit")
					orbit._synchronous = false
				elif parent_body.orbit and parent_body.orbit.periapsis <= target_a:
					push_error("Parent body '", parent_body.name, "' is not valid for synchronous orbit")
					orbit._synchronous = false # Synchronous orbit is too far from parent
				else:
					orbit._semi_major_axis = target_a

		var orbital_velocity = orbit.get_orbital_velocity(G*parent_body.mass)
		var current_parent = parent_body
		
		while current_parent != null and current_parent.enabled and current_parent.orbit != null:
			if current_parent.parent_body:
				orbital_velocity += current_parent.orbit.get_orbital_velocity(G*current_parent.parent_body.mass)
			else:
				orbital_velocity += current_parent.linear_velocity
			current_parent = current_parent.parent_body
		
		if orbit.periapsis <= parent_body.radius:
			push_warning(name, ": Periapsis intersects with parent body!")
		var r = 0.0
		var origin = parent_body.global_position
		#if orbit.relative_to_barycenter:
			#r = orbit.get_barycenter_distance_scalar(mass, parent_body.mass)
			#var new_position = orbit.get_position(0) + parent_body.global_position
			#origin = orbit.get_barycenter(new_position, mass, parent_body.global_position, parent_body.mass)
		var orbital_position = origin  + orbit.get_position(r)
		if global_position != orbital_position:
			global_position = orbital_position
		linear_velocity = orbital_velocity

		if orbit.tidally_locked:
			rotational_period = orbit.get_orbital_period(G*parent_body.mass)

		sync_to_physics = true
		set_ignore_transform_notification(false)
		#print("true_anomaly: ", rad_to_deg(orbit.true_anomaly))
		if is_inside_tree():
			redraw_orbital_visualizations()
		
	for child_body in child_bodies:
		child_body.update_orbit()


func get_stable_orbital_distance() -> float:
	if !parent_body:
		return INF
	else:
		var parent_distance = global_position.distance_to(parent_body.global_position)
		var stable_orbital_distance = ORBITAL_STABILITY_COEFFICIENT*Orbit.get_hill_sphere_radius(mass, parent_distance, parent_body.mass)
		return stable_orbital_distance


func calculate_most_stable_semi_major_axis() -> float:
	var most_stable_semi_major_axis
	if !parent_body:
		return 0.0
	var farthest_stable_orbital_distance = parent_body.get_stable_orbital_distance()
	var farthest_child_sma = 0.0
	for body in child_bodies:
		if !body.enabled: continue
		if body.orbit.semi_major_axis > farthest_child_sma:
			farthest_child_sma = body.orbit.semi_major_axis
	var farthest_sibling_apoapsis = 0.0
	var farthest_sibling = null
	for sibling_body in parent_body.child_bodies:
		if sibling_body == self or !sibling_body.enabled: continue
		if sibling_body.orbit.apoapsis > farthest_sibling_apoapsis:
			farthest_sibling_apoapsis = sibling_body.orbit.apoapsis
			farthest_sibling = sibling_body
	# Need to find A such that (0.5)*A*cbrt(m/3(m+M)) >= a
	# A >= a/(0.5*cbrt*m/3(m+M))
	var closest_stable_sibling_distance = 0.0
	if farthest_sibling:
		closest_stable_sibling_distance = farthest_sibling_apoapsis + 2*farthest_sibling.get_stable_orbital_distance()
	var closest_stable_orbital_distance = farthest_child_sma/(ORBITAL_STABILITY_COEFFICIENT*Orbit.get_hill_sphere_radius(mass, 1.0, parent_body.mass))
	if closest_stable_orbital_distance > farthest_stable_orbital_distance:
		print("No fully stable semi major axis exists")
		return farthest_stable_orbital_distance
	closest_stable_orbital_distance = max(closest_stable_orbital_distance, closest_stable_sibling_distance)
	if farthest_stable_orbital_distance == INF:
		most_stable_semi_major_axis = 1.15*closest_stable_orbital_distance
	else:
		var margin = farthest_stable_orbital_distance-closest_stable_orbital_distance
		most_stable_semi_major_axis = closest_stable_orbital_distance + 0.75*margin
	return most_stable_semi_major_axis
	
	
	

func validate_child_bodies():
	for child_body in child_bodies.keys().duplicate():
		if !child_body or child_body.parent_body != self:
			child_bodies.erase(child_body)

func clear_child_bodies():
	for child_body in child_bodies.keys().duplicate():
		if child_body and child_body.parent_body == self:
			child_body.parent_body = null
			child_bodies.erase(child_body)


#region Orbital Visualization



@export var show_orbit: bool = true:
	set(val):
		show_orbit = val
		if orbital_line_visualization:
			orbital_line_visualization.visible = show_orbit
			if show_orbit:
				redraw_orbital_visualizations()

@export var show_gravity_well: bool = true:
	set(val):
		show_gravity_well = val
		if is_inside_tree() and gravity_well_visualization:
			gravity_well_visualization.visible = show_gravity_well
			if show_gravity_well:
				redraw_orbital_visualizations()

@export_tool_button("Reload Orbital Visualizations", "Trackball")
var reload_orbital_visualizations_button: Callable = func():
	_initialize_orbital_visualization_meshes()
	redraw_orbital_visualizations()

@onready var ascending_texture = preload("res://assets/normal.png")
@onready var descending_texture = preload("res://assets/anti_normal.png")
@onready var apoapsis_texture = preload("res://assets/radial_out.png")
@onready var periapsis_texture = preload("res://assets/radial_in.png")
@onready var barycenter_texture = preload("res://assets/point_indicator.png")

# I'd like to do this all with shaders in the future but this'll do for now

@onready var orbital_line_visualization_material = preload("res://assets/materials/orbital_path_material.tres")
@onready var gravity_well_visualization_material = preload("res://assets/materials/gravity_well_visualization_material.tres")

func _initialize_orbital_visualization_meshes():
	if !gravity_well_visualization:
		gravity_well_visualization = MeshInstance3D.new()
		add_child(gravity_well_visualization)
	gravity_well_visualization.material_override = gravity_well_visualization_material
	if Engine.is_editor_hint():
		gravity_well_visualization.visible = true
	else:
		gravity_well_visualization.visible = false
	
	if !orbital_line_visualization:
		orbital_line_visualization = MeshInstance3D.new()
		orbital_line_visualization.top_level = true
		add_child(orbital_line_visualization)
	orbital_line_visualization.layers =  0b0000_0000_0000_0000_0000_0000_0000_0100
	orbital_line_visualization.material_override = orbital_line_visualization_material

	if !barycenter_visualization:
		barycenter_visualization = Sprite3D.new()
		add_child(barycenter_visualization)
	barycenter_visualization.texture = barycenter_texture
	barycenter_visualization.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func redraw_orbital_visualizations():
	# Orbital Line
	if orbital_line_visualization:
		if orbit == null or !parent_body or !show_orbit:
			orbital_line_visualization.visible = false
			return
		orbital_line_visualization.visible = true
		var r = 0.0
		#if orbit.relative_to_barycenter:
			#r = orbit.get_barycenter_distance_scalar(mass, parent_body.mass)
		var orbital_path = orbit.get_orbital_path(360, r)
		orbital_line_visualization.mesh = generate_orbital_path_mesh(orbital_path)
		#var normal = (global_position - parent_body.global_position).normalized()
		var focus = parent_body.global_position
		#var orbit_origin = barycenter if orbit.relative_to_barycenter else parent_body.global_position
		orbital_line_visualization.global_position = focus
	
	# Gravity Well
	if gravity_well_visualization:
		if !parent_body or !Engine.is_editor_hint() or !show_gravity_well:
			gravity_well_visualization.visible = false
		else:
			var stable_orbital_radius = get_stable_orbital_distance()
			gravity_well_visualization.mesh = generate_gravity_well_mesh(stable_orbital_radius)
			gravity_well_visualization.visible = true
			gravity_well_visualization.position = Vector3.ZERO
			gravity_well_visualization.rotation = -rotation
	
	# Barycenter
	if barycenter_visualization:
		if !parent_body or !orbit or !show_orbit or !Engine.is_editor_hint():
			barycenter_visualization.visible = false
		else:
			var barycenter = Orbit.get_barycenter(global_position, mass, parent_body.global_position, parent_body.mass)
			barycenter_visualization.visible = true
			barycenter_visualization.global_position = barycenter
			barycenter_visualization.scale = Vector3(1,1,1)*(orbit.semi_major_axis/5)
			barycenter_visualization.no_depth_test = true


static func generate_gravity_well_mesh(stable_radius: float):
	var circle_mesh := CylinderMesh.new()
	circle_mesh.height = 0.01
	circle_mesh.top_radius = stable_radius
	circle_mesh.bottom_radius = stable_radius
	return circle_mesh

static func generate_orbital_path_mesh(orbital_path: PackedVector3Array) -> ArrayMesh:
	# Initialize the ArrayMesh.
	var arr_mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = orbital_path
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINE_STRIP, arrays)
	return arr_mesh


#endregion
#endregion
