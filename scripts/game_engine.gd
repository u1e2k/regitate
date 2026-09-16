class_name GameEngine
extends Node

enum Phase {
	PHASE_PLAYER,         # プレイヤーカードプレイ手番
	PHASE_ENEMY_COUNTER,  # 敵反撃（防御カード廃棄手番）
	PHASE_ENEMY_DEFEATED, # 敵撃破中
	PHASE_GAME_OVER,      # ゲームオーバー
	PHASE_GAME_WIN        # ゲーム勝利（クリア）
}

const MAX_HAND_SIZE: int = 8

# デッキと手札
var castle_deck: Array[CardData] = []
var tavern_deck: Array[CardData] = []
var discard_pile: Array[CardData] = []
var hand: Array[CardData] = []

# 現在の敵ステータス
var current_enemy: CardData = null
var current_enemy_current_hp: int = 0
var current_enemy_max_hp: int = 0
var current_enemy_base_atk: int = 0
var current_enemy_current_atk: int = 0
var current_enemy_shield: int = 0
var is_enemy_immunity_cancelled: bool = false

# 難易度 & フェーズ
var difficulty: GameState.Difficulty = GameState.Difficulty.NORMAL
var current_phase: Phase = Phase.PHASE_PLAYER

# シグナル
signal game_started()
signal enemy_spawned(enemy: CardData)
signal enemy_hp_changed(current_hp: int, max_hp: int)
signal enemy_atk_changed(current_atk: int, base_atk: int, shield: int)
signal hand_changed(hand: Array[CardData])
signal deck_counts_changed(tavern_count: int, discard_count: int, castle_count: int)
signal action_resolved(summary: String)
signal banner_triggered(message: String, banner_type: String)
signal phase_changed(new_phase: Phase)
signal game_over(reason: String)
signal game_won()

## 新しいゲームの初期化と開始
func start_new_game(p_difficulty: GameState.Difficulty = GameState.Difficulty.NORMAL) -> void:
	difficulty = p_difficulty
	castle_deck.clear()
	tavern_deck.clear()
	discard_pile.clear()
	hand.clear()
	current_enemy = null
	
	_build_castle_deck()
	_build_tavern_deck()
	
	# 初期手札8枚ドロー
	draw_cards(MAX_HAND_SIZE)
	
	# 難易度に応じたジョーカーの配布 (Casual/Normalは初期手札にジョーカーを挿入)
	if difficulty != GameState.Difficulty.HARD:
		# ジョーカー2枚
		hand.append(CardData.new(CardData.Suit.JOKER, 0, false))
		hand.append(CardData.new(CardData.Suit.JOKER, 0, false))
		hand_changed.emit(hand)
	
	# 最初の敵をスポーン
	_spawn_next_enemy()
	
	current_phase = Phase.PHASE_PLAYER
	game_started.emit()
	phase_changed.emit(current_phase)
	_notify_deck_counts()

## Castle Deck構築（下から K:4枚 -> Q:4枚 -> J:4枚）
func _build_castle_deck() -> void:
	var kings: Array[CardData] = []
	var queens: Array[CardData] = []
	var jacks: Array[CardData] = []
	
	for suit in [CardData.Suit.CLUBS, CardData.Suit.SPADES, CardData.Suit.DIAMONDS, CardData.Suit.HEARTS]:
		kings.append(CardData.new(suit, 13, true))
		queens.append(CardData.new(suit, 12, true))
		jacks.append(CardData.new(suit, 11, true))
	
	kings.shuffle()
	queens.shuffle()
	jacks.shuffle()
	
	for k in kings:
		castle_deck.append(k)
	for q in queens:
		castle_deck.append(q)
	for j in jacks:
		castle_deck.append(j)

## Tavern Deck構築（A〜10 × 4スート = 40枚）
func _build_tavern_deck() -> void:
	for suit in [CardData.Suit.CLUBS, CardData.Suit.SPADES, CardData.Suit.DIAMONDS, CardData.Suit.HEARTS]:
		for rank in range(1, 11):
			tavern_deck.append(CardData.new(suit, rank, false))
	tavern_deck.shuffle()

## 次の敵を出現させる
func _spawn_next_enemy() -> bool:
	if castle_deck.is_empty():
		return false
	
	current_enemy = castle_deck.pop_back()
	var diff_int = int(difficulty)
	current_enemy_max_hp = current_enemy.get_enemy_max_hp(diff_int)
	current_enemy_current_hp = current_enemy_max_hp
	current_enemy_base_atk = current_enemy.get_enemy_base_attack(diff_int)
	current_enemy_shield = 0
	current_enemy_current_atk = current_enemy_base_atk
	is_enemy_immunity_cancelled = false
	
	enemy_spawned.emit(current_enemy)
	enemy_hp_changed.emit(current_enemy_current_hp, current_enemy_max_hp)
	enemy_atk_changed.emit(current_enemy_current_atk, current_enemy_base_atk, current_enemy_shield)
	_notify_deck_counts()
	return true

## Tavern Deckから指定枚数ドロー（手札上限8枚）
func draw_cards(count: int) -> int:
	var drawn_count = 0
	for i in range(count):
		if hand.size() >= MAX_HAND_SIZE:
			break
		if tavern_deck.is_empty():
			break
		var card = tavern_deck.pop_back()
		hand.append(card)
		drawn_count += 1
	
	if drawn_count > 0:
		hand_changed.emit(hand)
		_notify_deck_counts()
	return drawn_count

## 捨て札をシャッフルしてTavern Deckの底に戻す（ハート効果）
func recharge_deck_from_discard(count: int) -> int:
	if discard_pile.is_empty() or count <= 0:
		return 0
	
	discard_pile.shuffle()
	var move_count = min(count, discard_pile.size())
	for i in range(move_count):
		var card = discard_pile.pop_back()
		tavern_deck.insert(0, card)
	
	_notify_deck_counts()
	return move_count

## デッキ枚数変更通知
func _notify_deck_counts() -> void:
	deck_counts_changed.emit(tavern_deck.size(), discard_pile.size(), castle_deck.size() + (1 if current_enemy != null else 0))

## カードプレイの妥当性バリデーション
func validate_play_selection(cards: Array[CardData]) -> Dictionary:
	if cards.is_empty():
		return {"valid": false, "reason": "カードが選択されていません"}
	
	# ジョーカー単体出し
	if cards.size() == 1 and cards[0].is_joker():
		return {"valid": true, "reason": "道化師: 敵耐性無効化 & 手札リフレッシュ"}
	
	# ジョーカーを含む複数出しは不可
	for c in cards:
		if c.is_joker():
			return {"valid": false, "reason": "道化師(Joker)は単体でプレイしてください"}
	
	# 1枚出し: 常にOK
	if cards.size() == 1:
		return {"valid": true, "reason": "1枚プレイ"}
	
	# 2枚出し: Aとのペア または 同一ランクで合計<=10
	if cards.size() == 2:
		var has_ace = (cards[0].rank == 1 or cards[1].rank == 1)
		if has_ace:
			return {"valid": true, "reason": "相棒(A)とのペアプレイ"}
		if cards[0].rank == cards[1].rank:
			var sum_val = cards[0].get_attack_value() + cards[1].get_attack_value()
			if sum_val <= 10:
				return {"valid": true, "reason": "ペアセットプレイ (合計%d)" % sum_val}
			else:
				return {"valid": false, "reason": "セット出しの合計値は10以下である必要があります (現在%d)" % sum_val}
		return {"valid": false, "reason": "2枚出しはAとのペアか同一ランク(合計<=10)のみ可能です"}
	
	# 3枚以上出し: すべて同じランク かつ 合計値<=10
	var first_rank = cards[0].rank
	var total_sum = 0
	for c in cards:
		if c.rank != first_rank:
			return {"valid": false, "reason": "3枚以上のセット出しはすべて同じ数字である必要があります"}
		total_sum += c.get_attack_value()
	
	if total_sum <= 10:
		return {"valid": true, "reason": "%d枚セットプレイ (合計%d)" % [cards.size(), total_sum]}
	else:
		return {"valid": false, "reason": "セット出しの合計値は10以下である必要があります (現在%d)" % total_sum}

## カードをプレイする
func play_cards(cards: Array[CardData]) -> bool:
	if current_phase != Phase.PHASE_PLAYER:
		return false
	
	var validation = validate_play_selection(cards)
	if not validation["valid"]:
		return false
	
	# 手札からカードを取り除く
	for c in cards:
		hand.erase(c)
	hand_changed.emit(hand)
	
	# ジョーカー特殊効果の発動
	if cards.size() == 1 and cards[0].is_joker():
		discard_pile.append(cards[0])
		is_enemy_immunity_cancelled = true
		banner_triggered.emit("JOKER ACTIVATE!", "exact_kill")
		
		# 手札を最大枚数(8枚)まで全回復ドロー
		var drawn = draw_cards(MAX_HAND_SIZE - hand.size())
		action_resolved.emit("🃏道化師発動！敵の耐性を完全解除 ＆ 山札から%d枚ドロー！" % drawn)
		_notify_deck_counts()
		# ジョーカーは敵の反撃を発生させず、プレイヤーの連続手番
		current_phase = Phase.PHASE_PLAYER
		phase_changed.emit(current_phase)
		return true
	
	# 基本攻撃力合計
	var base_power = 0
	for c in cards:
		base_power += c.get_attack_value()
	
	# スート収集
	var suits_present: Dictionary = {}
	for c in cards:
		suits_present[c.suit] = true
	
	var log_parts: Array[String] = []
	var enemy_suit = current_enemy.suit
	
	# 1. ダイヤ（♦）: ドロー
	if suits_present.has(CardData.Suit.DIAMONDS):
		if enemy_suit == CardData.Suit.DIAMONDS and not is_enemy_immunity_cancelled:
			log_parts.append("♦無効(敵耐性)")
		else:
			var drawn = draw_cards(base_power)
			log_parts.append("♦+%d枚ドロー" % drawn)
	
	# 2. ハート（♥）: 捨て札回復
	if suits_present.has(CardData.Suit.HEARTS):
		if enemy_suit == CardData.Suit.HEARTS and not is_enemy_immunity_cancelled:
			log_parts.append("♥無効(敵耐性)")
		else:
			var recovered = recharge_deck_from_discard(base_power)
			log_parts.append("♥+%d枚回復" % recovered)
	
	# 3. スペード（♠）: シールド
	if suits_present.has(CardData.Suit.SPADES):
		if enemy_suit == CardData.Suit.SPADES and not is_enemy_immunity_cancelled:
			log_parts.append("♠無効(敵耐性)")
		else:
			current_enemy_shield += base_power
			current_enemy_current_atk = max(0, current_enemy_base_atk - current_enemy_shield)
			enemy_atk_changed.emit(current_enemy_current_atk, current_enemy_base_atk, current_enemy_shield)
			log_parts.append("♠-%d 敵ATK" % base_power)
	
	# 4. クラブ（♣） & ダメージ計算
	var damage = base_power
	if suits_present.has(CardData.Suit.CLUBS):
		if enemy_suit == CardData.Suit.CLUBS and not is_enemy_immunity_cancelled:
			log_parts.append("♣無効(敵耐性)")
		else:
			damage = base_power * 2
			log_parts.append("♣x2倍撃")
	
	log_parts.insert(0, "%dダメージ" % damage)
	
	# 敵へダメージ適用
	current_enemy_current_hp -= damage
	action_resolved.emit(" / ".join(log_parts))
	enemy_hp_changed.emit(max(0, current_enemy_current_hp), current_enemy_max_hp)
	
	# 敵の撃破判定
	if current_enemy_current_hp <= 0:
		_handle_enemy_defeat(cards, current_enemy_current_hp == 0)
	else:
		for c in cards:
			discard_pile.append(c)
		_notify_deck_counts()
		
		# 反撃フェーズ
		if current_enemy_current_atk <= 0:
			action_resolved.emit("敵の攻撃力は0！反撃なし")
			current_phase = Phase.PHASE_PLAYER
			phase_changed.emit(current_phase)
		else:
			current_phase = Phase.PHASE_ENEMY_COUNTER
			phase_changed.emit(current_phase)
			_check_defense_possible()
	
	return true

## パス（イールド）
func yield_turn() -> bool:
	if current_phase != Phase.PHASE_PLAYER:
		return false
	
	action_resolved.emit("パスしました（敵の反撃を受けます）")
	if current_enemy_current_atk <= 0:
		action_resolved.emit("敵の攻撃力は0！ダメージなし")
		current_phase = Phase.PHASE_PLAYER
		phase_changed.emit(current_phase)
	else:
		current_phase = Phase.PHASE_ENEMY_COUNTER
		phase_changed.emit(current_phase)
		_check_defense_possible()
	return true

## 敵撃破処理
func _handle_enemy_defeat(played_cards: Array[CardData], is_exact_kill: bool) -> void:
	var defeated_enemy = current_enemy
	
	for c in played_cards:
		discard_pile.append(c)
	
	if is_exact_kill:
		banner_triggered.emit("EXACT KILL!!", "exact_kill")
		defeated_enemy.is_enemy = false
		tavern_deck.push_back(defeated_enemy)
		action_resolved.emit("ぴったり撃破！%s が山札の先頭に加わった！" % defeated_enemy.get_display_name())
	else:
		banner_triggered.emit("DEFEATED!", "kill")
		discard_pile.append(defeated_enemy)
		action_resolved.emit("%s を撃破！" % defeated_enemy.get_display_name())
	
	_notify_deck_counts()
	
	if castle_deck.is_empty():
		current_enemy = null
		current_phase = Phase.PHASE_GAME_WIN
		phase_changed.emit(current_phase)
		banner_triggered.emit("VICTORY!!", "win")
		game_won.emit()
	else:
		_spawn_next_enemy()
		current_phase = Phase.PHASE_PLAYER
		phase_changed.emit(current_phase)

## 防御可能かチェック
func _check_defense_possible() -> void:
	var max_possible_defense = 0
	for c in hand:
		max_possible_defense += c.get_defense_value()
	
	if max_possible_defense < current_enemy_current_atk:
		current_phase = Phase.PHASE_GAME_OVER
		phase_changed.emit(current_phase)
		banner_triggered.emit("GAME OVER", "game_over")
		game_over.emit("手札の合計値(%d)が敵の攻撃力(%d)に足りず力尽きました..." % [max_possible_defense, current_enemy_current_atk])

## 反撃ダメージに対するカード廃棄処理
func discard_for_defense(cards: Array[CardData]) -> Dictionary:
	if current_phase != Phase.PHASE_ENEMY_COUNTER:
		return {"success": false, "reason": "反撃フェーズではありません"}
	
	var total_defense = 0
	var has_joker = false
	for c in cards:
		if c.is_joker():
			has_joker = true
		total_defense += c.get_defense_value()
	
	if total_defense < current_enemy_current_atk:
		return {
			"success": false,
			"reason": "防御値が足りません (選択:%d / 必要:%d)" % [total_defense, current_enemy_current_atk]
		}
	
	for c in cards:
		hand.erase(c)
		discard_pile.append(c)
	
	hand_changed.emit(hand)
	_notify_deck_counts()
	
	if has_joker:
		action_resolved.emit("🃏道化師の奇術！反撃ダメージを完全に無効化！")
	else:
		action_resolved.emit("防御成功！(%dダメージを%d値で吸収)" % [current_enemy_current_atk, total_defense])
	
	current_phase = Phase.PHASE_PLAYER
	phase_changed.emit(current_phase)
	return {"success": true, "reason": "防御成功"}
