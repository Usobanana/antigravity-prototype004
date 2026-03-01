extends Node

const SAVE_PATH = "user://antigravity_save.dat"
# パスワードはここで自由に変更可能です
const SECRET_KEY = "MySuperSecretKey_ChangeThis_12345"

var data: Dictionary = {
	"coins": 0,
	"top_stage": 1,
	"stamina": 10,
	"equipped_weapons": [1, 0, 0, 0, 0], # 0は空き枠
	"weapon_inventory": {"1": 99, "5": 5}, # 所持している武器の種類と個数
	"weapon_base_levels": {
		"1": 1, "2": 1, "3": 1, "4": 1, "5": 1
	},
	"shield_level": 0, # 防弾チョッキのLv
	"current_shield": 1 # 現在の残りシールド
}

func _ready() -> void:
	load_game()

func save_game() -> void:
	# 暗号化してファイルを書き込む
	var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.WRITE, SECRET_KEY)
	if file:
		var json_string = JSON.stringify(data)
		file.store_string(json_string)
		file.close()
		print("--- Save file written successfully! ---")
	else:
		push_error("Failed to open save file for writing.")

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found. Creating a new one.")
		save_game()
		return
		
	# 暗号化ファイルの読み込み
	var file = FileAccess.open_encrypted_with_pass(SAVE_PATH, FileAccess.READ, SECRET_KEY)
	if file:
		var content = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(content)
		if error == OK:
			var saved_data = json.data
			if typeof(saved_data) == TYPE_DICTIONARY:
				# 既存のキーを結合して最新の仕様に合わせる
				for key in saved_data.keys():
					data[key] = saved_data[key]
				print("--- Save file loaded successfully! ---")
			else:
				push_error("Save data is not a dictionary.")
		else:
			push_error("JSON Parse Error: ", json.get_error_message())
	else:
		push_error("Failed to open save file for reading. (Perhaps wrong key?)")

# --- 便利関数 ---

func set_val(key: String, val: Variant) -> void:
	data[key] = val
	save_game()

func get_val(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)
