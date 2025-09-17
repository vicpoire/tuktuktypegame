extends Node
class_name SkyProfileManager

@export var sky_material: ShaderMaterial
@export var sun_light: DirectionalLight3D
@export var environment: Environment
@export var profiles: Array[SkyProfile] = []

var current_profile_index := 0
var sky_pressed_last_frame := false
var is_transitioning := false
var transition_duration := 2.0
var transition_timer := 0.0
var start_profile: SkyProfile
var target_profile: SkyProfile
var procedural_sky: Sky
var skybox_sky: Sky

func _ready():
	setup_sky_resources()
	if profiles.size() > 0:
		apply_profile(profiles[0])

func setup_sky_resources():
	procedural_sky = Sky.new()
	procedural_sky.sky_material = sky_material
	skybox_sky = Sky.new()
	var skybox_material = PanoramaSkyMaterial.new()
	skybox_sky.sky_material = skybox_material

func _process(delta: float):
	# Update shader with the **current profile’s viewport & dither**
	if profiles.size() > 0 and sky_material:
		var current := profiles[current_profile_index]
		sky_material.set_shader_parameter("viewport_size", current.viewport_size)
		sky_material.set_shader_parameter("dither_strength", current.dither_strength)

	var sky_pressed = Input.is_action_pressed("sky")
	if sky_pressed and not sky_pressed_last_frame and not is_transitioning:
		start_transition_to_next_profile()
	sky_pressed_last_frame = sky_pressed

	if is_transitioning:
		transition_timer += delta
		var progress = transition_timer / transition_duration
		if progress >= 1.0:
			progress = 1.0
			is_transitioning = false
			apply_profile(target_profile)
		else:
			lerp_between_profiles(start_profile, target_profile, progress)

func start_transition_to_next_profile():
	if profiles.size() <= 1:
		return
	start_profile = create_current_profile_snapshot()
	var next_index = (current_profile_index + 1) % profiles.size()
	target_profile = profiles[next_index]
	current_profile_index = next_index
	is_transitioning = true
	transition_timer = 0.0
	print("starting transition to ", target_profile.profile_name)

func create_current_profile_snapshot() -> SkyProfile:
	var snapshot = SkyProfile.new()
	if current_profile_index < profiles.size():
		var current = profiles[current_profile_index]
		snapshot.sky_mode = current.sky_mode
		snapshot.skybox_texture = current.skybox_texture
		snapshot.viewport_size = current.viewport_size
		snapshot.dither_strength = current.dither_strength

	if snapshot.sky_mode == 0:
		if sky_material:
			snapshot.sky_color = sky_material.get_shader_parameter("skyColor")
			snapshot.horizon_color = sky_material.get_shader_parameter("horizonColor")
			snapshot.cloud_color = sky_material.get_shader_parameter("cloudColor")
			snapshot.cloud_threshold = sky_material.get_shader_parameter("cloud_threshold")
			snapshot.cloud_softness = sky_material.get_shader_parameter("cloud_softness")
			snapshot.cloud_scale = sky_material.get_shader_parameter("cloud_scale")
			snapshot.cloud_speed = sky_material.get_shader_parameter("cloud_speed")
			snapshot.cloud_opacity = sky_material.get_shader_parameter("cloud_opacity")
			snapshot.dither_strength = sky_material.get_shader_parameter("dither_strength")

	if sun_light:
		snapshot.sun_intensity = sun_light.light_energy
		snapshot.sun_color = sun_light.light_color

	if environment:
		snapshot.ambient_color = environment.ambient_light_color
		snapshot.fog_enabled = environment.fog_enabled
		snapshot.fog_color = environment.fog_light_color
		snapshot.fog_density = environment.fog_density

	return snapshot

func lerp_between_profiles(from: SkyProfile, to: SkyProfile, t: float):
	if not from or not to: return
	var smooth_t = smoothstep(0.0, 1.0, t)

	if from.sky_mode != to.sky_mode:
		if smooth_t < 0.5:
			apply_sky_mode(from.sky_mode, from)
		else:
			apply_sky_mode(to.sky_mode, to)
	else:
		if from.sky_mode == 0:
			lerp_procedural_sky(from, to, smooth_t)

	if sun_light:
		sun_light.light_energy = lerp(from.sun_intensity, to.sun_intensity, smooth_t)
		sun_light.light_color = from.sun_color.lerp(to.sun_color, smooth_t)

	if environment:
		environment.ambient_light_color = from.ambient_color.lerp(to.ambient_color, smooth_t)
		lerp_fog(from, to, smooth_t)


func lerp_fog(from: SkyProfile, to: SkyProfile, t: float):
	if from.fog_enabled == to.fog_enabled:
		environment.fog_enabled = from.fog_enabled
		if from.fog_enabled:
			environment.fog_light_color = from.fog_color.lerp(to.fog_color, t)
			environment.fog_density = lerp(from.fog_density, to.fog_density, t)
	else:
		if t < 0.5:
			environment.fog_enabled = from.fog_enabled
			if from.fog_enabled:
				environment.fog_light_color = from.fog_color
				environment.fog_density = from.fog_density
		else:
			environment.fog_enabled = to.fog_enabled
			if to.fog_enabled:
				environment.fog_light_color = to.fog_color
				environment.fog_density = to.fog_density

func apply_profile(profile: SkyProfile):
	if not profile: return
	apply_sky_mode(profile.sky_mode, profile)
	apply_lighting(profile)
	apply_environment(profile)
	if sky_material:
		sky_material.set_shader_parameter("viewport_size", profile.viewport_size)
		sky_material.set_shader_parameter("dither_strength", profile.dither_strength)

func apply_sky_mode(mode: int, profile: SkyProfile):
	if not environment: return
	if mode == 0:
		environment.sky = procedural_sky
		apply_procedural_sky(profile)
	else:
		environment.sky = skybox_sky
		apply_skybox(profile)

func apply_procedural_sky(profile: SkyProfile):
	if not sky_material: return

	sky_material.set_shader_parameter("skyColor", profile.sky_color)
	sky_material.set_shader_parameter("horizonColor", profile.horizon_color)
	sky_material.set_shader_parameter("cloudColor", profile.cloud_color)
	sky_material.set_shader_parameter("cloud_threshold", profile.cloud_threshold)
	sky_material.set_shader_parameter("cloud_softness", profile.cloud_softness)
	sky_material.set_shader_parameter("cloud_scale_x", profile.cloud_scale_x)
	sky_material.set_shader_parameter("cloud_scale_y", profile.cloud_scale_y)
	sky_material.set_shader_parameter("cloud_speed", profile.cloud_speed)
	sky_material.set_shader_parameter("cloud_opacity", profile.cloud_opacity)
	sky_material.set_shader_parameter("dither_strength", profile.dither_strength)
	sky_material.set_shader_parameter("viewport_size", profile.viewport_size)

func lerp_procedural_sky(from: SkyProfile, to: SkyProfile, t: float):
	if not sky_material: return

	var smooth_t = smoothstep(0.0, 1.0, t)

	sky_material.set_shader_parameter("skyColor", from.sky_color.lerp(to.sky_color, smooth_t))
	sky_material.set_shader_parameter("horizonColor", from.horizon_color.lerp(to.horizon_color, smooth_t))
	sky_material.set_shader_parameter("cloudColor", from.cloud_color.lerp(to.cloud_color, smooth_t))
	sky_material.set_shader_parameter("cloud_threshold", lerp(from.cloud_threshold, to.cloud_threshold, smooth_t))
	sky_material.set_shader_parameter("cloud_softness", lerp(from.cloud_softness, to.cloud_softness, smooth_t))
	sky_material.set_shader_parameter("cloud_scale_x", lerp(from.cloud_scale_x, to.cloud_scale_x, smooth_t))
	sky_material.set_shader_parameter("cloud_scale_y", lerp(from.cloud_scale_y, to.cloud_scale_y, smooth_t))
	sky_material.set_shader_parameter("cloud_speed", lerp(from.cloud_speed, to.cloud_speed, smooth_t))
	sky_material.set_shader_parameter("cloud_opacity", lerp(from.cloud_opacity, to.cloud_opacity, smooth_t))
	sky_material.set_shader_parameter("dither_strength", lerp(from.dither_strength, to.dither_strength, smooth_t))
	sky_material.set_shader_parameter("viewport_size",
		Vector2(
			lerp(from.viewport_size.x, to.viewport_size.x, smooth_t),
			lerp(from.viewport_size.y, to.viewport_size.y, smooth_t)
		)
	)


func apply_skybox(profile: SkyProfile):
	if not skybox_sky or not skybox_sky.sky_material: return
	var skybox_material = skybox_sky.sky_material as PanoramaSkyMaterial
	if skybox_material and profile.skybox_texture:
		skybox_material.panorama = profile.skybox_texture

func apply_lighting(profile: SkyProfile):
	if sun_light:
		sun_light.light_energy = profile.sun_intensity
		sun_light.light_color = profile.sun_color

func apply_environment(profile: SkyProfile):
	if not environment: return
	environment.ambient_light_color = profile.ambient_color
	environment.ambient_light_energy = 0.3
	if profile.fog_enabled:
		environment.fog_enabled = true
		environment.fog_light_color = profile.fog_color
		environment.fog_density = profile.fog_density
	else:
		environment.fog_enabled = false

func add_profile(profile: SkyProfile):
	profiles.append(profile)
