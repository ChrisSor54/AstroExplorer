extends CanvasLayer
class_name PlayerHUD

@onready var player: Player = get_parent()

@export var control: Control
@export var gravity_label: Label
@export var debug_label: Label
@export var debug_label2: Label



# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var up_vector = player.global_transform.basis.y.normalized()
	gravity_label.text = str(player._current_gravity.project(-up_vector).length()/player.mass).pad_decimals(2)
	
	var status_text = ""
	var velocity_text = "(0.00,0.00,0.00)"
	var speed_text = "0.00"
	if player._is_stuck_to_surface:
		status_text = "Stuck to surface"
	else:
		if player.is_grounded:
			status_text = "Not stuck"
			var surface_velocity = player._ground.linear_velocity
			if player._ground is AstroBody:
				surface_velocity += player._ground.get_surface_velocity_from(player.ground_raycast.get_collision_point())
			var relative_velocity = player.linear_velocity - surface_velocity
			velocity_text = Global.pretty_vector(relative_velocity)
			speed_text = str("%.2f" % relative_velocity.length())
			#debug_label.text = "Not stuck\n" + str(trunc_rvel) + "\n" + )
		else:
			status_text = "Not grounded"
	debug_label.text = status_text + "\n" + velocity_text + "\n" + speed_text
	var pos = player.global_position
	var vel = player.linear_velocity
	var trunc_position = Global.pretty_vector(pos)
	var trunc_velocity = Global.pretty_vector(vel)
	debug_label2.text = str("Position: " + trunc_position) + "\nVelocity: " + str(trunc_velocity)
			
