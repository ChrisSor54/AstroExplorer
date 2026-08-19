extends Node3D
class_name StarSystem

@export var player: Player

var bodies: Array[GravBody]


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for node in get_children():
		if node is GravBody:
			bodies.append(node)
			node.init()
	if player:
		pass
		player.teleport_to_body($Planet)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _physics_process(delta: float) -> void:
	player.parent_body = null
	player.parent_gravity = Vector3.ZERO
	for body1 in bodies:
		if body1.process_mode == ProcessMode.PROCESS_MODE_DISABLED: continue
		for body2 in bodies:
			if body2.process_mode == ProcessMode.PROCESS_MODE_DISABLED: continue
			if body1 == body2: continue
			var grav_vector = body2.get_gravity_vector_between(body1)
			body1.apply_force(grav_vector)
		if player:
			var grav_vector = body1.get_gravity_vector_from(player.global_position, player.mass)
			print(body1.name, ": ", grav_vector.length()/player.mass)
			if grav_vector.length_squared() > player.parent_gravity.length_squared():
				player.parent_body = body1
				player.parent_gravity = grav_vector
				#print((grav_vector/player.mass).length())
			player.apply_central_force(grav_vector)
