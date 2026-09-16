class_name MainGame
extends Control

const CARD_VIEW_SCENE = preload("res://scenes/Card.tscn")

# 内部ゲームエンジン
var game_engine: GameEngine

# 手札フォーカス・選択管理
var focused_hand_index: int = 0
var selected_indices: Array[int] = []

# ノード参照
@onready var enemy_card_view: CardView = $VBoxContainer/EnemyArea/HBox/EnemyCardContainer/EnemyCardView
@onready var enemy_hp_bar: ProgressBar = $VBoxContainer/EnemyArea/HBox/StatusContainer/EnemyHpBar
@onready var enemy_hp_label: Label = $VBoxContainer/EnemyArea/HBox/StatusContainer/HpLabel
@onready var enemy_atk_label: Label = $VBoxContainer/EnemyArea/HBox/StatusContainer/AttackLabel
@onready var enemy_name_label: Label = $VBoxContainer/EnemyArea/HBox/StatusContainer/EnemyNameLabel

@onready var tavern_deck_label: Label = $VBoxContainer/FieldArea/FieldVBox/DeckInfoHBox/TavernDeckLabel
@onready var discard_pile_label: Label = $VBoxContainer/FieldArea/FieldVBox/DeckInfoHBox/DiscardPileLabel
@onready var castle_deck_label: Label = $VBoxContainer/FieldArea/FieldVBox/DeckInfoHBox/CastleDeckLabel
@onready var last_action_label: Label = $VBoxContainer/FieldArea/FieldVBox/LastActionLabel
@onready var banner_label: Label = $VBoxContainer/FieldArea/FieldVBox/BannerLabel
@onready var selection_info_label: Label = $VBoxContainer/FieldArea/FieldVBox/SelectionInfoLabel

@onready var hand_scroll: ScrollContainer = $VBoxContainer/HandArea/HandVBox/HandContainer/HandScroll
@onready var hand_hbox: HBoxContainer = $VBoxContainer/HandArea/HandVBox/HandContainer/HandScroll/HandHBox
@onready var footer_guide: Label = $VBoxContainer/HandArea/HandVBox/FooterGuide

var banner_tween: Tween

func _ready() -> void:
	_setup_engine()
	game_engine.start_new_game()

func _setup_engine() -> void:
	game_engine = GameEngine.new()
	add_child(game_engine)
	
	game_engine.enemy_spawned.connect(_on_enemy_spawned)
	game_engine.enemy_hp_changed.connect(_on_enemy_hp_changed)
	game_engine.enemy_atk_changed.connect(_on_enemy_atk_changed)
	game_engine.hand_changed.connect(_on_hand_changed)
	game_engine.deck_counts_changed.connect(_on_deck_counts_changed)
	game_engine.action_resolved.connect(_on_action_resolved)
	game_engine.banner_triggered.connect(_on_banner_triggered)
	game_engine.phase_changed.connect(_on_phase_changed)
	game_engine.game_over.connect(_on_game_over)
	game_engine.game_won.connect(_on_game_won)

## D-Pad / ゲームパッド / キーボード入力処理
func _unhandled_input(event: InputEvent) -> void:
	# ゲームオーバー / 勝利時のリスタート
	if game_engine.current_phase == GameEngine.Phase.PHASE_GAME_OVER or game_engine.current_phase == GameEngine.Phase.PHASE_GAME_WIN:
		if event.is_action_pressed("action_play") or event.is_action_pressed("action_cancel"):
			game_engine.start_new_game()
			get_viewport().set_input_as_handled()
			return

	# D-Pad / 十字キー フォーカス移動
	if event.is_action_pressed("ui_left"):
		_move_focus(-1)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_right"):
		_move_focus(1)
		get_viewport().set_input_as_handled()
	
	# Xボタン: 選択/解除トグル
	elif event.is_action_pressed("action_toggle_select"):
		_toggle_current_selection()
		get_viewport().set_input_as_handled()
	
	# Aボタン: 決定（複数選択時はまとめて、非選択時はフォーカスの1枚）
	elif event.is_action_pressed("action_play"):
		_handle_action_play()
		get_viewport().set_input_as_handled()
	
	# Yボタン: パス（イールド）
	elif event.is_action_pressed("action_yield"):
		if game_engine.current_phase == GameEngine.Phase.PHASE_PLAYER:
			game_engine.yield_turn()
		get_viewport().set_input_as_handled()
	
	# Bボタン: 取消（選択クリア）
	elif event.is_action_pressed("action_cancel"):
		_clear_selection()
		get_viewport().set_input_as_handled()

func _move_focus(delta: int) -> void:
	if game_engine.hand.is_empty():
		return
	var new_index = clamp(focused_hand_index + delta, 0, game_engine.hand.size() - 1)
	if new_index != focused_hand_index:
		focused_hand_index = new_index
		_update_hand_views()
		_scroll_to_focused()

func _toggle_current_selection() -> void:
	if game_engine.hand.is_empty():
		return
	
	if selected_indices.has(focused_hand_index):
		selected_indices.erase(focused_hand_index)
	else:
		selected_indices.append(focused_hand_index)
	
	_update_hand_views()
	_update_selection_info()

func _clear_selection() -> void:
	selected_indices.clear()
	_update_hand_views()
	_update_selection_info()

func _scroll_to_focused() -> void:
	if focused_hand_index < 0 or focused_hand_index >= hand_hbox.get_child_count():
		return
	var target_child = hand_hbox.get_child(focused_hand_index) as Control
	if target_child:
		var target_x = target_child.position.x - (hand_scroll.size.x / 2.0) + (target_child.size.x / 2.0)
		hand_scroll.scroll_horizontal = int(clamp(target_x, 0, max(0, hand_hbox.size.x - hand_scroll.size.x)))

func _handle_action_play() -> void:
	var cards_to_act: Array[CardData] = []
	
	# 複数選択されているカードがあれば優先
	if not selected_indices.is_empty():
		selected_indices.sort()
		for idx in selected_indices:
			if idx < game_engine.hand.size():
				cards_to_act.append(game_engine.hand[idx])
	# 選択されていなければ、現在フォーカスしている1枚
	elif focused_hand_index >= 0 and focused_hand_index < game_engine.hand.size():
		cards_to_act.append(game_engine.hand[focused_hand_index])
	
	if cards_to_act.is_empty():
		return
	
	if game_engine.current_phase == GameEngine.Phase.PHASE_PLAYER:
		var validation = game_engine.validate_play_selection(cards_to_act)
		if validation["valid"]:
			_clear_selection()
			game_engine.play_cards(cards_to_act)
		else:
			selection_info_label.text = "⚠️ %s" % validation["reason"]
	
	elif game_engine.current_phase == GameEngine.Phase.PHASE_ENEMY_COUNTER:
		var res = game_engine.discard_for_defense(cards_to_act)
		if res["success"]:
			_clear_selection()
		else:
			selection_info_label.text = "⚠️ %s" % res["reason"]

# ==========================================
# UI更新ロジック
# ==========================================

func _update_hand_views() -> void:
	var cards = game_engine.hand
	
	# フォーカスインデックスの整合性
	if focused_hand_index >= cards.size():
		focused_hand_index = max(0, cards.size() - 1)
	
	# 選択インデックスのクリーニング
	var valid_selected: Array[int] = []
	for idx in selected_indices:
		if idx < cards.size():
			valid_selected.append(idx)
	selected_indices = valid_selected
	
	# 手札ノード数の同期
	while hand_hbox.get_child_count() < cards.size():
		var card_inst = CARD_VIEW_SCENE.instantiate() as CardView
		var idx = hand_hbox.get_child_count()
		card_inst.card_clicked.connect(func(_c): _on_card_view_clicked(idx))
		hand_hbox.add_child(card_inst)
	
	while hand_hbox.get_child_count() > cards.size():
		var child = hand_hbox.get_child(hand_hbox.get_child_count() - 1)
		hand_hbox.remove_child(child)
		child.queue_free()
	
	# 各カードの見た目更新
	for i in range(cards.size()):
		var child = hand_hbox.get_child(i) as CardView
		child.set_card_data(cards[i])
		child.set_focused(i == focused_hand_index)
		child.set_selected(selected_indices.has(i))
	
	_update_selection_info()

func _on_card_view_clicked(index: int) -> void:
	if index == focused_hand_index:
		_toggle_current_selection()
	else:
		focused_hand_index = index
		_update_hand_views()
		_scroll_to_focused()

func _update_selection_info() -> void:
	if game_engine.current_phase == GameEngine.Phase.PHASE_GAME_OVER:
		selection_info_label.text = "A または B で再挑戦"
		return
	if game_engine.current_phase == GameEngine.Phase.PHASE_GAME_WIN:
		selection_info_label.text = "全敵撃破！ A または B でリスタート"
		return
	
	var cards: Array[CardData] = []
	if not selected_indices.is_empty():
		for idx in selected_indices:
			if idx < game_engine.hand.size():
				cards.append(game_engine.hand[idx])
	elif focused_hand_index >= 0 and focused_hand_index < game_engine.hand.size():
		cards.append(game_engine.hand[focused_hand_index])
	
	if cards.is_empty():
		selection_info_label.text = "カードを選択してください"
		return
	
	var total_val = 0
	var names: Array[String] = []
	for c in cards:
		total_val += c.get_attack_value()
		names.append(c.get_display_name())
	
	var cards_str = ", ".join(names)
	
	if game_engine.current_phase == GameEngine.Phase.PHASE_PLAYER:
		var validation = game_engine.validate_play_selection(cards)
		if validation["valid"]:
			selection_info_label.text = "【出撃】%s (パワー: %d) - %s" % [cards_str, total_val, validation["reason"]]
		else:
			selection_info_label.text = "【選択】%s (パワー: %d) - ⚠️%s" % [cards_str, total_val, validation["reason"]]
	
	elif game_engine.current_phase == GameEngine.Phase.PHASE_ENEMY_COUNTER:
		var req_atk = game_engine.current_enemy_current_atk
		if total_val >= req_atk:
			selection_info_label.text = "【防御可能】%s (防御値: %d / 必要: %d)" % [cards_str, total_val, req_atk]
		else:
			selection_info_label.text = "【防御不足】%s (防御値: %d / 必要: %d)" % [cards_str, total_val, req_atk]

# ==========================================
# ゲームエンジンからのシグナル処理
# ==========================================

func _on_enemy_spawned(enemy: CardData) -> void:
	if enemy:
		enemy_card_view.set_card_data(enemy)
		enemy_card_view.set_immunity_badge_visible(true)
		enemy_name_label.text = "👑 %s of %s" % [enemy.get_rank_name(), enemy.get_suit_name_ja()]
		enemy_name_label.add_theme_color_override("font_color", enemy.get_suit_color())

func _on_enemy_hp_changed(current_hp: int, max_hp: int) -> void:
	enemy_hp_bar.max_value = max_hp
	enemy_hp_bar.value = current_hp
	enemy_hp_label.text = "HP: %d / %d" % [current_hp, max_hp]

func _on_enemy_atk_changed(current_atk: int, base_atk: int, shield: int) -> void:
	if shield > 0:
		enemy_atk_label.text = "ATK: %d (%d - %d)" % [current_atk, base_atk, shield]
		enemy_atk_label.add_theme_color_override("font_color", Color("42a5f5"))
	else:
		enemy_atk_label.text = "ATK: %d" % current_atk
		enemy_atk_label.add_theme_color_override("font_color", Color("ef5350"))

func _on_hand_changed(_hand: Array[CardData]) -> void:
	_update_hand_views()

func _on_deck_counts_changed(tavern_count: int, discard_count: int, castle_count: int) -> void:
	tavern_deck_label.text = "山札: %d" % tavern_count
	discard_pile_label.text = "捨て札: %d" % discard_count
	castle_deck_label.text = "城の敵: %d体" % castle_count

func _on_action_resolved(summary: String) -> void:
	last_action_label.text = summary

func _on_banner_triggered(message: String, banner_type: String) -> void:
	banner_label.text = message
	banner_label.visible = true
	
	match banner_type:
		"exact_kill":
			banner_label.add_theme_color_override("font_color", Color("ffeb3b"))
		"win":
			banner_label.add_theme_color_override("font_color", Color("00e676"))
		"game_over":
			banner_label.add_theme_color_override("font_color", Color("ff1744"))
		_:
			banner_label.add_theme_color_override("font_color", Color.WHITE)
	
	if banner_tween and banner_tween.is_valid():
		banner_tween.kill()
	
	banner_label.modulate.a = 1.0
	banner_label.scale = Vector2(1.2, 1.2)
	
	banner_tween = create_tween().set_parallel(true)
	banner_tween.tween_property(banner_label, "scale", Vector2.ONE, 0.2)
	banner_tween.chain().tween_interval(1.5)
	banner_tween.chain().tween_property(banner_label, "modulate:a", 0.0, 0.4)

func _on_phase_changed(new_phase: GameEngine.Phase) -> void:
	match new_phase:
		GameEngine.Phase.PHASE_PLAYER:
			footer_guide.text = "A: 決定 | X: 選択/解除 | Y: パス | B: 取消 | 十字キー: 移動"
			footer_guide.add_theme_color_override("font_color", Color("81c784"))
		GameEngine.Phase.PHASE_ENEMY_COUNTER:
			footer_guide.text = "【敵の反撃！】敵ATK以上のカードを選択し A: 防御 | X: 選択/解除"
			footer_guide.add_theme_color_override("font_color", Color("ff8a80"))
		GameEngine.Phase.PHASE_GAME_OVER:
			footer_guide.text = "【GAME OVER】A または B ボタンを押してリスタート"
			footer_guide.add_theme_color_override("font_color", Color("e57373"))
		GameEngine.Phase.PHASE_GAME_WIN:
			footer_guide.text = "【VICTORY!!】全12体撃破！ A または B でリスタート"
			footer_guide.add_theme_color_override("font_color", Color("69f0ae"))
	_update_selection_info()

func _on_game_over(reason: String) -> void:
	last_action_label.text = "敗北: %s" % reason

func _on_game_won() -> void:
	last_action_label.text = "すべての城主を討ち果たし完全勝利！"
