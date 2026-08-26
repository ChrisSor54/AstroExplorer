extends RigidBody3D
class_name AstroRigidBody

var parent_body: AstroBody = null
var parent_gravity: Vector3 = Vector3.ZERO
var _current_gravity: Vector3 = Vector3.ZERO
var _current_strongest_gravity: Vector3 = Vector3.ZERO
#var _ground: PhysicsBody3D = null
#var _is_stuck_to_surface: bool = false
#var _surface_position: Vector3 = Vector3.ZERO



signal integrating_forces(emitter: PhysicsBody3D, state: PhysicsDirectBodyState3D)

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
	
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	integrating_forces.emit(self, state)


func apply_gravitational_force(source_body: PhysicsBody3D, gravity_vector: Vector3):
	apply_central_force(gravity_vector)
	_current_gravity += gravity_vector
	var distance = global_position.distance_to(source_body.global_position)
	if (distance <= (source_body.radius/2) and parent_gravity == Vector3.ZERO) \
	or (distance <= 2*source_body.radius and gravity_vector.length_squared() >= _current_strongest_gravity.length_squared()):
		
		_current_strongest_gravity = gravity_vector
		parent_gravity = gravity_vector
		parent_body = source_body


## Called by the StarSystem at the start of each physics frame.
## Resets appropriate values
func _on_new_frame():
	parent_body = null
	parent_gravity = Vector3.ZERO
	_current_strongest_gravity = Vector3.ZERO
	_current_gravity = get_gravity()
