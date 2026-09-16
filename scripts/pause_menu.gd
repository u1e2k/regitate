class_name PauseMenu
extends Control

signal resumed()
signal restarted()
signal quit_to_title()

const RULE_DIALOG_SCENE = preload("res://scenes/RuleDialog.tscn")

enum MenuItem {
	RESUME,
	RESTART,
	RULES,
	QUIT_TITLE
}

var current_menu_index: int = 0
var rule_dialog: RuleDialog

@onready var btn_resume: Button = $Panel/VBox/MenuContainer/BtnResume
@onready var btn_restart: Button = $Panel/VBox/MenuContainer/BtnRestart
@onready var btn_rules: Button = $Panel/VBox/MenuContainer/BtnRules
@onready var btn_quit: Button = $Panel/VBox/MenuContainer/BtnQuit

var menu_buttons: Array[Button] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu_buttons = [btn_resume, btn_restart, btn_rules, btn_quit]
	
	btn_resume.pressed.connect(_on_resume_pressed)
	btn_restart.pressed.connect(_on_restart_pressed)
	btn_rules.pressed.connect(_on_rules_pressed)
	btn_quit.pressed.connect(_on_quit_pressed)
	
	_update_menu_focus()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	
	if rule_dialog and rule_dialog.visible:
		return
	
	if event.is_action_pressed("action_pause") or event.is_action_pressed("action_cancel"):
		_on_resume_pressed()
		get_viewport().set_input_as_handled()
		return
	
	if event.is_action_pressed("ui_up"):
		_change_menu_index(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_down"):
		_change_menu_index(1)
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
		MenuItem.RESUME:
			_on_resume_pressed()
		MenuItem.RESTART:
			_on_restart_pressed()
		MenuItem.RULES:
			_on_rules_pressed()
		MenuItem.QUIT_TITLE:
			_on_quit_pressed()

func open_menu() -> void:
	visible = true
	get_tree().paused = true
	current_menu_index = 0
	_update_menu_focus()

func _on_resume_pressed() -> void:
	visible = false
	get_tree().paused = false
	resumed.emit()

func _on_restart_pressed() -> void:
	visible = false
	get_tree().paused = false
	restarted.emit()

func _on_rules_pressed() -> void:
	if not rule_dialog:
		rule_dialog = RULE_DIALOG_SCENE.instantiate() as RuleDialog
		add_child(rule_dialog)
		rule_dialog.closed.connect(func(): _update_menu_focus())
	rule_dialog.open()

func _on_quit_pressed() -> void:
	get_tree().paused = false
	quit_to_title.emit()
	get_tree().change_scene_to_file("res://scenes/Title.tscn")
