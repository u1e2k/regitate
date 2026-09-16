class_name CardData
extends Resource

enum Suit {
	CLUBS,     # ♣ (Club / 緑 or 黒 / 与ダメージ2倍)
	SPADES,    # ♠ (Spade / 青 or 黒 / シールド永続軽減)
	DIAMONDS,  # ♦ (Diamond / 赤 / カードドロー)
	HEARTS     # ♥ (Heart / 赤 / 捨て札回復)
}

@export var suit: Suit = Suit.CLUBS
@export var rank: int = 1 # 1=A, 2..10, 11=J, 12=Q, 13=K
@export var is_enemy: bool = false

func _init(p_suit: Suit = Suit.CLUBS, p_rank: int = 1, p_is_enemy: bool = false) -> void:
	suit = p_suit
	rank = p_rank
	is_enemy = p_is_enemy

## プレイヤーカードとしての攻撃力（または効果値）を取得
func get_attack_value() -> int:
	if rank == 1:
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

## 防御時に捨て札として支払う値（攻撃力と同等）
func get_defense_value() -> int:
	return get_attack_value()

## 敵としての最大HP
func get_enemy_max_hp() -> int:
	match rank:
		11: return 20 # Jack
		12: return 30 # Queen
		13: return 40 # King
		_: return 20

## 敵としての基本攻撃力
func get_enemy_base_attack() -> int:
	match rank:
		11: return 10 # Jack
		12: return 15 # Queen
		13: return 20 # King
		_: return 10

## ランク表示名（A, 2..10, J, Q, K）
func get_rank_name() -> String:
	match rank:
		1: return "A"
		11: return "J"
		12: return "Q"
		13: return "K"
		_: return str(rank)

## スート記号 (♣, ♠, ♦, ♥)
func get_suit_symbol() -> String:
	match suit:
		Suit.CLUBS: return "♣"
		Suit.SPADES: return "♠"
		Suit.DIAMONDS: return "♦"
		Suit.HEARTS: return "♥"
		_: return "?"

## スートの日本語名
func get_suit_name_ja() -> String:
	match suit:
		Suit.CLUBS: return "クラブ"
		Suit.SPADES: return "スペード"
		Suit.DIAMONDS: return "ダイヤ"
		Suit.HEARTS: return "ハート"
		_: return ""

## スート効果の日本語説明
func get_suit_effect_desc() -> String:
	match suit:
		Suit.CLUBS: return "ダメージ2倍"
		Suit.SPADES: return "敵ATK永続軽減"
		Suit.DIAMONDS: return "カードドロー"
		Suit.HEARTS: return "捨て札を山札へ"
		_: return ""

## スートのUI表示色
func get_suit_color() -> Color:
	match suit:
		Suit.CLUBS: return Color("2e7d32")     # エメラルドグリーン系（識別しやすい）
		Suit.SPADES: return Color("2196f3")    # スカイブルー系（視認性の高いシールド色）
		Suit.DIAMONDS: return Color("e53935")  # 明るいレッド
		Suit.HEARTS: return Color("ff5252")    # コーラルレッド
		_: return Color.WHITE

## スートのクラシックカラー（黒/赤）
func get_classic_suit_color() -> Color:
	match suit:
		Suit.CLUBS, Suit.SPADES:
			return Color("212121") # ダークグレー/ブラック
		Suit.DIAMONDS, Suit.HEARTS:
			return Color("d32f2f") # クラシックレッド
		_:
			return Color.BLACK

## 表示用の略称 (例: "♣A", "♥10")
func get_display_name() -> String:
	return "%s%s" % [get_suit_symbol(), get_rank_name()]

func _to_string() -> String:
	return get_display_name()
