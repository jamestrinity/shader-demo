extends DirectionalLight3D

func _ready():
	# Update the shadow direction once when the level loads
	update_shader_sun()

# Uncomment this _process function ONLY if your sun moves/rotates during gameplay!
# func _process(_delta):
#     update_shader_sun()

func update_shader_sun():
	# In Godot 3D, the "forward" direction an object is facing is its negative Z axis
	var forward_direction = -global_transform.basis.z
	
	# Push that direction to the Global Shader Variable we created
	RenderingServer.global_shader_parameter_set("sun_direction", forward_direction)
