extends CanvasLayer
## In-run HUD: hull and boost meters, stage and hostile count, collateral
## damage counter, owned upgrades, boss bar, banners and the damage flash.

const Bar := preload("res://scenes/ui/bar.gd")
const UI := preload("res://scenes/ui/ui_kit.gd")
const PowerUps := preload("res://data/powerups.gd")

var _hp_bar
var _hp_label: Label
var _dash_bar
var _stage_label: Label
var _hostiles: Label
var _collateral: Label
var _upgrades: Label
var _boss_box: VBoxContainer
var _boss_bar
var _boss_name: Label
var _banner: Label
var _sub_banner: Label
var _flash: ColorRect
var _banner_tween: Tween


func _ready() -> void:
	layer = 10
	var root := UI.full_rect(Control.new())
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_flash = ColorRect.new()
	UI.full_rect(_flash)
	_flash.color = Color(1.0, 0.05, 0.1, 0.0)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_flash)

	var tl := VBoxContainer.new()
	tl.position = Vector2(28, 20)
	tl.add_theme_constant_override("separation", 4)
	root.add_child(tl)
	tl.add_child(UI.label("HULL INTEGRITY", 16, UI.CYAN))
	_hp_bar = Bar.new()
	_hp_bar.custom_minimum_size = Vector2(380, 22)
	tl.add_child(_hp_bar)
	_hp_label = UI.label("", 18)
	tl.add_child(_hp_label)
	tl.add_child(UI.label("BOOST", 14, Color(1.0, 0.7, 0.3)))
	_dash_bar = Bar.new()
	_dash_bar.custom_minimum_size = Vector2(200, 10)
	_dash_bar.color = Color(1.0, 0.65, 0.25)
	_dash_bar.segments = 1
	tl.add_child(_dash_bar)

	_stage_label = UI.label("", 26)
	_stage_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stage_label.offset_top = 16
	_stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_stage_label)
	_hostiles = UI.label("", 18, Color(1.0, 0.45, 0.55))
	_hostiles.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_hostiles.offset_top = 52
	_hostiles.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_hostiles)

	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.offset_left = -460
	tr.offset_right = -28
	tr.offset_top = 20
	root.add_child(tr)
	var cl := UI.label("COLLATERAL DAMAGE", 16, Color(1.0, 0.75, 0.3))
	cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(cl)
	_collateral = UI.label("", 28, Color(1.0, 0.85, 0.4))
	_collateral.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(_collateral)

	_upgrades = UI.label("", 16, Color(0.75, 0.9, 1.0), 4)
	_upgrades.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_upgrades.offset_left = 28
	_upgrades.offset_top = -260
	_upgrades.offset_bottom = -24
	_upgrades.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	root.add_child(_upgrades)

	_boss_box = VBoxContainer.new()
	_boss_box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_boss_box.offset_left = 320
	_boss_box.offset_right = -320
	_boss_box.offset_top = -96
	_boss_box.offset_bottom = -30
	root.add_child(_boss_box)
	_boss_name = UI.label("", 24, Color(1.0, 0.35, 0.6))
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_box.add_child(_boss_name)
	_boss_bar = Bar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 22)
	_boss_bar.color = Color(0.9, 0.25, 1.0)
	_boss_bar.segments = 3
	_boss_box.add_child(_boss_bar)
	_boss_box.visible = false

	_banner = UI.label("", 72, Color.WHITE, 12)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.28
	_banner.anchor_bottom = 0.28
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	root.add_child(_banner)
	_sub_banner = UI.label("", 26, Color.WHITE, 8)
	_sub_banner.anchor_left = 0.0
	_sub_banner.anchor_right = 1.0
	_sub_banner.anchor_top = 0.28
	_sub_banner.anchor_bottom = 0.28
	_sub_banner.offset_top = 100
	_sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_banner.modulate.a = 0.0
	root.add_child(_sub_banner)

	Game.player_damaged.connect(_on_player_damaged)
	Game.stats_changed.connect(_refresh_upgrades)
	_refresh_upgrades()


func refresh(run) -> void:
	var max_hp: float = Game.stats.max_hp
	_hp_bar.value = Game.player_hp / max_hp
	_hp_label.text = "%d / %d" % [ceili(Game.player_hp), int(max_hp)]
	if World.player_alive():
		_dash_bar.value = 1.0 - World.player.dash_cd / float(Game.stats.dash_cd)
	_stage_label.text = "STAGE %d / %d  //  %s" % [Game.stage_index + 1, Game.stage_count(), String(Game.current_stage()["name"]).to_upper()]
	var hostiles: int = World.enemies.size() + run.pending
	_hostiles.text = "HOSTILES  %d" % hostiles if hostiles > 0 else ""
	_collateral.text = UI.yen(Game.collateral)


func _refresh_upgrades() -> void:
	var lines: Array = []
	for id in Game.owned:
		var p := PowerUps.find(id)
		lines.append("%s  x%d" % [String(p.name).to_upper(), Game.owned[id]])
	_upgrades.text = "\n".join(lines)


func show_banner(text: String, color: Color, duration: float = 1.6, sub: String = "") -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_sub_banner.text = sub
	if _banner_tween != null:
		_banner_tween.kill()
	_banner.modulate.a = 1.0
	_sub_banner.modulate.a = 1.0
	_banner.pivot_offset = _banner.size * 0.5
	_banner.scale = Vector2(1.3, 1.3)
	_banner_tween = create_tween()
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(duration)
	_banner_tween.tween_property(_banner, "modulate:a", 0.0, 0.4)
	_banner_tween.parallel().tween_property(_sub_banner, "modulate:a", 0.0, 0.4)


func show_boss(boss_name: String) -> void:
	_boss_name.text = boss_name + "  //  CATEGORY IV"
	_boss_bar.value = 1.0
	_boss_box.visible = true


func set_boss(ratio: float) -> void:
	_boss_bar.value = ratio


func hide_boss() -> void:
	_boss_box.visible = false


func _on_player_damaged() -> void:
	_flash.color.a = 0.35
	create_tween().tween_property(_flash, "color:a", 0.0, 0.35)
