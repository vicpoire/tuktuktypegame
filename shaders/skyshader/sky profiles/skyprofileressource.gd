extends Resource
class_name SkyProfile

@export_enum("procedural", "skybox") var sky_mode: int = 0
@export var profile_name: String = "defsky"

@export_group("sky colors")
@export var sky_color: Color = Color(1.0, 1.0, 1.0)
@export var horizon_color: Color = Color(1.0, 1.0, 1.0)
@export var cloud_color: Color = Color(1.0, 1.0, 1.0)

@export_group("cloud settings")
@export var cloud_threshold: float = 0.5
@export var cloud_softness: float = 0.2
@export var cloud_scale_x: float = 2.0
@export var cloud_scale_y: float = 2.0
@export var cloud_speed: float = 0.02
@export var cloud_opacity: float = 1.0
@export var dither_strength: float = 1.0
@export var viewport_size: Vector2 = Vector2(1280,720)

@export_group("lighting")
@export var sun_intensity: float = 1.0
@export var sun_color: Color = Color.WHITE
@export var ambient_color: Color = Color(0.2, 0.2, 0.3)

@export_group("environment")
@export var fog_enabled: bool = false
@export var fog_color: Color = Color.WHITE
@export var fog_density: float = 0.01

@export_group("skybox")
@export var skybox_texture: Texture2D
