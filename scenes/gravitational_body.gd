extends StaticBody3D
class_name GBody

const G: float = 1.0

@export var mass: float = 1.0
@export var acceleration: Vector3 = Vector3.ZERO

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	update_velocity()
	global_position += constant_linear_velocity*delta

func update_velocity():
	constant_linear_velocity += acceleration
	acceleration = Vector3.ZERO


func get_gravity_vector_from(global_position: Vector3):
	var normal = self.global_position - global_position
	var normalDir = normal.normalized()
	#print(normal.length())
	return normalDir * (G*mass/normal.length_squared())
	
	
