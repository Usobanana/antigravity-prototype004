extends GridContainer

# マージ成功時に発行するシグナル。演出用のパーティクル管理ノード等でこれを受け取ります
signal merged(level: int)

# グリッドサイズの設定
const COLS: int = 5
const ROWS: int = 5
const TOTAL_SLOTS: int = COLS * ROWS

# アイテムのデータ構造
# 空きスロットは null で表現します
@export var drag_visual_offset: Vector2 = Vector2(0, -80) # タッチ時の指からのズレ
var items: Array = []

# ドラッグ状態管理
var dragging_slot_index: int = -1
var drag_touch_index: int = -1  # シングルタッチ用
var dragged_visual: Control = null # ドラッグ中に指に追従する仮のUIノード

func _ready() -> void:
	# VBoxContainer内で正方形の高さを強制確保するため、自身の幅(=画面幅)を最小高さに設定する
	resized.connect(_on_resized)
	
	# スロットデータの初期化
	items.resize(TOTAL_SLOTS)
	items.fill(null)
	
	# スロットのUIノード生成（今回はスクリプトから自動生成）
	for i in range(TOTAL_SLOTS):
		var slot = PanelContainer.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
		
		var margin = MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.name = "MarginContainer"
		margin.add_theme_constant_override("margin_left", 4)
		margin.add_theme_constant_override("margin_top", 4)
		margin.add_theme_constant_override("margin_right", 4)
		margin.add_theme_constant_override("margin_bottom", 4)
		slot.add_child(margin)
		
		var bg = ColorRect.new()
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bg.name = "ColorRect"
		bg.color = Color(0.2, 0.2, 0.2, 0.8)
		margin.add_child(bg)
		
		var label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.name = "LevelLabel"
		label.add_theme_font_size_override("font_size", 24)
		bg.add_child(label)
		
		add_child(slot)
	
	# テスト用初期生成は LevelManager からの load_layout() に移行するため削除

func load_layout(layout_array: Array) -> void:
	if layout_array.size() != TOTAL_SLOTS:
		push_error("Invalid layout array size.")
		return
		
	for i in range(TOTAL_SLOTS):
		var val = layout_array[i]
		if val == -1:
			# 障害物
			items[i] = {"level": -1}
		elif val > 0:
			# アイテム
			items[i] = {"level": val}
		else:
			# 空
			items[i] = null
			
		update_slot_visual(i, items[i])

func spawn_order(is_bonus: bool = false) -> bool:
	var empty_slots = []
	for i in range(TOTAL_SLOTS):
		if items[i] == null:
			empty_slots.append(i)
			
	if empty_slots.is_empty():
		return false # 盤面がいっぱい
		
	var target_idx = empty_slots.pick_random()
	
	var new_level = 1
	if is_bonus:
		# ボーナスタイム中は Lv.2 が 60%、Lv.3 が 40%
		new_level = 2 if randf() < 0.6 else 3
	else:
		# 通常時は Lv.1 が 80%、Lv.2 が 20%
		new_level = 1 if randf() < 0.8 else 2
		
	spawn_item(target_idx, new_level)
	return true

func _on_resized() -> void:
	# 自身の横幅(size.x)が変わったとき、VBoxに対して「同じだけの高さが必要」と伝える
	if size.x > 0:
		custom_minimum_size.y = size.x
		# 親の AspectRatioContainer にも伝搬させる
		var parent = get_parent()
		if parent is AspectRatioContainer:
			parent.custom_minimum_size.y = size.x

# スマホのタッチやマウス入力を処理
func _unhandled_input(event: InputEvent) -> void:
	var is_touch_event = event is InputEventScreenTouch
	var is_mouse_event = event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT
	
	if is_touch_event or is_mouse_event:
		var is_pressed = event.is_pressed()
		var touch_index = event.index if is_touch_event else 0  # マウスの場合は0を固定で使う
		var pos = event.position
		
		if is_pressed:
			if dragging_slot_index == -1:
				var slot_idx = get_slot_at_position(pos)
				if slot_idx != -1 and items[slot_idx] != null:
					start_drag(slot_idx, touch_index, pos)
					get_viewport().set_input_as_handled()
		else:
			# マウス離上（またはタッチ終了）
			if dragging_slot_index != -1 and drag_touch_index == touch_index:
				var drop_slot_idx = get_slot_at_position(pos)
				drop_item(drop_slot_idx)
				get_viewport().set_input_as_handled()

	var is_drag_event = event is InputEventScreenDrag
	var is_mouse_motion = event is InputEventMouseMotion
	# マウス追従の場合は左クリックが押されている状態(button_mask)でのみ処理する
	if is_drag_event or (is_mouse_motion and event.button_mask & MOUSE_BUTTON_MASK_LEFT):
		var touch_index = event.index if is_drag_event else 0
		if dragging_slot_index != -1 and drag_touch_index == touch_index:
			if dragged_visual:
				dragged_visual.global_position = event.position - (dragged_visual.size / 2.0)
			get_viewport().set_input_as_handled()

# --- 内部ロジック ---

func get_slot_at_position(global_pos: Vector2) -> int:
	for i in range(get_child_count()):
		var slot_node = get_child(i)
		if slot_node is Control and slot_node.get_global_rect().has_point(global_pos):
			return i
	return -1

func start_drag(slot_idx: int, touch_index: int, pos: Vector2) -> void:
	var item_data = items[slot_idx]
	if item_data.get("level", 0) == -1:
		return # 障害物はドラッグ不可

	dragging_slot_index = slot_idx
	drag_touch_index = touch_index
	
	dragged_visual = create_visual_node(item_data)
	get_tree().root.add_child(dragged_visual)
	dragged_visual.global_position = pos - (dragged_visual.size / 2.0)
	
	# 元のスロットは非表示風に
	update_slot_visual(slot_idx, null)

func drop_item(drop_slot_idx: int) -> void:
	if drop_slot_idx != -1:
		var original_idx = dragging_slot_index
		
		# 同じスロットにドロップ（ただのタップ扱い）
		if drop_slot_idx == original_idx:
			cancel_drag()
		else:
			var source_item = items[original_idx]
			var target_item = items[drop_slot_idx]
			
			if target_item != null and target_item.get("level", 0) == -1:
				# 障害物のスロットにはドロップ不可
				cancel_drag()
			elif target_item == null:
				# 空きスロットへ移動 (500msのクールダウン)
				source_item["cooldown"] = 0.5
				items[drop_slot_idx] = source_item
				items[original_idx] = null
				
				# SE/演出
				var main = get_tree().current_scene
				if main.has_method("play_b_movie_effect"):
					main.play_b_movie_effect("cutin", get_global_mouse_position())
			else:
				if source_item.level == target_item.level:
					# マージ成功
					var new_level = target_item.level + 1
					items[drop_slot_idx] = {"level": new_level, "cooldown": 0.0}
					items[original_idx] = null
					merged.emit(new_level)
					
					# エリアダメージ(マージバースト)を発生させる
					var main = get_tree().current_scene
					if main.has_method("trigger_merge_burst"):
						var drop_pos = get_child(drop_slot_idx).global_position + (get_child(drop_slot_idx).size / 2.0)
						main.trigger_merge_burst(drop_pos, new_level)
				else:
					# レベルが違う場合は場所を入れ替え (両方に500msのクールダウン)
					source_item["cooldown"] = 0.5
					target_item["cooldown"] = 0.5
					
					items[drop_slot_idx] = source_item
					items[original_idx] = target_item
					
					# SE/演出
					var main = get_tree().current_scene
					if main.has_method("play_b_movie_effect"):
						main.play_b_movie_effect("cutin", get_global_mouse_position())
					
			update_slot_visual(original_idx, items[original_idx])
			update_slot_visual(drop_slot_idx, items[drop_slot_idx])
	else:
		# ゴミ箱エリアでドロップされたかの判定
		var is_trashed = false
		var main = get_tree().current_scene
		var trash_cans = get_tree().get_nodes_in_group("trash_can")
		for tc in trash_cans:
			if tc is Control and tc.get_global_rect().has_point(get_global_mouse_position()):
				is_trashed = true
				break
				
		if is_trashed:
			# アイテム削除処理
			items[dragging_slot_index] = null
			if main.has_method("play_b_movie_effect"):
				main.play_b_movie_effect("trash_shredder", get_global_mouse_position())
			update_slot_visual(dragging_slot_index, null)
		else:
			cancel_drag()
		
	dragging_slot_index = -1
	drag_touch_index = -1
	
	cleanup_drag()

func cancel_drag() -> void:
	update_slot_visual(dragging_slot_index, items[dragging_slot_index])

func cleanup_drag() -> void:
	if dragged_visual:
		dragged_visual.queue_free()
		dragged_visual = null
		
	dragging_slot_index = -1
	drag_touch_index = -1
	
	# 全スロットの表示を更新
	for i in range(TOTAL_SLOTS):
		update_slot_visual(i, items[i])

func _process(delta: float) -> void:
	if dragged_visual and is_instance_valid(dragged_visual):
		var target_pos = get_viewport().get_mouse_position() + drag_visual_offset
		dragged_visual.global_position = dragged_visual.global_position.lerp(target_pos - (dragged_visual.size / 2.0), 25.0 * delta)
		
	# クールダウンの更新
	for i in range(TOTAL_SLOTS):
		var item = items[i]
		if item != null and item.has("cooldown") and item.cooldown > 0:
			item.cooldown -= delta
			if item.cooldown <= 0:
				item.cooldown = 0
			update_slot_visual(i, item)

# --- ヘルパー関数 ---

func spawn_item(idx: int, level: int) -> void:
	items[idx] = {"level": level}
	update_slot_visual(idx, items[idx])

func update_slot_visual(idx: int, item_data: Variant) -> void:
	var slot_node = get_child(idx)
	var label = slot_node.get_node(^"MarginContainer/ColorRect/LevelLabel") as Label
	var bg = slot_node.get_node(^"MarginContainer/ColorRect") as ColorRect
	
	if item_data != null:
		if item_data.get("level", 0) == -1: # 障害物
			label.text = "X"
			label.add_theme_color_override("font_color", Color.BLACK)
			slot_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			bg.color = Color(0.4, 0.4, 0.4, 1.0)
		else: # 通常アイテム
			label.text = "Lv." + str(item_data.level)
			if label.has_theme_color_override("font_color"):
				label.remove_theme_color_override("font_color")
			
			if item_data.get("cooldown", 0.0) > 0:
				slot_node.modulate = Color(0.3, 0.3, 0.3, 1.0) # クールダウン中は暗くする
			else:
				slot_node.modulate = Color(1.0, 1.0, 1.0, 1.0)
			
			# レベルごとに色を少し変える
			var hue = fmod(item_data.level * 0.15, 1.0)
			bg.color = Color.from_hsv(hue, 0.8, 0.6)
	else:
		label.text = ""
		bg.color = Color(0.2, 0.2, 0.2, 0.5)

func create_visual_node(item_data: Dictionary) -> Control:
	var visual = ColorRect.new()
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var base_slot = get_child(0)
	visual.size = base_slot.size
	
	var hue = fmod(item_data.level * 0.15, 1.0)
	visual.color = Color.from_hsv(hue, 0.8, 0.6)
	
	var label = Label.new()
	label.text = "Lv." + str(item_data.level)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("font_size", 24)
	visual.add_child(label)
	
	# ドラッグ中であることを強調
	visual.modulate = Color(1.2, 1.2, 1.2, 0.9)
	return visual
