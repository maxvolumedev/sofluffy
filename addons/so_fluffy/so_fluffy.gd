@tool
extends Node

## Show fur in editor. Fur rendering is relatively expensive, so it is recommened to disable this when not needed.
@export
var preview_in_editor: bool = true:
	set(v):
		var previous_value = preview_in_editor
		preview_in_editor = v		
		if Engine.is_editor_hint():
			clear_materials()
			if preview_in_editor:
				create_materials()
				setup_materials()
				init_physics()

@export_group("Targeting")

## Indices of surfaces to apply fur to. If empty, fur is applied to the entire mesh as a single overlay Material. Otherwise, fur is applied only to the specified surfaces.
@export var target_surfaces : Array[int] = []:
	set(v):
		clear_materials()
		target_surfaces = v		
		create_materials()
		setup_materials()

@export_group("Shells and LOD")

## Number of shells to generate. Higher numbers look better, but incur larger performance penalties.
@export
var number_of_shells: int = 64:
	set(v):
		number_of_shells = v
		clear_materials()
		create_materials()
		setup_materials()

## Enable or disable dynamic LOD. If disabled, fur will always be rendered with the maximum number of shells.
@export var lod_enabled: bool = false:
	set(v):
		lod_enabled = v
		if !lod_enabled:
			lod = 0
			apply_lod()
			setup_materials()
		else:
			apply_lod()
			setup_materials()
		notify_property_list_changed()

var lod: int = 0:
	set(v):
		var old_lod = lod
		lod = v
		if lod != old_lod:
			apply_lod()
			setup_materials()


## Minimum distance from the camera at which lower-detail LODs are used.
@export_range(0, 10, 0.01, "or_greater")
var lod_min_distance = 3.0

## Distance from the camera at which the lowest level LOD is used.
@export_range(0, 50, 0.01, "or_greater")
var lod_max_distance = 25.0

## Number of shells to use for the lowest-quality LOD. Default and lower bound is 8, which should be a good value in most cases.
@export_range(8, 256, 1, "or greater")
var lod_minimum_shells: int = 8


## Parameters that affect the growth of the fur - density, length, turbulence, etc.
@export_group("Shape and Growth")

## Strand length
@export_range(0, 2, 0.01, "or_greater")
var length: float = 0.1:
	set(v):
		length = v
		setup_materials()

## Scaling of the fur density - strands per area. Higher numbers make the fur more dense.
@export_range(0.010, 3, 0.001, "or_greater")
var density: float = 0.5:
	set(v):
		density = v
		setup_materials()

## seed for fur noise random generator
@export
var seed: int = RandomNumberGenerator.new().randi_range(0, 65535):
	set(v):
		seed = v
		setup_materials()

## Variation of the height distribution of strands. Higher values for a more scruffy look.
@export_range(0.0, 4, 0.001, "or_greater")
var scruffiness: float = 0.5:
	set(v):
		scruffiness = v
		setup_materials()

## Fur heightmap texture. Values scale hair length by [1..0[. Black pixels are not rendered.
@export
var heightmap_texture: Texture2D: # = preload("res://addons/so_fluffy/density_default.tres").duplicate():
	set(v):
		heightmap_texture = v
		setup_materials()


@export_subgroup("Strand Thickness")

## Thickness profile of a single strand. The values are inverted (1 it thin, 0 is thick) so that the curve presets can be used.
@export
var thickness_curve: CurveTexture:
	set(v):
		thickness_curve = v
		setup_materials()

## Uniformly scales the thickness of all strands.
@export_range(0.01, 4.0, 0.01, "or_greater")
var thickness_scale: float = 1.5:
	set(v):
		thickness_scale = v
		setup_materials()

@export_subgroup("Turbulence and Jitter")

## Noise texture to overlay displacement turbulence on the fur. Best provided as a normal map.
@export
var turbulence_texture: Texture2D = preload("res://addons/so_fluffy/turbulence_default.tres").duplicate():
	set(v):
		turbulence_texture = v
		setup_materials()	
		
## Strength of the turbulence effect. Higher numbers apply more turbulence.
@export_range(0, 1, 0.001, "or_greater")
var turbulence_strength: float = 0.3:
	set(v):
		turbulence_strength = v
		setup_materials()

## Noise texture to add high-frequency jitter on the fur.
@export
var jitter_texture: Texture2D = preload("res://addons/so_fluffy/turbulence_default.tres").duplicate():
	set(v):
		jitter_texture = v
		setup_materials()	
		
## Strength of the jitter effect.
@export_range(0, 1, 0.001, "or_greater")
var jitter_strength: float = 0.0:
	set(v):
		jitter_strength = v
		setup_materials()

@export_subgroup("Growth Direction")

## Blends the fur growth direction between the surface normal and the static directions below. A value of 1 means fur grows only in the direction of normals, a value of 0 means it grows only in a static direction.
@export_range(0, 1, 0.005)
var normal_strength: float = 1.0:
	set(v):
		normal_strength = v
		setup_materials()

## Static direction of fur growth in object space. This is useful for fur that grows in a specific direction but moves with the object, such as a mane or a mohawk.
@export
var static_direction_local: Vector3 = Vector3.ZERO:
	set(v):
		static_direction_local = v
		setup_materials()
		
## Static direction of fur growth in world space. This is useful for fur that grows in a specific direction in world coordinates, such as grass, which always grows upwards.
@export
var static_direction_world: Vector3 = Vector3.ZERO:
	set(v):
		static_direction_world = v
		setup_materials()
		


# Material parameters
@export_group("Appearance")

var shell_material: Material = preload("res://addons/so_fluffy/shell_material.tres").duplicate();

## Albedo color is multiplied by this gradient, sampled by relative height. The default gradient simulates ambient occlusion.
@export
var height_gradient: GradientTexture2D:
	set(v):
		height_gradient = v
		setup_materials()

## Should the height gradient be scaled with the length of individual strands? If true, each strand will use the full gradient.
@export
var scale_height_gradient: bool = false:
	set(v):
		scale_height_gradient = v
		setup_materials()

## If enabled, all pixels on shell 0 are rendered. Otherwise, non-strand pixels are transparent. This is useful if you do not want to incur the overhead of a dedicated skin material.
@export
var render_skin: bool = false:
	set(v):
		render_skin = v
		setup_materials()

## Albedo 
@export_subgroup("Albedo")
## Plain hair color
@export_color_no_alpha
var albedo_color: Color = Color.LIGHT_BLUE:
	set(v):
		albedo_color = v
		setup_materials()

## Texture defining hair color. Albedo color is [i]multiplied[\i] by the texture color.
@export
var albedo_texture: Texture2D:
	set(v):
		albedo_texture = v
		setup_materials()

@export_subgroup("Emission")


## Emission
@export
var use_emission: bool = false:
	set(v):
		use_emission = v
		setup_materials()
		notify_property_list_changed() # necessary to trigger _validate_property, apparently

## Uniform emission color
@export_color_no_alpha
var emission_color: Color:
	set(v):
		emission_color = v
		setup_materials()

## Emission energy multiplier. Higher numbers make the emission brighter.
@export_range(0, 16, 0.01)
var emission_energy_multiplier: float = 1.0:
	set(v):
		emission_energy_multiplier = v
		setup_materials()

## Texture defining emission color. Emission color is [i]added[i] to the texture color.
@export
var emission_texture: Texture2D:
	set(v):
		emission_texture = v
		setup_materials()
		

@export_group("Physics")

# physics parameters are set in _process, no need to call setup_materials()
## Disable physics processing altogether. Physics simulation is very cheap, but should be disabled if the fur will not be subject to any movement.
@export var physics_enabled: bool = true:
	set(v):
		physics_enabled = v		
		init_physics()
		notify_property_list_changed()

## Simulate physics in the editor. Physics simulation is very cheap, but can be distracting while editing.
@export var physics_preview: bool = true:
	set(v):
		physics_preview = v
		if(!physics_preview):
			setup_materials()
			init_physics()
## adjust the magnitude of rotational physics effects
@export var rotational_physics_scale: float = 1.0
## gravity constant
@export var gravity: Vector3 = Vector3(0,0,0)
## strand spring spring_constant
@export var spring_constant: float = 80
## strand mass - higher numbers make the hair more resistant to movement
@export var mass: float = 0.15
## spring damping
@export var damping: float = 3
## allow strand to stretch beyond its length for a more elastic appearance. A value of 1 means no stretch is allowed.
@export_range(1, 2, 0.01, "or_greater") var stretch: float = 1.0

## controls how stiff the strands are over their length - higher numbers make the strands more bendy
@export_range(0, 4, 0.01, "or_greater")
var stiffness: float = 1.0



var lod_shell_count: int = 0

# the geometry we're growing fur on
var mesh: GeometryInstance3D

# the generated shell materials
var shells: Array[Material] = []

# shells for current LOD
var lod_shells: Array[Material] = []

# linear spring physics state
var previous_position: Vector3
var spring_offset: Vector3 = Vector3.ZERO
var spring_velocity: Vector3 = Vector3.ZERO

# rotational spring physics state
var previous_rotation: Vector3 = Vector3.ZERO
var spring_rotation: Vector3 = Vector3.ZERO
var spring_angular_velocity: Vector3 = Vector3.ZERO

func _validate_property(property: Dictionary):
	# hide/show emission section details
	if property.name in ["emission_color", "emission_energy_multiplier", "emission_texture"] and !use_emission:
			property.usage = PROPERTY_USAGE_NO_EDITOR
	# hide/show physics section details
	if property.name in ["physics_preview", "gravity", "spring_constant", "mass", "damping", "stretch"] and !physics_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	# hide/show LOD section details
	if property.name in ["lod_min_distance", "lod_max_distance"] and !lod_enabled:
		property.usage = PROPERTY_USAGE_NO_EDITOR

func _ready():
	mesh = get_parent()
	clear_materials()
	create_materials()
	lod = 0
	lod_shell_count = number_of_shells
	apply_lod()
	setup_materials()	
	init_physics()	
	notify_property_list_changed()


func _enter_tree():
	pass

# remove fur material
func clear_materials():
	if(mesh == null):
		return
	if target_surfaces.size() == 0:
		if !remove_fur_material(mesh.material_overlay):
			mesh.material_overlay = null
	else:
		for i in target_surfaces:
			if !remove_fur_material(mesh.get_surface_override_material(i)):
				mesh.set_surface_override_material(i, null)

	for shell in shells:
		shell.next_pass = null
	shells = []


# remove fur materials when Fur node is deleted
func _exit_tree() -> void:
	clear_materials()


# remove fur material from the material chain. Returns false if the passed material is itself a fur material.
func remove_fur_material(mat: Material) -> bool:
	if mat == null:
		return false
	if mat.has_meta("is_fur"):
		return false

	while mat.next_pass != null:		
		if mat.next_pass.has_meta("is_fur"):
			mat.next_pass = null
			return true
		mat = mat.next_pass

	return true

# assigns a fur material to the last material in the next_pass chain. If the start of the chain is null, return false.
func assign_fur_material(mat: Material, fur: Material) -> bool:
	if mat == null:
		return false

	while mat.next_pass != null:		
		mat = mat.next_pass

	mat.next_pass = fur

	return true


# create cascade of shell materials and assign to subsequent next_pass slots
func create_materials():	
	if(mesh == null):
		return	

	var mat = shell_material.duplicate()
	mat.set_meta("is_fur", true)

	if target_surfaces.size() == 0:
		if !assign_fur_material(mesh.material_overlay, mat):
			mesh.material_overlay = mat
	else:
		for i in target_surfaces:
			if !assign_fur_material(mesh.get_surface_override_material(i), mat):
				mesh.set_surface_override_material(i, mat)
	
	shells.append(mat)

	for i in range(1, number_of_shells):
		var new_mat = shell_material.duplicate()
		new_mat.set_meta("is_fur", true)
		mat.next_pass = new_mat
		mat = new_mat
		shells.append(mat)
		
	previous_position = mesh.transform.origin
	previous_rotation = mesh.transform.basis.get_euler()


func apply_lod():	
	if mesh == null:
		return

	lod_shells = []
	
	lod_shell_count = lod_minimum_shells + (1 - float(lod) / (number_of_shells-1)) * (number_of_shells - lod_minimum_shells)

	var step = float(number_of_shells-1) / (lod_shell_count-1)

	lod_shells.append(shells[0])

	for i in range(lod_shell_count-1):		
		var base = int(step * i)
		var next = int(step * (i+1))
		shells[base].next_pass = shells[next]
		lod_shells.append(shells[next])

# setup parameters for all shell materials
func setup_materials():
	if mesh == null:
		return

	for i in number_of_shells:
		configure_material_for_level(shells[i], i)


# set shader parameters for a single shell at the given level
func configure_material_for_level(mat: Material, level: int):
	var h = float(level) / (number_of_shells-1)
	
	# lower number of shells means visually less dense fur. We adjust the thickness based on an empirical formula
	# to compensate for the loss of strand pixels
	var lod_thickness = 4.5987 * pow(lod_shell_count, -0.2807) if lod_enabled else 1.0

	# growth
	mat.set_shader_parameter("height", length)
	mat.set_shader_parameter("normal_strength", normal_strength)
	mat.set_shader_parameter("static_direction_local", static_direction_local)
	mat.set_shader_parameter("static_direction_world", static_direction_world)
	mat.set_shader_parameter("h", h)
	mat.set_shader_parameter("heightmap_texture", heightmap_texture)
	mat.set_shader_parameter("use_heightmap_texture", heightmap_texture != null)
	mat.set_shader_parameter("turbulence_texture", turbulence_texture)
	mat.set_shader_parameter("turbulence_strength", turbulence_strength)
	mat.set_shader_parameter("jitter_texture", jitter_texture)
	mat.set_shader_parameter("jitter_strength", jitter_strength)
	mat.set_shader_parameter("density", density)
	mat.set_shader_parameter("seed", seed)
	mat.set_shader_parameter("scruffiness", scruffiness)
	mat.set_shader_parameter("thickness_curve", thickness_curve)
	mat.set_shader_parameter("use_thickness_curve", thickness_curve != null)
	mat.set_shader_parameter("thickness_scale", thickness_scale * lod_thickness)
	mat.set_shader_parameter("render_skin", render_skin)
	# Albedo
	mat.set_shader_parameter("color", albedo_color)
	mat.set_shader_parameter("height_gradient", height_gradient)
	mat.set_shader_parameter("use_height_gradient", height_gradient != null)
	mat.set_shader_parameter("scale_height_gradient", scale_height_gradient)
	mat.set_shader_parameter("use_albedo_texture", albedo_texture != null)
	mat.set_shader_parameter("albedo_texture", albedo_texture)
	# Emission
	mat.set_shader_parameter("use_emission", use_emission)
	mat.set_shader_parameter("emission_color", emission_color)
	mat.set_shader_parameter("emission_energy_multiplier", emission_energy_multiplier)
	mat.set_shader_parameter("use_emission_texture", emission_texture != null)
	mat.set_shader_parameter("emission_texture", emission_texture)	

func init_physics():
	spring_offset = Vector3.ZERO
	spring_velocity = Vector3.ZERO
	spring_rotation = Vector3.ZERO
	spring_angular_velocity = Vector3.ZERO	

	if mesh == null:
		return

	previous_position = mesh.transform.origin
	previous_rotation = mesh.transform.basis.get_euler()

	for mat in shells:
		# initial Physics parameters
		mat.set_shader_parameter("physics_pos_offset", Vector3.ZERO)
		mat.set_shader_parameter("physics_rot_offset", Basis.IDENTITY)

func _process(_delta):
	# LOD
	if lod_enabled:
		if mesh == null:
			return
		# calculate distance from transform origin to camera		
		var camera: Camera3D = get_viewport().get_camera_3d()
		if camera == null:
			return
		
		# use closest point on AABB for distance calculation.
		var aabb: AABB = mesh.get_aabb()
		var closest = closest_point_on_aabb(aabb, camera.transform.origin)

		# lod distance in the range [0, 1]	
		var rel_dist: float = clamp((camera.transform.origin.distance_to(closest) - lod_min_distance) / (lod_max_distance - lod_min_distance), 0, 1)

		# linearly scale number of shells
		lod = clamp(floor(rel_dist * number_of_shells), 0, number_of_shells-1)


func closest_point_on_aabb(aabb: AABB, p: Vector3):
	var closest = Vector3.ZERO
	var pos = mesh.to_global(aabb.position)
	var end = mesh.to_global(aabb.end)
	closest.x = clamp(p.x, pos.x, end.x)
	closest.y = clamp(p.y, pos.y, end.y)
	closest.z = clamp(p.z, pos.z, end.z)
	return closest
	

func _physics_process(delta):	
	linear_spring_physics(delta)
	rotational_spring_physics(delta)


# calculate spring physics for linear movement
func linear_spring_physics(delta: float):
	if !physics_enabled: return
	if Engine.is_editor_hint() and (!physics_preview || !preview_in_editor): return
	# calculate compound linear forces acting on the shells
	var f = gravity
		
	# calculate movement from previous position
	var dx = mesh.transform.origin - previous_position # movement from previous position
	var v = dx / delta # velocity
	spring_offset += dx # new offset, after base has moved

	var st = 8.0 # "exaggeration" factor for more fun spring movement

	f += -spring_constant * spring_offset - damping * (v+spring_velocity)

	var a = f / mass
	spring_velocity += a * delta
	var s = spring_velocity * delta / 2
	
	spring_offset += s

	spring_velocity = spring_velocity.limit_length( 200.0 * length )

	# iterate through materials from 0 length to 1 and set physics params
	var dh = 1.0 / (number_of_shells-1)
	var h = dh

	spring_offset = spring_offset.limit_length(length / st * stretch)

	for i in range(number_of_shells):
		var mat = shells[i]
		var offset_at_height = st * spring_offset * pow(h * i, stiffness)
		mat.set_shader_parameter("physics_pos_offset", -offset_at_height)
		i+=1
		
	previous_position = mesh.transform.origin


func short_angle(a):
	return fmod(2 * a, 2 * PI) - a

# calculate spring physics for rotational movement
func rotational_spring_physics(delta: float):
	if !physics_enabled:
		return
	if Engine.is_editor_hint() and (!physics_preview || !preview_in_editor):
		return
	# calculate compound rotational forces acting on the shells, as a Vector3 of Euler angles
	var f = Vector3.ZERO
	
	# calculate rotation from previous position
	var dp: Vector3 = mesh.transform.basis.get_euler() - previous_rotation # rotation from previous rotation
	
	dp = Vector3(short_angle(dp.x), short_angle(dp.y), short_angle(dp.z))

	var w: Vector3 = dp / delta # velocity
	spring_rotation += dp # new offset, after base has rotated
	
	f += -spring_rotation * spring_constant - damping * (w+spring_angular_velocity)
	
	var a = f / mass
	spring_angular_velocity += a * delta
	var p = spring_angular_velocity * delta / 2
	
	spring_rotation += p
	
	# iterate through materials from 0 length to 1 and set physics params
	var dh = 1.0 / (number_of_shells-1)
	var h = dh	

	spring_rotation = spring_rotation.limit_length(PI * length / 2.0)

	for i in range(number_of_shells):
		var mat = shells[i]
		var rotation_at_height = rotational_physics_scale * spring_rotation * pow(h * i, stiffness)
		mat.set_shader_parameter("physics_rot_offset", Basis.from_euler(rotation_at_height))
		i+=1
		
	previous_rotation = mesh.transform.basis.get_euler()
