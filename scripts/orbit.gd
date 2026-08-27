@tool
class_name Orbit
extends Resource

var _ignore_update: bool = false
var _owner_mass: float = 1.0

var _semi_major_axis: float = 0.0:
	set(val):
		_semi_major_axis = maxf(0, val)
		apoapsis = semi_major_axis*(1 + eccentricity)
		periapsis = semi_major_axis*(1 - eccentricity)
var _true_anomaly: float = 0:
	set(val):
		_true_anomaly = wrapf(val, 0, 2*PI)
var _eccentricity: float = 0.0:
	set(val):
		_eccentricity = val
		if is_equal_approx(eccentricity, 0):
			_true_anomaly += _argument_of_periapsis
			_argument_of_periapsis = 0
var _argument_of_periapsis: float = 0:
	set(val):
		if is_equal_approx(eccentricity, 0):
			_argument_of_periapsis = 0
		else:
			_argument_of_periapsis = wrapf(val, -PI, PI)
var _inclination: float = 0.0:
	set(val):
		_inclination = wrapf(val, 0, PI)
		if is_equal_approx(_inclination, 0) or is_equal_approx(abs(_inclination), PI):
			_true_anomaly += _longitude_of_ascending_node
			_longitude_of_ascending_node = 0
var _longitude_of_ascending_node: float = 0.0:
	set(val):
		if is_equal_approx(_inclination, 0) or is_equal_approx(abs(_inclination), PI):
			_longitude_of_ascending_node = 0
		else:
			_longitude_of_ascending_node = wrapf(val, -PI, PI)
var _tidally_locked: bool = false
var _synchronous: bool = false
var _relative_to_barycenter: bool = false
var apoapsis: float = semi_major_axis*(1 + _eccentricity)
var periapsis: float = semi_major_axis*(1 - _eccentricity)

@export_tool_button("Apply Orbit", "Trackball")
var apply_orbit: Callable = emit_changed

@export_node_path("OrbitalBody")
var parent_body: NodePath:
	set(new_parent_body):
		parent_body = new_parent_body
		if !_ignore_update: emit_changed()
	
@export_custom(PROPERTY_HINT_NONE, "suffix:m")
var semi_major_axis: float = 0.0:
	set(val):
		_semi_major_axis = val
		if !_ignore_update: emit_changed()
	get(): 
		return _semi_major_axis

@export_range(0.0, 0.99, 0.01)
var eccentricity: float:
	set(val):
		_eccentricity = clampf(val, 0.0, 1.0)
		apoapsis = semi_major_axis*(1 + eccentricity)
		periapsis = semi_major_axis*(1 - eccentricity)
		if !_ignore_update: emit_changed()
	get(): return _eccentricity

@export_range(0, 180, 0.01, "radians_as_degrees","suffix:°")
var inclination: float:
	set(val):
		_inclination = val
		if !_ignore_update: emit_changed()
	get(): return _inclination

@export_range(-180, 180, 1, "radians_as_degrees","suffix:°")
var argument_of_periapsis: float:
	set(val):
		_argument_of_periapsis = val
		if !_ignore_update: emit_changed()
	get(): return _argument_of_periapsis

@export_range(-180, 180, 1, "radians_as_degrees","suffix:°")
var longitude_of_ascending_node: float:
	set(val):
		_longitude_of_ascending_node = val
		if !_ignore_update: emit_changed()
	get(): return _longitude_of_ascending_node

@export_range(0, 360, 0.01, "radians_as_degrees","suffix:°")
var true_anomaly: float = 0:
	set(val):
		_true_anomaly = val
		if !_ignore_update: emit_changed()
	get(): return _true_anomaly

@export var tidally_locked: bool:
	set(val):
		_tidally_locked = val
		if !_ignore_update: emit_changed()
	get(): return _tidally_locked

@export var synchronous: bool:
	set(val):
		_synchronous = val
		if !_ignore_update: emit_changed()
	get(): return _synchronous

var relative_to_barycenter: bool:
	set(val):
		_relative_to_barycenter = val
		if !_ignore_update: emit_changed()
	get(): return _relative_to_barycenter



func get_orbital_plane_normal() -> Vector3:
	var cos_i = cos(inclination)
	var sin_i = sin(inclination)
	var cos_om = cos(longitude_of_ascending_node)
	var sin_om = sin(longitude_of_ascending_node)
	return Vector3(-cos_om*sin_i, cos_i, sin_om*sin_i)


func get_position(focal_distance_scalar: float = 0) -> Vector3:
	return get_position_at_true_anomaly(true_anomaly, focal_distance_scalar)

func get_position_at_true_anomaly(true_anomaly: float, focal_distance_scalar: float = 0) -> Vector3:
	#print("True anomaly: ", rad_to_deg(true_anomaly))
	focal_distance_scalar = clampf(focal_distance_scalar, 0.0, 1.0)
	#print(focal_distance_scalar)
	if eccentricity >= 1 or is_equal_approx(focal_distance_scalar, 1.0):
		return Vector3(0,0,0)
	var r = (semi_major_axis*(1 - focal_distance_scalar))*(1 - eccentricity*eccentricity)/(1 + eccentricity*cos(true_anomaly)) # Distance
	var x_orbit = r*cos(true_anomaly) # X along orbital plane
	var y_orbit = r*sin(true_anomaly) # Y along orbital plane
	
	var cos_w = cos(argument_of_periapsis)
	var sin_w = sin(argument_of_periapsis)
	var cos_i = cos(inclination)
	var sin_i = sin(inclination)
	var cos_om = cos(longitude_of_ascending_node)
	var sin_om = sin(longitude_of_ascending_node)
	
	var x = x_orbit*(sin_om*cos_w + cos_om*sin_w*cos_i) - y_orbit*(sin_om*sin_w - cos_om*cos_w*cos_i)
	var y = x_orbit*(sin_w*sin_i) + y_orbit*(cos_w*sin_i)
	var z = x_orbit*(cos_om*cos_w - sin_om*sin_w*cos_i) - y_orbit*(cos_om*sin_w + sin_om*cos_w*cos_i)
	return Vector3(x, y, z)

func get_orbital_velocity(gravitational_parameter: float) -> Vector3:
	return get_orbital_velocity_at(true_anomaly, gravitational_parameter)


func get_orbital_velocity_at(true_anomaly: float, gravitational_parameter: float) -> Vector3:
	if eccentricity == 1:
		return Vector3(0,0,0)
	var p = semi_major_axis*(1 - eccentricity*eccentricity)
	var vx_orbit = -sqrt(gravitational_parameter/p)*sin(true_anomaly)
	var vy_orbit = sqrt(gravitational_parameter/p)*(eccentricity + cos(true_anomaly))
	var cos_w = cos(argument_of_periapsis)
	var sin_w = sin(argument_of_periapsis)
	var cos_i = cos(inclination)
	var sin_i = sin(inclination)
	var cos_om = cos(longitude_of_ascending_node)
	var sin_om = sin(longitude_of_ascending_node)
	
	var x = vx_orbit*(sin_om*cos_w + cos_om*sin_w*cos_i) \
		- vy_orbit*(sin_om*sin_w - cos_om*cos_w*cos_i)
	var y = vx_orbit*(sin_w*sin_i) + vy_orbit*(cos_w*sin_i)
	var z = vx_orbit*(cos_om*cos_w - sin_om*sin_w*cos_i) \
		- vy_orbit*(cos_om*sin_w + sin_om*cos_w * cos_i)
	return Vector3(x, y, z)


func get_orbital_path(vertices: int = 360, focal_distance_scalar: float = 0.0, parent_path: bool = false):
	focal_distance_scalar = clampf(focal_distance_scalar, 0.0, 1.0)
	if parent_path:
		focal_distance_scalar = 1 - focal_distance_scalar
	var path: PackedVector3Array = []
	var point_delta = 360/vertices
	var point = 0
	while point < 360:
		var orbital_position = get_position_at_true_anomaly(deg_to_rad(point), focal_distance_scalar)
		if parent_path:
			orbital_position *= -1.0
		path.append(orbital_position)
		point += point_delta
	path.append(path[0])
	return path


func get_orbital_period(gravitational_parameter: float) -> float:
	if parent_body == null:
		return 0.0
	if eccentricity == 1:
		return INF
	#var orbital_velocity = (linear_velocity-parent_body.linear_velocity).length()
	var a3 = pow(semi_major_axis, 3)
	return 2*PI*sqrt(a3/(gravitational_parameter))


func set_orbital_period(orbital_period: float, gravitational_parameter: float) -> void:
	semi_major_axis = get_sma_for_orbital_period(orbital_period, gravitational_parameter)



static func generate_orbit(relative_position: Vector3, relative_velocity: Vector3, gravitational_parameter: float) -> Orbit:
	var new_orbit = Orbit.new()
	var distance = relative_position.length()
	var r = relative_position
	var v = relative_velocity
	var v2 = v.length_squared()
	var mu = gravitational_parameter
	if v.length() >= Orbit.get_escape_velocity_at_distance(distance, mu) or v2 == 0:
		#print(v2, ", ", Orbit.get_escape_velocity_at_distance(distance, mu))
		print("On escape trajectory")
		return null
		
	var h = r.cross(v)
	if h.length_squared() == 0:
		print("No tangential movement")
		return null

	var n = Vector3(0,1,0).cross(h)
	var e = (1/mu)*((v2 - mu/distance)*r - (r.dot(v))*v)
	var energy = v2/2 - mu/distance

	new_orbit.eccentricity = e.length()
	new_orbit.semi_major_axis = -mu/(2*energy)
	new_orbit.inclination = acos(clamp(h.y/h.length(), -1, 1))
	new_orbit.longitude_of_ascending_node = atan2(n.x, n.z)
	#_argument_of_periapsis = atan2(n.cross(e).dot(h.normalized()), n.dot(e))
	#_true_anomaly = atan2(e.cross(r).dot(h.normalized()), e.dot(r))
	if new_orbit.eccentricity <= 0.01:
		new_orbit.argument_of_periapsis = 0.0
		if n.length_squared() > 0:
			new_orbit.true_anomaly = atan2(n.cross(r).dot(h.normalized()), n.dot(r))
	else:
		new_orbit.argument_of_periapsis = atan2(n.cross(e).dot(h.normalized()), n.dot(e))
		new_orbit.true_anomaly = atan2(e.cross(r).dot(h.normalized()), e.dot(r))
	return new_orbit


static func get_barycenter(body1_position: Vector3, body1_mass: float, body2_position: Vector3, body2_mass: float) -> Vector3:
	var r = get_barycenter_distance_scalar(body1_mass, body2_mass)
	var normal = (body1_position - body2_position)
	return normal*r + body2_position

static func get_distance_to_barycenter(body1_relative_position: Vector3, body1_mass: float, body2_mass: float) -> float:
	var distance = body1_relative_position.length()
	if is_zero_approx(distance):
		return 0.0
	var r = distance/(1 + (body1_mass/body2_mass))
	return r
	
static func get_barycenter_distance_scalar(body1_mass: float, body2_mass: float) -> float:
	var r = body1_mass/(body1_mass+body2_mass)
	return r

static func get_sma_for_orbital_period(orbital_period: float, gravitational_parameter: float) -> float:
	var target_a3 = pow(orbital_period/(2*PI), 2)*gravitational_parameter
	var target_a = pow(target_a3, 1.0/3.0) # cube root
	return target_a

static func get_escape_velocity_at_distance(distance: float, gravitational_parameter: float) -> float:
	return sqrt((2*gravitational_parameter)/distance)
