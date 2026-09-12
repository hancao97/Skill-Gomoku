extends Control

var screen: ColorRect
var screen_material: ShaderMaterial
var title: TextureRect
var title_material: ShaderMaterial
var amount := 0.0
var pulse := 0.0
var title_key := ""
var motion: Tween
var title_motion: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen=ColorRect.new()
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter=Control.MOUSE_FILTER_IGNORE
	screen_material=ShaderMaterial.new()
	screen_material.shader=preload("res://shaders/cinema.gdshader")
	screen.material=screen_material
	add_child(screen)
	title=TextureRect.new()
	title.position=Vector2(245,85)
	title.size=Vector2(1050,310)
	title.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	title.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	title.mouse_filter=Control.MOUSE_FILTER_IGNORE
	title.pivot_offset=title.size*.5
	title_material=ShaderMaterial.new()
	title_material.shader=preload("res://shaders/calligraphy.gdshader")
	title.material=title_material
	add_child(title)
	title.hide()
	hide()

func _process(delta:float) -> void:
	pulse=move_toward(pulse,0.0,delta*2.0)
	screen_material.set_shader_parameter("amount",amount)
	screen_material.set_shader_parameter("pulse",pulse)

func begin(color:int, center:Vector2=Vector2(.62,.5)) -> void:
	show()
	title.hide()
	title_key=""
	screen_material.set_shader_parameter("white_stone",color==2)
	screen_material.set_shader_parameter("origin",center)
	if motion and motion.is_running():motion.kill()
	motion=create_tween()
	motion.tween_property(self,"amount",.88,.28)

func strike(power:float=1.0) -> void:
	pulse=power

func inscription(key:String, color:int) -> void:
	title_key=key
	title.texture=load("res://assets/calligraphy/"+key+".png")
	title_material.set_shader_parameter("white_stone",color==2)
	title_material.set_shader_parameter("reveal",0.0)
	title_material.set_shader_parameter("fade",1.0)
	title.show()
	title.scale=Vector2(1.13,1.13)
	if title_motion and title_motion.is_running():title_motion.kill()
	title_motion=create_tween().set_parallel()
	title_motion.tween_method(func(v:float):title_material.set_shader_parameter("reveal",v),0.0,1.1,.66).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	title_motion.tween_property(title,"scale",Vector2.ONE,.45).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	title_motion.chain().tween_interval(1.7)
	title_motion.chain().tween_method(func(v:float):title_material.set_shader_parameter("fade",v),1.0,0.0,.45)
	title_motion.chain().tween_callback(title.hide)

func end() -> void:
	if motion and motion.is_running():motion.kill()
	motion=create_tween()
	motion.tween_property(self,"amount",0.0,.45)
	await motion.finished
	title.hide()
	title_key=""
	hide()
