extends ColorRect

@export var alpha: float = 0.5
@export var update_every_n_frames: int = 1
@export var fade_duration: float = 1.0  # seconds
@export var fade_target: float = 0.75   # target alpha when fully active

@onready var shader_mat: ShaderMaterial = material as ShaderMaterial
var fb_tex: ImageTexture = null
var _frame_counter: int = 0
var _fade_tween: Tween = null

func _process(_delta: float) -> void:
	_frame_counter = (_frame_counter + 1) % max(1, update_every_n_frames)
	if _frame_counter == 0:
		_accumulation_motion_blur()

func _accumulation_motion_blur() -> void:
	await RenderingServer.frame_post_draw

	var vp: Viewport = get_viewport()
	var vp_tex = vp.get_texture()
	if vp_tex == null:
		return

	var img: Image = vp_tex.get_image()

	if fb_tex == null:
		fb_tex = ImageTexture.create_from_image(img)
		if shader_mat:
			shader_mat.set_shader_parameter("framebuffer", fb_tex)
	else:
		fb_tex.update(img)

	if shader_mat:
		shader_mat.set_shader_parameter("alpha", alpha)

# --- Fade control ---

func fade_in() -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "alpha", fade_target, fade_duration)
	_fade_tween.finished.connect(func(): _fade_tween = null)

func fade_out() -> void:
	if _fade_tween:
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "alpha", 0.0, fade_duration)
	_fade_tween.finished.connect(func(): _fade_tween = null)
