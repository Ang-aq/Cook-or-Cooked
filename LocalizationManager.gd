extends Node

<<<<<<< HEAD
var current_language: String = "jp" # en or jp
# testing
=======
var current_language: String = "en" # en or jp

>>>>>>> 0f522c9 (images for readme)
var translations: Dictionary = {
	"en": {
		# Gamemodes
		"Solo": "Solo",
		"Versus": "Versus",
		"Infinite": "Infinite",
		
		"intro_1": "Oh hello, you must be the chef's new apprentice!",
		"intro_2": "I work here too. I'll teach you the basics of this place.",
		"intro_3": "First is to collect ingredients. Look, there's one now!",
		"instruction": "Use the JOYSTICK to chop ingredients then press the BLUE BUTTON to confirm.",
		"reset":"If you mess up press the RED BUTTON to reset.",
		"wrong_input": "Wrong input, try again!",
		"success": "Perfect!! You're a natural!",
		"lives": "These are your lives. Make mistakes, lose hearts!",
		"timer": "This is the timer. Finish your dish before the time runs out!",
		"checklist": "This is your ingredient checklist. Remember, follow the recipe!",
		"pests": "Also be careful of pests that like to steal your food or mess you up! If you see any, make sure to swat them away.",
		
		# Tutorial Dialogue (Infinite Mode)
		"tutorial_1": "Hey you! Come here, quickly!",
		"tutorial_2": "It's RUSH HOUR and the line of customers seems endless!",
		"tutorial_3": "We need the dishes done as soon as possible. Here I'll teach you the basics.",
		"tutorial_4": "Chop ingredients by entering their combos using the BLUE JOYSTICK.",
		"tutorial_5": "Then press the RED BUTTON to enter the combo and the BLUE BUTTON to reset!",
		
		# Skip label
		"skip_tutorial": "     Press to skip",
		
		# Ingredients
		"Spring Onion": "Spring Onion",
		"Scallion": "Scallion",
		"Meat": "Meat",
		"Octopus": "Octopus",
		"Egg": "Egg",
		"Flour": "Flour",
		"Potato": "Potato",
		"Carrot": "Carrot",
		"Onion": "Onion",
		"Tomato": "Tomato",
		"GreenBean": "Green Bean",
		"Hotdog": "Hotdog",
		"Rice": "Rice",
		"Shrimp": "Shrimp",

		# Dishes
		"Beef Yakitori": "Beef Yakitori",
		"Yakitori": "Yakitori",
		"Takoyaki": "Takoyaki",
		"Beef Curry": "Beef Curry",
		"Sinigang!?": "Sinigang!?",
		"Shiba Showdown": "Shiba Showdown",
		"Shrimp Curry": "Shrimp Curry",
		"Bento!": "Bento!",

		# Labels and Gameplay UI
		"Dishes Made": "Dishes Made",
		"%dx Combo!": "%dx Combo!",
		"Continue": "Press the BLUE BUTTON to continue",
		
		# Countdown
		"GO!": "GO!",
		"time_60_left": "60 seconds left!",
		"time_30_left": "30 seconds left!",
		"time_10_left": "10 seconds left!",
		"time_5_left": "5 seconds left!",

		# Popup Messages
		"Dish Stolen!": "Dish Stolen!",
		"No dishes to steal!": "No dishes to steal!",
		"+1 Heart!": "+1 Heart!",
		"-1 Heart!": "-1 Heart!",
		"Wrong combo!": "Wrong combo!",
		"Missed %s!": "Missed %s!",
		"Too many %ss!": "Too many %ss!",
		"Slow Down!": "Slow Down!",
		"Combo Boost!": "Combo Boost!",
		"Extra Heart!": "Extra Heart!",
		"Collected %s": "Collected %s",
		"Score: %d": "Score: %d",
		
	},

	"jp": {
		# Gamemodes
		"Solo": "ソロ",
		"Versus": "バーサス",
		"Infinite": "インフィニット",
		
		# main tutorial
		"intro_1": "こんにちは！あなたが新しい見習いシェフですね！",
		"intro_2": "私もここで働いています。このお店の基本を教えてあげますね。",
		"intro_3": "まずは食材を集めましょう。ほら、あそこにあります！",
		"instruction": "ジョイスティックで食材を切り、青ボタンで決定。",
		"reset": "間違えたら赤ボタンでリセット。",
		"wrong_input": "入力が間違っています。もう一度試してください！",
		"success": "完璧です！あなたは天才ですね！",
		"lives": "これはあなたのライフです。ミスをするとハートを失います！",
		"timer": "これはタイマーです。時間内に料理を完成させてください！",
		"checklist": "これは食材のチェックリストです。レシピ通りに作りましょう！",
		"pests": "害虫に注意！見つけたら叩こう！",
		
		# Tutorial Infinite Mode
		"tutorial_1": "おい君！ こっちに来て！",
		"tutorial_2": "今はラッシュアワーだ！お客さんの列が途切れない！",
		"tutorial_3": "できるだけ早く料理を仕上げなきゃ。基本を教えるぞ！",
		"tutorial_4": "青いジョイスティックでコンボを入力して材料を切るんだ！",
		"tutorial_5": "赤いボタンでコンボを確定、青いボタンでリセットだ！",

		# Skip label
		"skip_tutorial": "スキップ",

		# Ingredients
		"Spring Onion": "ねぎ",
		"Scallion": "ねぎ",
		"Meat": "肉",
		"Octopus": "タコ",
		"Egg": "たまご",
		"Flour": "こむぎこ",
		"Potato": "じゃがいも",
		"Carrot": "にんじん",
		"Onion": "たまねぎ",
		"Tomato": "トマト",
		"GreenBean": "いんげん",
		"Hotdog": "ホットドッグ",
		"Rice": "ごはん",
		"Shrimp": "えび",

		# Dishes
		"Beef Yakitori": "牛焼き鳥",
		"Yakitori": "焼き鳥",
		"Takoyaki": "たこ焼き",
		"Beef Curry": "ビーフカレー",
		"Sinigang!?": "シニガン！？",
		"Shiba Showdown": "シバ対決",
		"Shrimp Curry": "えびカレー",
		"Bento!": "弁当！",

		# Labels and Gameplay UI
		"Dishes Made": "作った料理",
		"%dx Combo!": "%d倍コンボ！",
		"Continue": "青いボタンを押して続ける",

		# Countdown
		"GO!": "スタート！",
		"time_60_left": "あと60秒！",
		"time_30_left": "あと30秒！",
		"time_10_left": "あと10秒！",
		"time_5_left": "あと5秒！",

		# Messages and Effects
		"Dish Stolen!": "料理を盗まれた！",
		"No dishes to steal!": "盗む料理がない！",
		"+1 Heart!": "ハート＋１！",
		"-1 Heart!": "ハート−１！",
		"Wrong combo!": "コンボが違う！",
		"Missed %s!": "%sを逃した！",
		"Too many %ss!": "%sが多すぎる！",
		"Slow Down!": "スロー！",
		"Combo Boost!": "コンボブースト！",
		"Extra Heart!": "エクストラハート！",
		"Collected %s": "集めた%s",
		"Score: %d": "スコア: %d"
	}
}

var fonts: Dictionary = {
	"en": preload("res://Fonts/CutePixel.ttf"),
	"jp": preload("res://Fonts/DotGothic16-Regular.ttf")
}

func t(key: String) -> String:
	if translations.has(current_language) and translations[current_language].has(key):
		return translations[current_language][key]
	return key

func get_font() -> Font:
	if fonts.has(current_language):
		return fonts[current_language]
	return null

func t_dynamic(key: String) -> String:
	return t(key)
