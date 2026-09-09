class_name ProxyBody
extends Node

var position: Vector3 = Vector3.ZERO
var velocity: Vector3 = Vector3.ZERO
var mass: float = 0.0

var _acceleration: Vector3 = Vector3.ZERO


func update(delta: float):
	velocity += _acceleration*delta
	_acceleration = Vector3.ZERO
	position += velocity*delta


func apply_gravity(other_body: ProxyBody, G: float = 1.0):
	var normal = other_body.position - position
	var sqr_distance = normal.length_squared()
	_acceleration += normal.normalized()*((G*other_body.mass)/sqr_distance)
