class_name CardView
extends Control

signal card_clicked(card_view: CardView)

@export var card_data: CardData:
	set(val):
		card_data = val
		update_view()

var is_selected: bool = false
var is_focused_card: bool = false
var show_immunity_badge: bool = false

# ノード参照
@onready var card_panel: Panel = $CardPanel
@onready var rank_top: Label = $CardPanel/TopLeft/RankTop
@onready var suit_top: Label = $CardPanel/TopLeft/SuitTop
@onready var suit_center: Label = $CardPanel/SuitCenter
@onready var suit_bottom: Label = $CardPanel/BottomRight/SuitBottom
@onready var rank_bottom: Label = $CardPanel/BottomRight/RankBottom
@onready var check_badge: Label = $CardPanel/CheckBadge
@onready var immunity_badge: Label = $CardPanel/ImmunityBadge

var tween_offset: Tween

# スタイル
var normal_style: StyleBoxFlat
var focus_style: StyleBoxFlat
var selected_style: StyleBoxFlat
var enemy_style: StyleBoxFlat

func _ready() -> void:
	_create_styles()
	update_view()

func _create_styles() -> void:
	# 通常スタイル
	normal_style = StyleBoxFlat.new()
	normal_style.bg_color = Color("f9f9fb")
	normal_style.set_corner_radius_all(6)
	normal_style.border_width_left = 2
	normal_style.border_width_top = 2
	normal_style.border_width_right = 2
	normal_style.border_width_bottom = 2
	normal_style.border_color = Color("b0bec5")
	normal_style.shadow_size = 4
	normal_style.shadow_offset = Vector2(0, 2)
	normal_style.shadow_color = Color(0, 0, 0, 0.35)
	
	# フォーカススタイル（ゴールド）
	focus_style = normal_style.duplicate()
	focus_style.border_color = Color("ffca28")
	focus_style.border_width_left = 3
	focus_style.border_width_top = 3
	focus_style.border_width_right = 3
	focus_style.border_width_bottom = 3
	focus_style.shadow_size = 8
	focus_style.shadow_offset = Vector2(0, 4)
	focus_style.shadow_color = Color("ffca28", 0.6)
	
	# 選択中スタイル（グリーン）
	selected_style = normal_style.duplicate()
	selected_style.bg_color = Color("e8f5e9")
	selected_style.border_color = Color("00e676")
	selected_style.border_width_left = 3
	selected_style.border_width_top = 3
	selected_style.border_width_right = 3
	selected_style.border_width_bottom = 3
	selected_style.shadow_size = 12
	selected_style.shadow_offset = Vector2(0, 6)
	selected_style.shadow_color = Color("00e676", 0.7)

	# 敵カードスタイル（ダーク）
	enemy_style = StyleBoxFlat.new()
	enemy_style.bg_color = Color("1e222b")
	enemy_style.set_corner_radius_all(8)
	enemy_style.border_width_left = 3
	enemy_style.border_width_top = 3
	enemy_style.border_width_right = 3
	enemy_style.border_width_bottom = 3
	enemy_style.border_color = Color("cfd8dc")
	enemy_style.shadow_size = 10
	enemy_style.shadow_offset = Vector2(0, 4)
	enemy_style.shadow_color = Color(0, 0, 0, 0.6)

func set_card_data(data: CardData) -> void:
	card_data = data
	update_view()

func set_focused(focused: bool) -> void:
	if is_focused_card != focused:
		is_focused_card = focused
		_update_visual_state()

func set_selected(selected: bool) -> void:
	if is_selected != selected:
		is_selected = selected
		_update_visual_state()

func set_immunity_badge_visible(is_visible: bool) -> void:
	show_immunity_badge = is_visible
	if immunity_badge:
		immunity_badge.visible = show_immunity_badge

func update_view() -> void:
	if not is_inside_tree() or not card_panel:
		return
	
	if card_data == null:
		visible = false
		return
	
	visible = true
	var rank_str = card_data.get_rank_name()
	var suit_str = card_data.get_suit_symbol()
	var color = card_data.get_suit_color()
	var classic_color = card_data.get_classic_suit_color()
	
	if card_data.is_enemy:
		card_panel.add_theme_stylebox_override("panel", enemy_style)
		rank_top.text = rank_str
		rank_top.add_theme_color_override("font_color", Color.WHITE)
		suit_top.text = suit_str
		suit_top.add_theme_color_override("font_color", color)
		
		rank_bottom.text = rank_str
		rank_bottom.add_theme_color_override("font_color", Color.WHITE)
		suit_bottom.text = suit_str
		suit_bottom.add_theme_color_override("font_color", color)
		
		suit_center.text = suit_str
		suit_center.add_theme_color_override("font_color", color)
		if check_badge:
			check_badge.visible = false
		if show_immunity_badge and immunity_badge:
			immunity_badge.visible = true
			immunity_badge.text = "%s耐性" % suit_str
	else:
		_apply_style()
		rank_top.text = rank_str
		rank_top.add_theme_color_override("font_color", classic_color)
		suit_top.text = suit_str
		suit_top.add_theme_color_override("font_color", classic_color)
		
		rank_bottom.text = rank_str
		rank_bottom.add_theme_color_override("font_color", classic_color)
		suit_bottom.text = suit_str
		suit_bottom.add_theme_color_override("font_color", classic_color)
		
		suit_center.text = suit_str
		suit_center.add_theme_color_override("font_color", classic_color)
		if check_badge:
			check_badge.visible = is_selected
		if immunity_badge:
			immunity_badge.visible = false

func _apply_style() -> void:
	if card_data and card_data.is_enemy:
		return
	
	if is_selected:
		card_panel.add_theme_stylebox_override("panel", selected_style)
	elif is_focused_card:
		card_panel.add_theme_stylebox_override("panel", focus_style)
	else:
		card_panel.add_theme_stylebox_override("panel", normal_style)

func _update_visual_state() -> void:
	_apply_style()
	if check_badge:
		check_badge.visible = is_selected and (card_data == null or not card_data.is_enemy)
	
	var target_y = 0.0
	if is_selected:
		target_y = -20.0
	elif is_focused_card:
		target_y = -10.0
	
	if tween_offset and tween_offset.is_valid():
		tween_offset.kill()
	
	tween_offset = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween_offset.tween_property(card_panel, "position:y", target_y, 0.12)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			card_clicked.emit(self)
			accept_event()
