class_name CardData
extends Resource

enum Suit {
	CLUBS,     # ♣ (Club / 与ダメージ2倍)
	SPADES,    # ♠ (Spade / 敵ATK永続軽減)
	DIAMONDS,  # ♦ (Diamond / カードドロー)
	HEARTS,    # ♥ (Heart / 捨て札回復)
	JOKER      # 🃏 (Joker / 万能特殊カード)
}

@export var suit: Suit = Suit.CLUBS
@export var rank: int = 1 # 0=Joker, 1=A, 2..10, 11=J, 12=Q, 13=K
@export var is_enemy: bool = false

func _init(p_suit: Suit = Suit.CLUBS, p_rank: int = 1, p_is_enemy: bool = false) -> void:
	suit = p_suit
	rank = p_rank
	is_enemy = p_is_enemy

func is_joker() -> bool:
	return suit == Suit.JOKER or rank == 0

## プレイヤーカードとしての攻撃力（または効果値）を取得
func get_attack_value() -> int:
	if is_joker():
		return 0 # 特殊発動
	elif rank == 1:
		return 1 # Ace
	elif rank >= 2 and rank <= 10:
		return rank
	elif rank == 11: # Jack
		return 10
	elif rank == 12: # Queen
		return 15
	elif rank == 13: # King
		return 20
	return 0

## 防御時に捨て札として支払う値（ジョーカーは緊急防御カードとして敵ATK全吸収可能）
func get_defense_value() -> int:
	if is_joker():
		return 99 # ジョーカー1枚でどんな攻撃も完全防御
	return get_attack_value()

## 敵としての最大HP
func get_enemy_max_hp(difficulty: int = 1) -> int:
	# difficulty: 0=Casual, 1=Normal, 2=Hard
	if difficulty == 0: # Casual
		match rank:
			11: return 15
			12: return 25
			13: return 35
			_: return 15
	else:
		match rank:
			11: return 20 # Jack
			12: return 30 # Queen
			13: return 40 # King
			_: return 20

## 敵としての基本攻撃力
func get_enemy_base_attack(difficulty: int = 1) -> int:
	if difficulty == 0: # Casual
		match rank:
			11: return 8
			12: return 12
			13: return 16
			_: return 8
	else:
		match rank:
			11: return 10 # Jack
			12: return 15 # Queen
			13: return 20 # King
			_: return 10

## ランク表示名（A, 2..10, J, Q, K, 🃏）
func get_rank_name() -> String:
	if is_joker():
		return "★"
	match rank:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_: return str(rank)

## スート記号 (♣, ♠, ♦, ♥, 🃏)
func get_suit_symbol() -> String:
	if is_joker():
		return "🃏"
	match suit:
		Suit.CLUBS: return "♣"
		Suit.SPADES: return "♠"
		Suit.DIAMONDS: return "♦"
		Suit.HEARTS: return "♥"
		_: return "?"

## スートの日本語名
func get_suit_name_ja() -> String:
	if is_joker():
		return "道化師"
	match suit:
		Suit.CLUBS: return "クラブ"
		Suit.SPADES: return "スペード"
		Suit.DIAMONDS: return "ダイヤ"
		Suit.HEARTS: return "ハート"
		_: return ""

## スート効果の日本語説明
func get_suit_effect_desc() -> String:
	if is_joker():
		return "敵耐性無効化 / 完全防御"
	match suit:
		Suit.CLUBS: return "ダメージ2倍"
		Suit.SPADES: return "敵ATK永続軽減"
		Suit.DIAMONDS: return "カードドロー"
		Suit.HEARTS: return "捨て札を山札へ"
		_: return ""

## スートのUI表示色
func get_suit_color() -> Color:
	if is_joker():
		return Color("ab47bc") # パープル
	match suit:
		Suit.CLUBS: return Color("2e7d32")
		Suit.SPADES: return Color("2196f3")
		Suit.DIAMONDS: return Color("e53935")
		Suit.HEARTS: return Color("ff5252")
		_: return Color.WHITE

## スートのクラシックカラー（黒/赤/紫）
func get_classic_suit_color() -> Color:
	if is_joker():
		return Color("7b1fa2") # パープル
	match suit:
		Suit.CLUBS, Suit.SPADES:
			return Color("212121")
		Suit.DIAMONDS, Suit.HEARTS:
			return Color("d32f2f")
		_:
			return Color.BLACK

## 表示用の略称 (例: "♣A", "♥10", "🃏Joker")
func get_display_name() -> String:
	if is_joker():
		return "🃏Joker"
	return "%s%s" % [get_suit_symbol(), get_rank_name()]

func _to_string() -> String:
	return get_display_name()
