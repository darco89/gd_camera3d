extends Node

class_name CameraMainMap

# Camera3D that will be controlled
@onready var camera : Camera3D = $Camera3D

var l : Logger
var mov_speed = Settings.Camera_move_speed
var speed_modifier = Settings.Camera_speed_modifier
var zoom_speed = Settings.Camera_zoom_speed
var camera_max_fov = Settings.Camera_max_fov
var camera_min_fov = Settings.Camera_min_fov
var camera_min_x_axis_pos = Settings.Camera_min_x_axis_pos
var camera_max_x_axis_pos = Settings.Camera_max_x_axis_pos
var camera_min_z_axis_pos = Settings.Camera_min_z_axis_pos
var camera_max_z_axis_pos = Settings.Camera_max_z_axis_pos

# Camera faces and dictates Direction of Controls ● UP = Vector3(0, 1, 0)
const camera_main_axis = Vector3.UP
# current camera rotation angle on Y axis (in radians) 
var camera_rotation_angle = 0
# camera will move according to this vector values
var direction = Vector3.ZERO

# Variables for camera rotation
var is_rotating: bool = false
var rotation_speed: float = 0.2  # Adjust this for smoother/slower rotation

# Control binds pressed to move or stop
var movementKeys : Array[Key] = [KEY_W, KEY_S, KEY_A, KEY_D]
var keysPressed : Array = []

func _ready() -> void:
	# setup
	l = LogControl.new(log_name, log_level)
	camera_rotation_angle = $Camera3D.rotation.y 

## MOVE CAMERA whenever direction is != 0
func _process(delta: float):
	if camera and direction != Vector3.ZERO:
		move_camera(delta)

# Normalize direction and move the camera
func move_camera(delta : float)  -> void:
	var velocity = direction.normalized() * mov_speed * delta
	camera.global_position += velocity * speed_modifier
	l.debug("Global position: %s", [camera.global_position])
	restrict_camera_position()

func _input(event: InputEvent) -> void:
	## handle mouse wheel
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			handle_zoom(false)
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			handle_zoom(true)
	## handle mouse movement 
	if event is InputEventMouseMotion and is_rotating:
		handle_camera_rotation(event.relative)
	## handle keys for movement
	if event is InputEventKey:
		# Z enables camera rotation with mouse
		detect_rotation_control(event)
		# WASD movement according to camera orientation
		if movementKeys.filter(func(m): return m == event.keycode).size() > 0:
			treat_movement_key(event)

# applies the correct direction considering camera rotation
func apply_direction_force(straight_vector : Vector3, release : bool):
	var rotatedAxis = straight_vector.rotated(Vector3.UP, $Camera3D.rotation.y)
	if release:
		direction -= rotatedAxis * direction.dot(rotatedAxis)
	else:
		direction += rotatedAxis
	return direction

# Handle camera movement input (WASD)
func handle_movement(event: InputEvent, released = false):
	# Handle movement keys
	if event.keycode == KEY_W:
		# "STRAIGHT" UP "FORCE"
		direction = apply_direction_force(Vector3(0, 0, -1), released)
		
		var rotatedZAxis = Vector3(0, 0, -1).rotated(Vector3.UP, $Camera3D.rotation.y)
		if not released:
			direction += rotatedZAxis
		else:
			direction -= rotatedZAxis * direction.dot(rotatedZAxis)
	elif event.keycode == KEY_S:
		# "STRAIGHT" DOWN "FORCE"
		var rotatedZAxis = Vector3(0, 0, 1).rotated(Vector3.UP, $Camera3D.rotation.y)
		if not released:
			direction += rotatedZAxis
		else:
			direction -= rotatedZAxis * direction.dot(rotatedZAxis)
	elif event.keycode == KEY_A:
		# "STRAIGHT" LEFT "FORCE"
		var rotatedXAxis = Vector3(-1, 0, 0).rotated(Vector3.UP, $Camera3D.rotation.y)
		if not released:
			direction += rotatedXAxis
		else:
			direction -= rotatedXAxis * direction.dot(rotatedXAxis)
	elif event.keycode == KEY_D:
		# "STRAIGHT" RIGHT 'FORCE'
		var right_vector = Vector3(1, 0, 0)
		# "ROTATED" RIGHT - ACCORDING TO CAMERA ORIENTATION
		var rotatedXAxis = right_vector.rotated(Vector3.UP, $Camera3D.rotation.y)
		if not released:
			# APPLY ROTATED 'RIGHT FORCE'
			direction += rotatedXAxis
		else:
			# Keep other axis values, but remove the 'RIGHT FORCE'
			direction -= rotatedXAxis * direction.dot(rotatedXAxis)

## Track the movement keys (keysPressed)
func treat_movement_key(event : InputEventKey):
	var idx = keysPressed.find(event.keycode)
	if event.is_pressed():
		# Track key pressed if it was not already
		if idx == -1:
			keysPressed.append(event.keycode)
		# Start movement
		handle_movement(event)
	elif event.is_released():
		# Stop movement in the released Key's Axis
		handle_movement(event, true)
		# Stop tracking released key 
		l.debug("keys released: %s ", [str(event.keycode)] )
		keysPressed.remove_at(idx)
	# For safety. Completely stop if all keys are released (stop direction)
	if keysPressed.size() == 0:
		direction = Vector3.ZERO

## sets is_rotating
func detect_rotation_control(event : InputEventKey):
	# Start rotation when Z is pressed
	if event.keycode == KEY_Z and event.pressed:
		is_rotating = true
	# Stop rotation when Z is released
	elif event.keycode == KEY_Z and event.is_released():
		is_rotating = false
	l.debug("camera is rotating: %s", [is_rotating])

## Handle zoom in and out with mouse wheel
func handle_zoom(zoomin: bool) -> void:
	var delta_zoom = zoom_speed * (1 if zoomin else -1)
	var newVal = camera.fov + delta_zoom
	# Clamp FOV between min and max values
	if newVal < camera_min_fov or newVal > camera_max_fov:
		l.debug("Zoom out of bounds. FOV should be between %s and %s", [camera_min_fov, camera_max_fov])
	else:
		camera.fov += delta_zoom
		l.debug( "zoomed in " if zoomin else "zoomed out")
		l.debug("camera fov %s", [camera.fov])

## Restrict camera's movement within set boundaries
func restrict_camera_position() -> void:
	var camera_position = camera.position
	# Clamp X and Z positions within set boundaries
	camera_position.x = clamp(camera_position.x, camera_min_x_axis_pos, camera_max_x_axis_pos)
	camera_position.z = clamp(camera_position.z, camera_min_z_axis_pos, camera_max_z_axis_pos)
	# Apply restricted position to the camera
	camera.position = camera_position
	l.debug("Camera clamped global position: %s", [camera.global_position])

## Function to handle camera strafing rotation
func handle_camera_rotation(mouse_delta: Vector2) -> void:
	if camera:
		# Horizontal rotation (left/right)
		var yaw_change = -mouse_delta.x * rotation_speed
		camera.rotate_y(deg_to_rad(yaw_change))
		# Vertical rotation (up/down)
		var pitch_change = -mouse_delta.y * rotation_speed
		var new_pitch = clamp(camera.rotation_degrees.x + pitch_change, -80, 80) # Prevent over-tilting
		camera.rotation_degrees.x = new_pitch
		l.debug("Camera rotated: yaw %s, pitch %s", [camera.rotation_degrees.y, camera.rotation_degrees.x])
