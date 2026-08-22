@tool
extends Resource
class_name Orbit

var semi_major_axis: float = 0.0
var periapsis: float = 0.0
var _argument_of_apoapsis: float = 0
var _argument_of_periapsis: float = PI

@export_node_path("GravBody") var parent_body: NodePath:
	set(new_parent_body):
		parent_body = new_parent_body
		emit_changed()
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var apoapsis: float = 0.0:
	set(val):
		apoapsis = val
		semi_major_axis = apoapsis/(1 + eccentricity)
		periapsis = semi_major_axis*(1 - eccentricity)
		emit_changed()
@export_range(-180, 180, 1, "radians_as_degrees","suffix:°") var longitude_of_ascending_node: float:
	set(val):
		longitude_of_ascending_node = val
		emit_changed()
@export_range(-180, 180, 1, "radians_as_degrees","suffix:°") var argument_of_apoapsis: float = 0.0:
	set(val):
		_argument_of_apoapsis = val
		_argument_of_periapsis = wrapf(argument_of_apoapsis + PI, -PI, PI)
		emit_changed()
	get(): return _argument_of_apoapsis
@export_range(-180, 180, 1, "radians_as_degrees","suffix:°") var argument_of_periapsis: float = PI:
	set(val):
		_argument_of_periapsis = val
		_argument_of_apoapsis = wrapf(argument_of_periapsis - PI, -PI, PI)
		emit_changed()
	get(): return _argument_of_periapsis
@export_range(0, 360, 0.01, "radians_as_degrees","suffix:°") var true_anomaly: float = PI:
	set(val):
		true_anomaly = val
		emit_changed()
@export var tidally_locked: bool = false:
	set(val):
		tidally_locked = val
		emit_changed()
@export_range(0.0, 1.0, 0.01) var eccentricity: float = 0.0:
	set(val):
		eccentricity = clampf(val, 0.0, 1.0)
		semi_major_axis = apoapsis/(1 + eccentricity)
		periapsis = semi_major_axis*(1 - eccentricity)
		emit_changed()
@export_range(-180, 180, 0.01, "radians_as_degrees","suffix:°") var inclination: float = 0.0:
	set(val):
		inclination = val
		emit_changed()

func get_orbital_plane_normal() -> Vector3:
	var cos_i = cos(inclination)
	var sin_i = sin(inclination)
	var cos_om = cos(longitude_of_ascending_node)
	var sin_om = sin(longitude_of_ascending_node)
	return Vector3(-cos_om * sin_i, cos_i, sin_om * sin_i)


func get_position() -> Vector3:
	return get_position_at_true_anomaly(true_anomaly)

func get_position_at_true_anomaly(true_anomaly: float) -> Vector3:
	var r = semi_major_axis * (1 - eccentricity * eccentricity) / (1 + eccentricity * cos(true_anomaly))
	var x_orbit = r * cos(true_anomaly)
	var y_orbit = -r * sin(true_anomaly)
	
	var cos_w = cos(argument_of_periapsis)
	var sin_w = sin(argument_of_periapsis)
	var cos_i = cos(inclination)
	var sin_i = sin(inclination)
	var cos_om = cos(longitude_of_ascending_node)
	var sin_om = sin(longitude_of_ascending_node)
	
	var x = x_orbit * (sin_om * cos_w + cos_om * sin_w * cos_i) \
		- y_orbit * (sin_om * sin_w - cos_om * cos_w * cos_i)
	var y = x_orbit * (sin_w * sin_i) + y_orbit * (cos_w * sin_i)
	var z = -(x_orbit * (cos_om * cos_w - sin_om * sin_w * cos_i) \
		- y_orbit * (cos_om * sin_w + sin_om * cos_w * cos_i))
	return Vector3(x, y, z)

func get_orbital_velocity(gravitational_parameter: float) -> Vector3:
	return get_orbital_velocity_at(true_anomaly, gravitational_parameter)

func get_orbital_velocity_at(true_anomaly: float, gravitational_parameter: float) -> Vector3:
	var p = semi_major_axis * (1 - eccentricity * eccentricity)
	var vx_orbit = sqrt(gravitational_parameter / p) * sin(true_anomaly)
	var vy_orbit = -sqrt(gravitational_parameter / p) * (eccentricity + cos(true_anomaly))
	var argument_of_periapsis = wrapf(argument_of_apoapsis - PI, -PI, PI)
	var cos_w = cos(argument_of_periapsis)
	var sin_w = sin(argument_of_periapsis)
	var cos_i = cos(inclination)
	var sin_i = sin(inclination)
	var cos_om = cos(longitude_of_ascending_node)
	var sin_om = sin(longitude_of_ascending_node)
	
	var x = (vx_orbit * (sin_om * cos_w + cos_om * sin_w * cos_i)) \
		- vy_orbit * (sin_om * sin_w - cos_om * cos_w * cos_i)
	var y = vx_orbit * (sin_w * sin_i) + vy_orbit * (cos_w * sin_i)
	var z = vx_orbit * (cos_om * cos_w - sin_om * sin_w * cos_i) \
		- vy_orbit * (cos_om * sin_w + sin_om * cos_w * cos_i)
	return Vector3(x, y, z)
