# Wraps an atmosphere rendering shader.
# When the camera is far, it uses a cube bounding the planet.
# When the camera is close, it uses a fullscreen quad (does not work in editor).
# Common parameters are exposed as properties.

@tool
extends Node3D

const MODE_NEAR = 0
const MODE_FAR = 1
const SWITCH_MARGIN_RATIO = 1.1

const AtmosphereShader = preload("./shaders/planet_atmosphere_no_clouds.gdshader")
const DefaultShader = AtmosphereShader
const BlueNoiseTexture = preload("./blue_noise.png")
const CloudShadowShader = preload("./shaders/clouds_shadow.gdshader")

const OpticalDepthBaker = preload("./optical_depth_baker.gd")


var _planet_radius := 1.0
@export var planet_radius: float:
	get:
		return _planet_radius
	set(value):
		set_planet_radius(value)


var _atmosphere_height := 0.1
@export var atmosphere_height : float:
	get:
		return _atmosphere_height
	set(value):
		set_atmosphere_height(value)


var _sun_path : NodePath
@export var sun_path : NodePath:
	get:
		return _sun_path
	set(value):
		set_sun_path(value)


var _custom_shader : Shader
@export var custom_shader : Shader:
	get:
		return _custom_shader
	set(value):
		set_custom_shader(value)

# In degrees per second
@export var clouds_rotation_speed : float = 1.0

@export var force_fullscreen := false

@export var clouds_shadow_enabled : bool = false
@export var clouds_shadow_cutoff_bias : float = 0.0

var _far_mesh : BoxMesh
var _near_mesh : QuadMesh
var _mode := MODE_FAR
var _mesh_instance : MeshInstance3D
var _prev_atmo_clip_distance : float = 0.0
var _uses_baked_optical_depth := false

var _optical_depth_baker : OpticalDepthBaker
var _optical_depth_texture : Texture2D

var _cloud_shadow_mesh_instance : MeshInstance3D

# These parameters are assigned internally,
# they don't need to be shown in the list of shader params
const _api_shader_params = {
	"u_planet_radius": true,
	"u_atmosphere_height": true,
	"u_clip_mode": true,
	"u_sun_position": true,
	"u_world_to_model_matrix": true,
	"u_blue_noise_texture": true,
	"u_cloud_coverage_rotation": true,
	"u_optical_depth_texture": true
}

const _shader_params_affecting_optical_depth = {
	"u_density": true
}


func _init() -> void:
	var material := ShaderMaterial.new()
	material.shader = AtmosphereShader
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.material_override = material
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh_instance)

	_near_mesh = QuadMesh.new()
	_near_mesh.orientation = PlaneMesh.FACE_Z
	_near_mesh.size = Vector2(2.0, 2.0)
	_near_mesh.flip_faces = true
	
	#_far_mesh = _create_far_mesh()
	_far_mesh = BoxMesh.new()
	_far_mesh.size = Vector3(1.0, 1.0, 1.0)

	_mesh_instance.mesh = _far_mesh
	
	_update_cull_margin()

	# Setup defaults for the builtin shader
	material.set_shader_parameter(&"u_sun_position", Vector3(5000, 0, 0))
	material.set_shader_parameter(&"u_blue_noise_texture", BlueNoiseTexture)
	material.set_shader_parameter(&"u_clip_mode", 0.0)


func _ready() -> void:
	var mat := _get_material()
	# Must assign those in _ready because they are set by the scene loader, after _init
	mat.set_shader_parameter(&"u_planet_radius", _planet_radius)
	mat.set_shader_parameter(&"u_atmosphere_height", _atmosphere_height)


func set_custom_shader(shader: Shader) -> void:
	_custom_shader = shader
	
	var mat := _get_material()
	if _custom_shader == null:
		mat.shader = DefaultShader
	else:
		var previous_shader = mat.shader
		mat.shader = shader
		if Engine.is_editor_hint():
			# Fork built-in shader
			if shader.code == "" and previous_shader == DefaultShader:
				shader.code = DefaultShader.code
	
	var uniforms := _custom_shader.get_shader_uniform_list()
	for uniform in uniforms:
		if uniform.name == "u_optical_depth_texture":
			_uses_baked_optical_depth = true
			break
	
	if _uses_baked_optical_depth:
		_request_bake_optical_depth()

	notify_property_list_changed()


func _request_bake_optical_depth() -> void:
	var mat := _get_material()
	if _optical_depth_baker == null:
		_optical_depth_baker = OpticalDepthBaker.new()
		add_child(_optical_depth_baker)
		_optical_depth_baker.baked.connect(_on_optical_depth_baked)
	_optical_depth_baker.request_bake(mat)


func _on_optical_depth_baked(tex: Texture2D) -> void:
	_optical_depth_texture = tex
	var mat := _get_material()
	mat.set_shader_parameter(&"u_optical_depth_texture", tex)


func _get_material() -> ShaderMaterial:
	return _mesh_instance.material_override as ShaderMaterial


# TODO Obsolete
func set_shader_param(param_name: String, value: Variant) -> void:
	push_warning("set_shader_param is deprecated, use set_shader_parameter")
	set_shader_parameter(param_name, value)


# TODO Obsolete
func get_shader_param(param_name: String):
	push_warning("get_shader_param is deprecated, use get_shader_parameter")
	return get_shader_parameter(param_name)


func set_shader_parameter(param_name: StringName, value: Variant) -> void:
	_get_material().set_shader_parameter(param_name, value)


func get_shader_parameter(param_name: StringName):
	return _get_material().get_shader_parameter(param_name)


# Shader parameters are exposed like this so we can have more custom shaders in the future,
# without forcing to change the node/script entirely
func _get_property_list() -> Array:
	var props := []
	var mat := _get_material()
	var shader_params := RenderingServer.get_shader_parameter_list(mat.shader.get_rid())
	for p in shader_params:
		if _api_shader_params.has(p.name):
			continue
		var cp := {}
		for k in p:
			cp[k] = p[k]
		cp.name = str("shader_params/", p.name)
		props.append(cp)
	return props


func _get(p_key: StringName) -> Variant:
	var key = String(p_key)
	if key.begins_with("shader_params/"):
		var param_name := key.substr(len("shader_params/"))
		var mat := _get_material()
		var value = mat.get_shader_parameter(param_name)
		if value == null:
			value = RenderingServer.shader_get_parameter_default(mat.shader, param_name)
		return value
	return null


func _set(p_key: StringName, value: Variant) -> bool:
	var key = String(p_key)
	if key.begins_with("shader_params/"):
		var param_name := key.substr(len("shader_params/"))
		var mat := _get_material()
		mat.set_shader_parameter(param_name, value)
		if _uses_baked_optical_depth and _shader_params_affecting_optical_depth.has(param_name):
			_request_bake_optical_depth()
		return true
	return false


func _get_configuration_warnings() -> PackedStringArray:
	if _sun_path == null or _sun_path.is_empty():
		return PackedStringArray(["The path to the sun is not assigned."])
	var light = get_node(_sun_path)
	if not (light is Node3D):
		return PackedStringArray(["The assigned sun node is not a Node3D."])
	return PackedStringArray()


func set_planet_radius(new_radius: float) -> void:
	if _planet_radius == new_radius:
		return
	_planet_radius = maxf(new_radius, 0.0)
	var sm : ShaderMaterial = _mesh_instance.material_override
	sm.set_shader_parameter(&"u_planet_radius", _planet_radius)
	_update_cull_margin()
	if _uses_baked_optical_depth:
		_request_bake_optical_depth()


func _update_cull_margin() -> void:
	_mesh_instance.extra_cull_margin = _planet_radius + _atmosphere_height


func set_atmosphere_height(new_height: float) -> void:
	if _atmosphere_height == new_height:
		return
	_atmosphere_height = maxf(new_height, 0.0)
	var sm : ShaderMaterial = _mesh_instance.material_override
	sm.set_shader_parameter(&"u_atmosphere_height", _atmosphere_height)
	_update_cull_margin()
	if _uses_baked_optical_depth:
		_request_bake_optical_depth()


func set_sun_path(new_sun_path: NodePath) -> void:
	_sun_path = new_sun_path
	update_configuration_warnings()


func _set_mode(mode: int) -> void:
	if mode == _mode:
		return
	_mode = mode

	var mat := _get_material()

	if _mode == MODE_NEAR:
		if OS.is_stdout_verbose():
			print("Switching ", name, " to near mode")
		# If camera is close enough, switch shader to near clip mode
		# otherwise it will pass through the quad
		mat.set_shader_parameter("u_clip_mode", 1.0)
		_mesh_instance.mesh = _near_mesh
		_mesh_instance.transform = Transform3D()
		# TODO Sometimes there is a short flicker, figure out why

	else:
		if OS.is_stdout_verbose():
			print("Switching ", name, " to far mode")
		mat.set_shader_parameter(&"u_clip_mode", 0.0)
		_mesh_instance.mesh = _far_mesh


func _process(_delta) -> void:
	var cam_pos := Vector3()
	var cam_near := 0.1
	
	var cam := get_viewport().get_camera_3d()

	if cam != null:
		cam_pos = cam.global_transform.origin
		cam_near = cam.near
		
	elif Engine.is_editor_hint():
		# Getting the camera in editor is freaking awkward so let's hardcode it...
		cam_pos = global_transform.origin \
			+ Vector3(10.0 * (_planet_radius + _atmosphere_height + cam_near), 0, 0)

	# 1.75 is an approximation of sqrt(3), because the far mesh is a cube and we have to take
	# the largest distance from the center into account
	var atmo_clip_distance : float = \
		1.75 * (_planet_radius + _atmosphere_height + cam_near) * SWITCH_MARGIN_RATIO
	
	# Detect when to switch modes.
	# we always switch modes while already being slightly away from the quad, to avoid flickering
	var d := global_transform.origin.distance_to(cam_pos)
	var is_near := d < atmo_clip_distance
	if is_near or force_fullscreen:
		_set_mode(MODE_NEAR)
	else:
		_set_mode(MODE_FAR)

	if _mode == MODE_FAR:
		if _prev_atmo_clip_distance != atmo_clip_distance:
			_prev_atmo_clip_distance = atmo_clip_distance
			# The mesh instance should not be scaled, so we resize the cube instead
			var cm := BoxMesh.new()
			cm.size = Vector3(atmo_clip_distance, atmo_clip_distance, atmo_clip_distance)
			_mesh_instance.mesh = cm
			_far_mesh = cm
	
	var mat := _get_material()
	
	# Lazily avoiding the node referencing can of worms.
	# Not very efficient but I assume there won't be many atmospheres in the game.
	# In Godot 4 it could be replaced by caching the object ID in some way
	if has_node(_sun_path):
		var sun = get_node(_sun_path)
		if sun is Node3D:
			mat.set_shader_parameter(&"u_sun_position", sun.global_transform.origin)
	
	# We need this for mapping stuff around the planet.
	# TODO Ideally we need view_to_model, which is better to avoid conversions with large numbers.
	var world_to_model_matrix := global_transform.inverse()
	mat.set_shader_parameter(&"u_world_to_model_matrix", world_to_model_matrix)
	
	var cov_rot := _get_cloud_coverage_rotation_2d()
	mat.set_shader_parameter(&"u_cloud_coverage_rotation", cov_rot)
	
	_process_cloud_shadow()


func _get_cloud_coverage_rotation_angle() -> float:
	var time := float(Time.get_ticks_msec()) / 1000.0
	return time * deg_to_rad(clouds_rotation_speed)


func _get_cloud_coverage_rotation_2d() -> Transform2D:
	var a := _get_cloud_coverage_rotation_angle()
	return Transform2D().rotated(a)


func _process_cloud_shadow() -> void:
	var use_cloud_shadow := false
	
	if clouds_shadow_enabled:
		var mat := _get_material()
		var coverage_cubemap : Cubemap = mat.get_shader_parameter(&"u_cloud_coverage_cubemap")
		
		if coverage_cubemap != null:
			use_cloud_shadow = true
			var mi : MeshInstance3D = _cloud_shadow_mesh_instance
			var sphere : SphereMesh
			
			if mi != null:
				sphere = mi.mesh
			else:
				sphere = SphereMesh.new()
				
				var new_shadow_mat := ShaderMaterial.new()
				new_shadow_mat.shader = CloudShadowShader
				
				mi = MeshInstance3D.new()
				mi.mesh = sphere
				mi.material_override = new_shadow_mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
				add_child(mi)
				_cloud_shadow_mesh_instance = mi
			
			var cloud_top : float = mat.get_shader_parameter(&"u_cloud_top");
			var cloud_bottom : float = mat.get_shader_parameter(&"u_cloud_bottom");
			var cast_radius := (cloud_top + cloud_bottom) * 0.5 * atmosphere_height + _planet_radius
			
			if not is_equal_approx(sphere.radius, cast_radius):
				sphere.radius = cast_radius
				sphere.height = sphere.radius * 2.0
			
			var shadow_mat : ShaderMaterial = mi.material_override
			
			shadow_mat.set_shader_parameter(&"u_cloud_coverage_cubemap", coverage_cubemap)
			
			var cov_rot := _get_cloud_coverage_rotation_2d()
			shadow_mat.set_shader_parameter(&"u_cloud_coverage_rotation", cov_rot)
			
			var sc_bias : float = mat.get_shader_parameter(&"u_cloud_coverage_bias")
			shadow_mat.set_shader_parameter(&"u_bias", clouds_shadow_cutoff_bias - sc_bias)
	
	if not use_cloud_shadow:
		if _cloud_shadow_mesh_instance != null:
			_cloud_shadow_mesh_instance.queue_free()
			_cloud_shadow_mesh_instance = null


#static func _make_quad_mesh() -> Mesh:
#	#  2---3
#	#  | x |
#	#  0---1
#	var vertices = [
#		Vector3(-1, -1, 0),
#		Vector3(1, -1, 0),
#		Vector3(-1, 1, 0),
#		Vector3(1, 1, 0)
#	]
#	var indices = [
#		0, 2, 1,
#		1, 2, 3
#	]
#	var arrays = []
#	arrays.resize(Mesh.ARRAY_MAX)
#	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array(vertices)
#	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array(indices)
#	var mesh = ArrayMesh.new()
#	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
#	return mesh
