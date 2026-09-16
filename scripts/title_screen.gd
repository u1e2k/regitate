class_name TitleScreen
extends Control

const RULE_DIALOG_SCENE = preload("res://scenes/RuleDialog.tscn")

enum MenuItem {
	START_GAME,
	DIFFICULTY,
	HOW_TO_PLAY
}

var current_menu_index: int = 0
var rule_dialog: RuleDialog

@onready var btn_start: Button = $VBoxContainer/MenuContainer/BtnStart
@onready var btn_difficulty: Button = $VBoxContainer/MenuContainer/BtnDifficulty
@onready var btn_rules: Button = $VBoxContainer/MenuContainer/BtnRules
@onready var diff_desc_label: Label = $VBoxContainer/MenuContainer/DiffDescLabel
@onready var footer_guide: Label = $FooterGuide

var menu_buttons: Array[Button] = []

func _ready() -> void:
	menu_buttons = [btn_start, btn_difficulty, btn_rules]
	
	btn_start.pressed.connect(_on_start_pressed)
	btn_difficulty.pressed.connect(_cycle_difficulty)
	btn_rules.pressed.connect(_on_rules_pressed)
	
	_update_difficulty_display()
	_update_menu_focus()

func _unhandled_input(event: InputEvent) -> void:
	if rule_dialog and rule_dialog.visible:
		return
	
	if event.is_action_pressed("ui_up"):
		_change_menu_index(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_change_menu_index(1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_left"):
		if current_menu_index == MenuItem.DIFFICULTY:
			_change_difficulty(-1)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		if current_menu_index == MenuItem.DIFFICULTY:
			_change_difficulty(1)
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("action_play"):
		_activate_current_menu()
		get_viewport().set_input_as_handled()

func _change_menu_index(delta: int) -> void:
	current_menu_index = (current_menu_index + delta + menu_buttons.size()) % menu_buttons.size()
	_update_menu_focus()

func _update_menu_focus() -> void:
	for i in range(menu_buttons.size()):
		var btn = menu_buttons[i]
		if i == current_menu_index:
			btn.grab_focus()
		else:
			btn.release_focus()

func _activate_current_menu() -> void:
	match current_menu_index:
		MenuItem.START_GAME:
			_on_start_pressed()
		MenuItem.DIFFICULTY:
			_cycle_difficulty()
		MenuItem.HOW_TO_PLAY:
			_on_rules_pressed()

func _cycle_difficulty() -> void:
	_change_difficulty(1)

func _change_difficulty(dir: int) -> void:
	var total_diffs = GameState.Difficulty.size()
	var new_diff_idx = (int(GameState.current_difficulty) + dir + total_diffs) % total_diffs
	GameState.current_difficulty = new_diff_idx as GameState.Difficulty
	_update_difficulty_display()

func _update_difficulty_display() -> void:
	btn_difficulty.text = "難易度: ◄  %s  ►" % GameState.get_difficulty_name()
	diff_desc_label.text = GameState.get_difficulty_desc()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/Main.tscn")

func _on_rules_pressed() -> void:
	if not rule_dialog:
		rule_dialog = RULE_DIALOG_SCENE.instantiate() as RuleDialog
		add_child(rule_dialog)
		rule_dialog.closed.connect(func(): _update_menu_focus())
	rule_dialog.open()
