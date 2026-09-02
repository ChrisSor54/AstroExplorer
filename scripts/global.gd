extends Node

var physics_count: int = 0

func _physics_process(delta: float) -> void:
	physics_count += 1

func pretty_vector(vector: Vector3):
	var text = "("
	for i in range(3):
		var val = 0.0
		if i == 0:
			val = vector.x
		elif i == 1:
			val = vector.y
		else:
			val = vector.z
		var val_text = "+" if val >= 0.0 else ""
		val_text += "%.8f"
		text += (val_text % val)
		if i != 2:
			text += ","
	#return "(%.2f, %.2f, %.2f)" % [vector.x, vector.y, vector.z]
	return text + ")"
