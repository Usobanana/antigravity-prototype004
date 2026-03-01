# 開発引継ぎ用マスタードキュメント (README_DEVELOPMENT.md)

このドキュメントは、現在のセッションまでの開発進捗、システムアーキテクチャ、および設計仕様を完全に網羅し、新しいAIセッションでの開発再開をスムーズに行うための引継ぎ資料です。

---

## 1. プロジェクト概要 ＆ ビジョン
* **ゲームジャンル**: マージパズル ＋ タワーディフェンス
* **テーマとアートスタイル**: 80年代 B級ホラー映画風、フィルムのザラついた質感、ネオンカラーのアクセント、黒背景。
* **UIデザイン**: 「KILL BILL（キル・ビル）」風のビビッドな差し色（黄色背景に黒文字など）を取り入れた過激でスタイリッシュなデザイン。
* **コアループ**:
  1. 「拠点（HomeScene）」でのデッキ編成と強化（ガチャ、アップグレード、シールドリチャージ）。
  2. 「バトル（Main.tscn）」でのマージパズルによる武器レベルアップと迫りくるゾンビの迎撃。
  3. 稼いだコインでさらなる強化を繰り返すサイクル。

---

## 2. 現在のシステム構成 (Tech Stack)
### 主なフレームワークと基盤
* **エンジン**: Godot Engine 4.3 (GDScript)
* **描画システム**: `CanvasItem._draw()` によるプロシージャル描画から、AI生成画像アセット (`TextureRect` ＋ `res://assets/weapons/` 内のPNG) へ移行完了。

### 主要シーン構造
* **`Main.tscn` (バトルエリア)**
  * `GridManager` (盤面管理、マージ処理)
  * `EnemyManager` (ゾンビ生成、移動ライン管理)
  * `LevelManager` (ステージ構成、オーダー生成とレベル進行)
* **`HomeScene.tscn` (拠点エリア)**
  * 上部のヘッダーUI（コイン、スタミナ表示）とヒロインのカットイン。
  * `ScrollContainer` によるスワイプ可能な「HOME」「DECK」「SHOP」「FIGHT」の4画面分割。
  * 下部固定ナビゲーションバーによる画面即時切り替え。

### Autoload (Singleton)
* **`SaveManager.gd`**: ゲーム進捗の保存・読み込み。JSONを利用し、将来的な暗号化を見据えたラッパー。
* **`AudioManager.gd`**: BGM、銃声、マージ音、各種UI効果音のグローバル管理。
* **`SceneManager.gd`**: トランジション（フェードイン・フェードアウト等）を伴うシーン間の遷移を担当。

---

## 3. 実装済み機能リスト (これまでの歩み)
* **9x9 グリッドパズル**: 81マスの盤面への拡張と、隣接または同一スロット間でのドラッグ＆ドロップマージ機能。
* **武器デッキ ＆ インベントリ（倉庫）**:
  * 最大40スロットの倉庫。同一武器の複数スタック所持システム。
  * 最大5枠の出撃用装備「EQUIPPED DECK」。重複装備不可。
  * 倉庫からデッキへのドラッグによる装備、およびタップによる解除（所持数の増減連動、配列の自動左詰めソート）。
* **スワイプUI遷移**: `HomeScene` において、`is_dragging_scroll` を解析したネイティブに近い横スワイプ操作と、メニューボタンとの共存。
* **シールド（ライフ）システム**: ゾンビが防衛ラインに到達した際、即ゲームオーバーにならず、シールドを消費して耐える仕様。UI上での5段階の視覚的ピップメーターと、コインによる+1回復処理。
* **ペナルティシステム**: 出撃用デッキの枠を埋めずにバトルを開始した場合、空き枠の代わりに「木箱（Wooden Box）」がマージ候補として降ってくる（攻撃能力なしのお邪魔ブロック）。
* **ダイナーの修理**: 拠点の看板を修理（アップグレード）することで、スタミナの最大値が上昇するシステム。

---

## 4. データ構造 ＆ 定数定義
### Weapon ID (Type) 定義
* `Type 1`: Pistol (ピストル / 初期装備・解除不可)
* `Type 2`: Shotgun (ショットガン)
* `Type 3`: Chainsaw (チェーンソー)
* `Type 4`: Shield (シールド / 防衛用アイテム)
* `Type 5`: SMG (サブマシンガン / テスト実装済み)
* `Type 99`: Wooden Box (木製ボックス / 空き枠ペナルティ用)

### `SaveManager` の主要キーフォーマット
```gdscript
{
  "coins": 3000,
  "top_stage": 1,
  "stamina": 10,            # 現在のスタミナ
  "sign_upgrade_level": 0,  # MAXスタミナ上昇値 (最大+5)
  "current_shield": 5,      # 現在のシールド耐久値
  "shield_level": 4,        # 最大シールドキャップの拡張値 (初期1 + 拡張分)
  "equipped_weapons": [1, 5, 0, 0, 0], # 5枠の装備配列 (0は空き枠)
  "weapon_inventory": {     # インベントリ内の武器所持数辞書
    "1": 99, 
    "5": 5 
  },
  "weapon_base_levels": {   # 武器ごとの基礎排出レベル
    "1": 1, "2": 1, "3": 1, "4": 1, "5": 1
  }
}
```

### 画像アセット規格
`res://assets/weapons/` ディレクトリ内に配置。
全て `128x128` ピクセルのPNG画像。透過背景ではなく、ゲームの雰囲気に合わせた**純黒背景**を採用。UIの `TextureRect` にて描画。

---

## 5. 次回セッションでの直近タスク
新しいセッションでは、以下の要素の着手・検討を推奨します。

1. **武器ごとの特殊攻撃ロジックの実装**:
   * 現在の連射ロジックや範囲ダメージを、武器種別 (1~5) ごとに細かく差別化する（例：SMGは低威力だが超高速連射、ショットガンは扇状の散弾、チェーンソーは近接貫通ダメージなど）。
2. **ShopTab（プレミアムショップ）の本格実装**:
   * ガチャ機能の実装、またはコインでの武器「購入・アンロック」処理の拡充。
3. **敵（ゾンビ）の多様化と挙動拡張**:
   * 足の速いゾンビ、耐久力が高い大型ゾンビなど、複数の種類を追加してWaveに変化を持たせる。
4. **エフェクトポリッシュ**:
   * ダメージテキストのポップアップ（Damage Numbers）やマージ時のパーティクルをより派手なB級映画風の血しぶき（ピクセルアート）に変更。

---

## 6. プロジェクト全体の重要なコード断片 (Reference)

### `GridManager.gd` - スポーン処理 (ペナルティ判定)
```gdscript
func spawn_order(new_items: Array) -> void:
	# ... (スタミナ判定など省略) ...
	for i in range(new_items.size()):
		var col = new_items[i]
		
		# デッキからランダムな枠を選ぶ
		var equipped = SaveDataManager.get_val("equipped_weapons")
		if typeof(equipped) != TYPE_ARRAY or equipped.size() < 5:
			equipped = [1, 0, 0, 0, 0]
			
		var weapon_type = int(equipped.pick_random())
		# 空き枠が選ばれたら木箱ペナルティ
		if weapon_type == 0:
			weapon_type = 99 
		
		var base_levels = SaveDataManager.get_val("weapon_base_levels")
		var base_level = 1
		if weapon_type != 99:
			base_level = int(base_levels.get(str(weapon_type), 1))
		
		var item = {
			"type": weapon_type,
			"level": base_level,
			"damage": base_level * 10 if weapon_type != 99 else 0
		}
		# ... (描画・アニメーション処理) ...
```

### `HomeScene.gd` - インベントリからの装備処理抜粋
```gdscript
func _handle_drop(pos: Vector2) -> void:
	for i in range(5):
		var slot = equip_slots[i]
		var panel = slot.get_parent() as Control
		if panel.get_global_rect().has_point(pos):
			if i == 0: break # 左端（ピストル）はロック済み
			
			var equipped = SaveDataManager.get_val("equipped_weapons")
			var inventory = SaveDataManager.get_val("weapon_inventory")
			var old_type = equipped[i]
			
			# 重複チェックロジック...
			# ...
			
			if not is_duplicate:
				var str_drag = str(dragging_weapon_type)
				if int(inventory.get(str_drag, 0)) > 0:
					# インベントリから消費
					inventory[str_drag] = int(inventory[str_drag]) - 1
					# 古い武器を返却
					if old_type != 0:
						var str_old = str(old_type)
						inventory[str_old] = int(inventory.get(str_old, 0)) + 1
						
					equipped[i] = dragging_weapon_type
					
					# 自動で左詰めにする処理
					var packed = []
					for w in equipped:
						if w != 0: packed.append(w)
					while packed.size() < 5: packed.append(0)
					equipped = packed
					
					SaveDataManager.set_val("weapon_inventory", inventory)
					SaveDataManager.set_val("equipped_weapons", equipped)
					update_ui()
			break
```

---
*Created by Antigravity AI for seamless session handoff.*
