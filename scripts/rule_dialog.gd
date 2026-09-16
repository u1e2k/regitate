class_name RuleDialog
extends Control

signal closed()

@onready var close_btn: Button = $Panel/VBox/CloseButton

func _ready() -> void:
	close_btn.pressed.connect(func(): close())

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("action_cancel") or event.is_action_pressed("action_play") or event.is_action_pressed("action_pause"):
		close()
		get_viewport().set_input_as_handled()

func open() -> void:
	visible = true

func close() -> void:
	visible = false
	closed.emit()
