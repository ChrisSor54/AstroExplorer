@tool
extends Resource
class_name Orbit

var _ignore_update: bool = false

var _semi_major_axis: float = 0.0:
	set(val):
		_semi_major_axis = val
		apoapsis = semi_major_axis*(1 + eccentricity)
		periapsis = semi_major_axis*(1 - eccentricity)
var _longitude_of_ascending_node: float = 0.0
var _argument_of_apoapsis: float = PI
var _argument_of_periapsis: float = 0
var _true_anomaly: float = 0
var _eccentricity: float = 0.0
var _inclination: float = 0.0
var _tidally_locked: bool = false
var _synchronous: bool = false
var apoapsis: float = semi_major_axis*(1 + _eccentricity)
var periapsis: float = semi_major_axis*(1 - _eccentricity)

@export var update_orbit: bool = false:
	set(val):
		if !_ignore_update: emit_changed()
	get(): return false

@export_node_path("GravBody") var parent_body: NodePath:
	set(new_parent_body):
		parent_body = new_parent_body
		if !_ignore_update: emit_changed()
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var semi_major_axis: float = 0.0:
	set(val):
		_semi_major_axis = max(val, 0.0)
		if !_ignore_update: emit_changed()
	get(): return _semi_major_axis
@export_range(-180, 180, 1, "radians_as_degrees","suffix:°") var longitude_of_ascending_node: float:
	set(val):
		_longitude_of_ascending_node = val
		if !_ignore_update: emit_changed()
	get(): return _longitude_of_ascending_node
var argument_of_apoapsis: float = PI:
	set(val):
		_argument_of_apoapsis = val
		_argument_of_periapsis = -wrapf(-argument_of_apoapsis + PI, -PI, PI)
		if !_ignore_update: emit_changed()
	get(): return _argument_of_apoapsis
@export_range(-180, 180, 1, "radians_as_degrees","suffix:°") var argument_of_periapsis: float:
	set(val):
		_argument_of_periapsis = val
		_argument_of_apoapsis = -wrapf(-argument_of_periapsis - PI, -PI, PI)
		if !_ignore_update: emit_changed()
	get(): return _argument_of_periapsis
@export_range(0, 360, 0.01, "radians_as_degrees","suffix:°") var true_anomaly: float = 0:
	set(val):
		_true_anomaly = val
		if !_ignore_update: emit_changed()
	get(): return _true_anomaly
@export_range(0.0, 0.99, 0.01) var eccentricity: float:
	set(val):
		_eccentricity = clampf(val, 0.0, 1.0)
		apoapsis = semi_major_axis*(1 + eccentricity)
		periapsis = semi_major_axis*(1 - eccentricity)
		if !_ignore_update: emit_changed()
	get(): return _eccentricity
@export_range(-180, 180, 0.01, "radians_as_degrees","suffix:°") var inclination: float:
	set(val):
		_inclination = val
		if !_ignore_update: emit_changed()
	get(): return _inclination
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



func get_orbital_plane_normal() -> Vector3:
	var cos_i = cos(inclination)
	var sin_i = sin(inclination)
	var cos_om = cos(longitude_of_ascending_node)
	var sin_om = sin(longitude_of_ascending_node)
	return Vector3(-cos_om*sin_i, cos_i, sin_om*sin_i)


func get_position() -> Vector3:
	return get_position_at_true_anomaly(true_anomaly)

func get_position_at_true_anomaly(true_anomaly: float) -> Vector3:
	if eccentricity >= 1:
		return Vector3(0,0,0)
	var r = semi_major_axis*(1 - eccentricity*eccentricity)/(1 + eccentricity*cos(true_anomaly))
	var x_orbit = r*cos(true_anomaly)
	var y_orbit = -r*sin(true_anomaly)
	
	var cos_w = cos(argument_of_periapsis)
	var sin_w = -sin(argument_of_periapsis)
	var cos_i = cos(inclination)
	var sin_i = -sin(inclination)
	var cos_om = cos(longitude_of_ascending_node)
	var sin_om = -sin(longitude_of_ascending_node)
	
	var x = x_orbit*(sin_om*cos_w + cos_om*sin_w*cos_i) \
		- y_orbit*(sin_om*sin_w - cos_om*cos_w*cos_i)
	var y = x_orbit*(sin_w*sin_i) + y_orbit*(cos_w*sin_i)
	var z = -(x_orbit*(cos_om*cos_w - sin_om*sin_w*cos_i) \
		- y_orbit*(cos_om*sin_w + sin_om*cos_w*cos_i))
	return Vector3(x, y, z)

func get_orbital_velocity(gravitational_parameter: float) -> Vector3:
	return get_orbital_velocity_at(true_anomaly, gravitational_parameter)

func get_orbital_velocity_at(true_anomaly: float, gravitational_parameter: float) -> Vector3:
	if eccentricity == 1:
		return Vector3(0,0,0)
	var p = semi_major_axis*(1 - eccentricity*eccentricity)
	var vx_orbit = sqrt(gravitational_parameter/p)*sin(true_anomaly)
	var vy_orbit = -sqrt(gravitational_parameter/p)*(eccentricity + cos(true_anomaly))
	var argument_of_periapsis = wrapf(argument_of_apoapsis - PI, -PI, PI)
	var cos_w = cos(argument_of_periapsis)
	var sin_w = -sin(argument_of_periapsis)
	var cos_i = cos(inclination)
	var sin_i = -sin(inclination)
	var cos_om = cos(longitude_of_ascending_node)
	var sin_om = sin(longitude_of_ascending_node)
	
	var x = -(vx_orbit*(sin_om*cos_w + cos_om*sin_w*cos_i)) \
		- vy_orbit*(sin_om*sin_w - cos_om*cos_w*cos_i)
	var y = vx_orbit*(sin_w*sin_i) + vy_orbit*(cos_w*sin_i)
	var z = vx_orbit*(cos_om*cos_w - sin_om*sin_w*cos_i) \
		- vy_orbit*(cos_om*sin_w + sin_om*cos_w * cos_i)
	return Vector3(x, y, z)

func get_orbital_path(vertices: int = 360):
	var path: PackedVector3Array = []
	var point_delta = 360/vertices
	var point = 0
	while point < 360:
		var orbital_position = get_position_at_true_anomaly(deg_to_rad(point))
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

func get_sma_for_orbital_period(orbital_period: float, gravitational_parameter: float) -> float:
	var target_a3 = pow(orbital_period/(2*PI), 2)*gravitational_parameter
	var target_a = pow(target_a3, 1.0/3.0) # cube root
	return target_a

func get_escape_velocity_at_distance(distance: float, gravitational_parameter: float) -> float:
	return sqrt((2*gravitational_parameter)/distance)
