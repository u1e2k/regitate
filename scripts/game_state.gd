extends Node

enum Difficulty {
	CASUAL,
	NORMAL,
	HARD
}

var current_difficulty: Difficulty = Difficulty.NORMAL

func get_difficulty_name(diff: Difficulty = current_difficulty) -> String:
	match diff:
		Difficulty.CASUAL: return "カジュアル (Casual)"
		Difficulty.NORMAL: return "ノーマル (Normal)"
		Difficulty.HARD: return "ハード (Hard)"
		_: return "ノーマル"

func get_difficulty_desc(diff: Difficulty = current_difficulty) -> String:
	match diff:
		Difficulty.CASUAL: return "ジョーカー2枚所持 / 敵HP・ATK軽減 (初心者向け)"
		Difficulty.NORMAL: return "ジョーカー2枚所持 / 公式標準ステータス (おすすめ)"
		Difficulty.HARD: return "ジョーカーなし / 公式標準ステータス (上級者向け)"
		_: return ""
