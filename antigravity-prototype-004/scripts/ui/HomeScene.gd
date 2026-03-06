# HomeScene.gd
extends Control

@onready var coins_label = $VBoxContainer/TopPanel/HBoxContainer/CoinsLabel
@onready var stamina_label = $VBoxContainer/TopPanel/HBoxContainer/StaminaLabel
@onready var content_area = $VBoxContainer/ContentArea
@onready var tab_box = $VBoxContainer/ContentArea/TabBox
@onready var home_tab = $VBoxContainer/ContentArea/TabBox/HomeTab
@onready var deck_tab = $VBoxContainer/ContentArea/TabBox/DeckTab
@onready var shop_tab = $VBoxContainer/ContentArea/TabBox/ShopTab
@onready var fight_tab = $VBoxContainer/ContentArea/TabBox/FightTab

@onready var stage_label = $VBoxContainer/ContentArea/TabBox/FightTab/StageLabel
@onready var start_button = $VBoxContainer/ContentArea/TabBox/FightTab/StartButton

@onready var nav_home = $VBoxContainer/BottomNavBg/BottomNav/NavHome
@onready var nav_deck = $VBoxContainer/BottomNavBg/BottomNav/NavDeck
@onready var nav_shop = $VBoxContainer/BottomNavBg/BottomNav/NavShop
@onready var nav_fight = $VBoxContainer/BottomNavBg/BottomNav/NavFight

# Removed repair_button
var buy_shield_button: Button
var heroine_speech: Label

var deck_vbox: VBoxContainer
var shield_pips_hbox: HBoxContainer

var displayed_coins: float = 0.0
var coin_tween: Tween

var current_tab_index: int = 0
var is_dragging_scroll: bool = false
var scroll_tween: Tween
var drag_start_x: float = 0.0
var drag_start_scroll: float = 0.0

var equip_slots: Array[TextureRect] = []
var warehouse_grid: GridContainer

var upgrade_panel: VBoxContainer
var upgrade_weapon_label: Label
var upgrade_weapon_btn: Button
var selected_weapon_for_upgrade: int = -1

var dragging_weapon_type: int = 0
var drag_preview: TextureRect = null
var shop_items_vbox: VBoxContainer

func _ready() -> void:
	content_area.get_h_scroll_bar().hide()
	content_area.get_v_scroll_bar().hide()
	
	content_area.resized.connect(_setup_tab_sizes)
	call_deferred("_setup_tab_sizes")
	
	_setup_diner_upgrades()
	_setup_heroine()
	
	nav_home.pressed.connect(func(): _on_tab_pressed(0))
	nav_deck.pressed.connect(func(): _on_tab_pressed(1))
	nav_shop.pressed.connect(func(): _on_tab_pressed(2))
	nav_fight.pressed.connect(func(): _on_tab_pressed(3))
	
	_on_tab_pressed(0) # Default to HOME
	
	update_ui()
	start_button.pressed.connect(_on_start_pressed)

func _setup_tab_sizes() -> void:
	for tab in [home_tab, deck_tab, shop_tab, fight_tab]:
		tab.custom_minimum_size.x = content_area.size.x

func _on_tab_pressed(index: int) -> void:
	current_tab_index = index
	
	if scroll_tween and scroll_tween.is_valid():
		scroll_tween.kill()
		
	var target_scroll = index * content_area.size.x
	scroll_tween = create_tween()
	scroll_tween.tween_property(content_area, "scroll_horizontal", int(target_scroll), 0.3)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	_update_nav_buttons(index)

func _update_nav_buttons(index: int) -> void:
	# リセットと選択タブのハイライト
	for btn in [nav_home, nav_deck, nav_shop, nav_fight]:
		btn.add_theme_color_override("font_color", Color(0, 0, 0, 1))
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 0.8, 0, 1) # 黄色ベース
		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)
		
	var selected_btn: Button
	match index:
		0: selected_btn = nav_home
		1: selected_btn = nav_deck
		2: selected_btn = nav_shop
		3: selected_btn = nav_fight
			
	if selected_btn:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 1) # 白背景でハイライト
		selected_btn.add_theme_stylebox_override("normal", style)
		selected_btn.add_theme_stylebox_override("hover", style)
		selected_btn.add_theme_stylebox_override("pressed", style)

func _setup_diner_upgrades() -> void:
	# Removed DINER UPGRADE
	
	var shop_vbox = VBoxContainer.new()
	shop_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shop_vbox.add_theme_constant_override("separation", 10)
	
	var shop_title = Label.new()
	shop_title.text = "- BLACK MARKET -"
	shop_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_title.add_theme_font_size_override("font_size", 24)
	shop_vbox.add_child(shop_title)
	
	# We will dynamically populate this in update_ui, but let's create a container for the items
	shop_items_vbox = VBoxContainer.new()
	shop_items_vbox.add_theme_constant_override("separation", 15)
	shop_items_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	shop_vbox.add_child(shop_items_vbox)
	
	shop_tab.add_child(shop_vbox)
	
	_setup_weapon_deck_ui()

func _setup_weapon_deck_ui() -> void:
	deck_vbox = VBoxContainer.new()
	deck_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	deck_vbox.add_theme_constant_override("separation", 10)
	
	# 1. シールド管理UI
	var shield_hbox = HBoxContainer.new()
	shield_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	shield_hbox.add_theme_constant_override("separation", 20)
	deck_vbox.add_child(shield_hbox)
	
	var shield_title = Label.new()
	shield_title.text = "SHIELD"
	shield_title.add_theme_font_size_override("font_size", 20)
	shield_hbox.add_child(shield_title)
	
	shield_pips_hbox = HBoxContainer.new()
	shield_pips_hbox.add_theme_constant_override("separation", 5)
	shield_pips_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	for i in range(5):
		var pip = ColorRect.new()
		pip.custom_minimum_size = Vector2(20, 20)
		pip.color = Color(0.2, 0.2, 0.2)
		shield_pips_hbox.add_child(pip)
	shield_hbox.add_child(shield_pips_hbox)
	
	buy_shield_button = Button.new()
	buy_shield_button.text = "+1" # Updated dynamically
	buy_shield_button.custom_minimum_size = Vector2(80, 50)
	buy_shield_button.add_theme_font_size_override("font_size", 20)
	buy_shield_button.pressed.connect(_on_buy_shield_pressed)
	shield_hbox.add_child(buy_shield_button)
	
	# 2. EQUIPPED DECK
	var equip_title = Label.new()
	equip_title.text = "- EQUIPPED DECK -"
	equip_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_vbox.add_child(equip_title)
	
	var equip_hbox = HBoxContainer.new()
	equip_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	equip_hbox.add_theme_constant_override("separation", 10)
	deck_vbox.add_child(equip_hbox)
	
	for i in range(5):
		var slot = TextureRect.new()
		slot.custom_minimum_size = Vector2(80, 80)
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		
		var panel = PanelContainer.new()
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2)
		panel.add_theme_stylebox_override("panel", style)
		
		# NONE Label for empty slots
		var none_label = Label.new()
		none_label.name = "NoneLabel"
		none_label.text = "NONE"
		none_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		none_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		none_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		none_label.add_theme_font_size_override("font_size", 14)
		panel.add_child(none_label)
		
		slot.mouse_filter = Control.MOUSE_FILTER_PASS
		slot.gui_input.connect(_on_equip_slot_gui_input.bind(i))
		
		panel.add_child(slot)
		equip_hbox.add_child(panel)
		equip_slots.append(slot)
		
	var wh_title = Label.new()
	wh_title.text = "- WAREHOUSE -"
	wh_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	deck_vbox.add_child(wh_title)
	
	warehouse_grid = GridContainer.new()
	warehouse_grid.columns = 5
	warehouse_grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	warehouse_grid.add_theme_constant_override("h_separation", 10)
	warehouse_grid.add_theme_constant_override("v_separation", 10)
	deck_vbox.add_child(warehouse_grid)
	
	var instruct = Label.new()
	instruct.text = "(Drag Item to Equip or Tap to Uninstall)"
	instruct.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruct.add_theme_font_size_override("font_size", 14)
	deck_vbox.add_child(instruct)
	
	# Upgrade Panel
	upgrade_panel = VBoxContainer.new()
	upgrade_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	upgrade_panel.hide()
	
	upgrade_weapon_label = Label.new()
	upgrade_weapon_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upgrade_panel.add_child(upgrade_weapon_label)
	
	upgrade_weapon_btn = Button.new()
	upgrade_weapon_btn.custom_minimum_size = Vector2(240, 50)
	upgrade_weapon_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	upgrade_weapon_btn.pressed.connect(_on_upgrade_selected_weapon)
	upgrade_panel.add_child(upgrade_weapon_btn)
	
	deck_vbox.add_child(upgrade_panel)
	# Remove old shield hbox block from bottom
	deck_tab.add_child(deck_vbox)

func _get_weapon_texture(w_type: int) -> Texture2D:
	match w_type:
		1: return preload("res://assets/weapons/pistol.png")
		2: return preload("res://assets/weapons/shotgun.png")
		3: return preload("res://assets/weapons/chainsaw.png")
		4: return preload("res://assets/weapons/shield.png")
		5: return preload("res://assets/weapons/smg.png")
		99: return preload("res://assets/weapons/wood_box.png")
		_: return preload("res://icon.svg")

func _setup_heroine() -> void:
	# HOMEタブの VBox 上などに配置したいので、別途 MarginBox を作るか Home_vbox のさらに上に配置する
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var heroine_tex = TextureRect.new()
	heroine_tex.texture = load("res://icon.svg")
	heroine_tex.custom_minimum_size = Vector2(128, 128)
	
	# インタラクション用にマウスフィルタを設定
	heroine_tex.mouse_filter = Control.MOUSE_FILTER_STOP
	heroine_tex.gui_input.connect(_on_heroine_gui_input)
	
	heroine_speech = Label.new()
	heroine_speech.text = "Hey! ゾンビを片付けてきて!"
	heroine_speech.add_theme_font_size_override("font_size", 24)
	heroine_speech.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heroine_speech.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	heroine_speech.position = Vector2(0, 140) # 下にずらす
	heroine_speech.modulate.a = 0.0
	
	heroine_tex.add_child(heroine_speech)
	center.add_child(heroine_tex)
	home_tab.add_child(center)

func _process(_delta: float) -> void:
	if coins_label:
		coins_label.text = "COINS: " + str(int(displayed_coins))
		
	if drag_preview and is_instance_valid(drag_preview):
		drag_preview.global_position = get_global_mouse_position() - (drag_preview.size / 2.0)
		
	var is_touching = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	
	# Drop if we released touch while dragging
	if not is_touching and dragging_weapon_type != 0:
		_handle_drop(get_global_mouse_position())
		
	# Swipe Snapping Logic (only if not dragging a weapon)
	if is_touching and dragging_weapon_type == 0:
		# Check if mouse is inside the content area
		var mouse_pos = get_local_mouse_position()
		if content_area.get_rect().has_point(mouse_pos):
			if not is_dragging_scroll:
				is_dragging_scroll = true
				drag_start_x = get_global_mouse_position().x
				drag_start_scroll = content_area.scroll_horizontal
				if scroll_tween and scroll_tween.is_valid():
					scroll_tween.kill()
			else:
				# Update scroll manually based on drag delta
				var current_x = get_global_mouse_position().x
				var delta_x = current_x - drag_start_x
				# Only move if drag distance is significant (threshold)
				if abs(delta_x) > 10:
					content_area.scroll_horizontal = drag_start_scroll - delta_x
	elif is_dragging_scroll:
		is_dragging_scroll = false
		if content_area.size.x > 0:
			var nearest_idx = round(float(content_area.scroll_horizontal) / content_area.size.x)
			nearest_idx = clamp(nearest_idx, 0, 3)
			
			if current_tab_index != nearest_idx:
				_on_tab_pressed(nearest_idx)
			else:
				var target_scroll = current_tab_index * content_area.size.x
				scroll_tween = create_tween()
				scroll_tween.tween_property(content_area, "scroll_horizontal", int(target_scroll), 0.2)\
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func update_ui() -> void:
	var coins = SaveDataManager.get_val("coins")
	if coins == null: coins = 0
	
	if coin_tween and coin_tween.is_valid():
		coin_tween.kill()
	
	coin_tween = create_tween()
	coin_tween.tween_property(self, "displayed_coins", float(coins), 0.5)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	var sign_level = SaveDataManager.get_val("sign_upgrade_level")
	if sign_level == null: sign_level = 0
	
	# Removed repair_button logic
	var total_max_stamina = 20 + sign_level
	var stamina = SaveDataManager.get_val("stamina")
	if stamina == null: stamina = total_max_stamina
	# リザルト等で20を超える場合はクリップ
	if stamina > total_max_stamina: stamina = total_max_stamina
	
	stamina_label.text = "STAMINA: " + str(stamina) + "/" + str(total_max_stamina)
	
	var max_shield = 5
	var current_shield = SaveDataManager.get_val("current_shield")
	if current_shield == null: current_shield = max_shield
	
	if shield_pips_hbox:
		for i in range(5):
			var pip = shield_pips_hbox.get_child(i) as ColorRect
			if i < current_shield:
				pip.color = Color(0.2, 0.8, 1.0) # Filled (Cyan)
			elif i < max_shield:
				pip.color = Color(0.4, 0.4, 0.4) # Empty slot
			else:
				pip.color = Color(0.2, 0.2, 0.2, 0) # Hidden (not unlocked)
	
	var shield_diff = max_shield - current_shield
	var recharge_cost = 50 # 1回の回復で50コイン(仕様:「１回押すとコインを消費して１シールド追加」)
	
	if buy_shield_button:
		if current_shield >= max_shield:
			buy_shield_button.text = "FULL"
			buy_shield_button.disabled = true
			buy_shield_button.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		else:
			buy_shield_button.text = "+1 (" + str(recharge_cost) + "C)"
			buy_shield_button.disabled = (coins < recharge_cost)
			if coins >= recharge_cost:
				buy_shield_button.add_theme_color_override("font_color", Color(0.2, 0.8, 1.0))
			else:
				buy_shield_button.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
				
	_update_weapon_deck_ui(coins)
	_update_shop_ui(coins)
	
	var current_stage = SaveDataManager.get_val("current_stage")
	if current_stage == null: current_stage = 1
	stage_label.text = "CURRENT STAGE: " + str(current_stage)

	# Removed _on_repair_pressed

func _on_buy_shield_pressed() -> void:
	var coins = SaveDataManager.get_val("coins")
	if coins == null: coins = 0
	
	var max_shield = 5
	var current_shield = SaveDataManager.get_val("current_shield")
	if current_shield == null: current_shield = max_shield
	
	var recharge_cost = 50
	
	if current_shield < max_shield and coins >= recharge_cost:
		coins -= recharge_cost
		current_shield += 1
		SaveDataManager.set_val("coins", coins)
		SaveDataManager.set_val("current_shield", current_shield)
		
		# SE再生
		if AudioManager: AudioManager.play_merge_sfx()
		
		update_ui()
		print("--- SHIELD RECHARGED +1 ---")

var shop_catalog = [
	{"type": 2, "name": "Shotgun", "price": 500},
	{"type": 3, "name": "Chainsaw", "price": 1000},
	{"type": 4, "name": "Grenade", "price": 1500},
	{"type": 5, "name": "SMG", "price": 800}
]

func _update_shop_ui(coins: int) -> void:
	if not shop_items_vbox: return
	
	for child in shop_items_vbox.get_children():
		child.queue_free()
		
	var unlocked_weapons = SaveDataManager.get_val("unlocked_weapons", [1])
	if typeof(unlocked_weapons) != TYPE_ARRAY: unlocked_weapons = [1]
	
	for item in shop_catalog:
		var w_type = item["type"]
		var w_name = item["name"]
		var cost = item["price"]
		
		var is_unlocked = unlocked_weapons.has(w_type)
		
		var hbox = HBoxContainer.new()
		hbox.alignment = BoxContainer.ALIGNMENT_CENTER
		hbox.add_theme_constant_override("separation", 20)
		
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(64, 64)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = _get_weapon_texture(w_type)
		hbox.add_child(icon)
		
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(200, 60)
		btn.add_theme_font_size_override("font_size", 20)
		
		if is_unlocked:
			btn.text = w_name + "\n(OWNED)"
			btn.disabled = true
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.2, 0.4, 0.2)
			btn.add_theme_stylebox_override("disabled", style)
			btn.add_theme_color_override("font_disabled_color", Color(0.7, 0.9, 0.7))
		else:
			btn.text = w_name + "\n" + str(cost) + " Coins"
			btn.disabled = (coins < cost)
			btn.pressed.connect(func(): _on_weapon_buy_pressed(w_type, cost, w_name))
			if coins >= cost:
				btn.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
			else:
				btn.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
				
		hbox.add_child(btn)
		shop_items_vbox.add_child(hbox)

func _on_weapon_buy_pressed(w_type: int, cost: int, w_name: String) -> void:
	var coins = SaveDataManager.get_val("coins", 0)
	if coins >= cost:
		coins -= cost
		SaveDataManager.set_val("coins", coins)
		
		var unlocked = SaveDataManager.get_val("unlocked_weapons", [1])
		if typeof(unlocked) != TYPE_ARRAY: unlocked = [1]
		if not unlocked.has(w_type):
			unlocked.append(w_type)
		SaveDataManager.set_val("unlocked_weapons", unlocked)
		
		var inv = SaveDataManager.get_val("weapon_inventory", {})
		if typeof(inv) != TYPE_DICTIONARY: inv = {}
		
		# Give a starter stock of 5
		inv[str(w_type)] = int(inv.get(str(w_type), 0)) + 5
		SaveDataManager.set_val("weapon_inventory", inv)
		
		_play_buy_effect()
		_show_purchase_dialog("Unlocked " + w_name + "!\nAdded 5 to Warehouse.")
		update_ui()

func _play_buy_effect() -> void:
	if AudioManager and AudioManager.has_method("play_merge_sfx"):
		AudioManager.play_merge_sfx()
		
	# Neon screen flash
	var flash = ColorRect.new()
	flash.color = Color(1.0, 0.8, 0.2, 0.8) # Yellow neon flash
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.z_index = 1000
	get_tree().current_scene.add_child(flash)
	
	var tw = create_tween()
	tw.tween_property(flash, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_OUT)
	tw.tween_callback(flash.queue_free)

func _show_purchase_dialog(msg: String) -> void:
	var panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	var vbox = VBoxContainer.new()
	panel.add_child(vbox)
	
	var label = Label.new()
	label.text = msg
	label.add_theme_font_size_override("font_size", 24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(label)
	
	var btn = Button.new()
	btn.text = "OK"
	btn.add_theme_font_size_override("font_size", 24)
	btn.pressed.connect(func(): panel.queue_free())
	vbox.add_child(btn)
	
	add_child(panel)

func _update_weapon_deck_ui(coins: int) -> void:
	var equipped = SaveDataManager.get_val("equipped_weapons")
	if typeof(equipped) != TYPE_ARRAY or equipped.size() < 5:
		equipped = [1, 0, 0, 0, 0]
		SaveDataManager.set_val("equipped_weapons", equipped)
		
	var inventory = SaveDataManager.get_val("weapon_inventory")
	if typeof(inventory) != TYPE_DICTIONARY:
		inventory = {"1": 99, "5": 5}
	else:
		var cleaned = {}
		for k in inventory.keys():
			var clean_k = str(int(str(k).to_float()))
			cleaned[clean_k] = cleaned.get(clean_k, 0) + int(inventory[k])
		inventory = cleaned
		if not inventory.has("5"):
			inventory["5"] = 5
	SaveDataManager.set_val("weapon_inventory", inventory)
		
	var base_levels = SaveDataManager.get_val("weapon_base_levels")
	if typeof(base_levels) != TYPE_DICTIONARY:
		base_levels = {"1": 1, "2": 1, "3": 1, "4": 1, "5": 1}
		
	# Update Equip Slots
	for i in range(5):
		var w_type = int(equipped[i])
		var panel = equip_slots[i].get_parent()
		var none_label = panel.get_node(^"NoneLabel") as Label
		
		if w_type == 0:
			equip_slots[i].texture = null
			if none_label: none_label.show()
		else:
			equip_slots[i].texture = _get_weapon_texture(w_type)
			if none_label: none_label.hide()
			
	# Update Warehouse (40 slots total = 8 rows * 5 cols)
	for child in warehouse_grid.get_children():
		child.queue_free()
		
	# Collect unique existing weapon types in inventory, ensure unlocked ones are included
	var unlocked = SaveDataManager.get_val("unlocked_weapons", [1])
	if typeof(unlocked) != TYPE_ARRAY: unlocked = [1]
	
	var available_types = []
	for k in inventory.keys():
		var w_str = str(int(str(k).to_float()))
		if not available_types.has(w_str):
			available_types.append(w_str)
	for w in unlocked:
		var w_str = str(int(w))
		if not available_types.has(w_str):
			available_types.append(w_str)
			
	available_types.sort() # Optional, sorts by string key but usually numerical
	
	for i in range(40):
		var panel = PanelContainer.new()
		panel.custom_minimum_size = Vector2(80, 80)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.2, 0.2, 0.2)
		panel.add_theme_stylebox_override("panel", style)
		
		# If we have an item for this slot...
		if i < available_types.size():
			var w_type_str = available_types[i]
			var count = int(inventory.get(w_type_str, 0))
			
			var w_type = int(w_type_str)
			
			# We show it if it's unlocked, or if it's equipped, or if count > 0
			var is_unlocked = unlocked.has(w_type) or unlocked.has(float(w_type))
			if count > 0 or w_type in equipped or is_unlocked:
				
				var slot = TextureRect.new()
				slot.custom_minimum_size = Vector2(80, 80)
				slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				slot.texture = _get_weapon_texture(w_type)
				
				# Only interactive if we actually have count > 0
				if count > 0:
					slot.mouse_filter = Control.MOUSE_FILTER_PASS
					slot.gui_input.connect(_on_warehouse_gui_input.bind(w_type))
				else:
					slot.modulate = Color(0.4, 0.4, 0.4, 0.8) # Grayed out if 0 count
					
				var count_label = Label.new()
				count_label.text = "x" + str(count)
				count_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
				count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				count_label.add_theme_font_size_override("font_size", 14)
				count_label.add_theme_color_override("font_color", Color.YELLOW)
				count_label.add_theme_color_override("font_shadow_color", Color.BLACK)
				count_label.add_theme_constant_override("shadow_offset_x", 1)
				count_label.add_theme_constant_override("shadow_offset_y", 1)
				
				if w_type in equipped:
					style.bg_color = Color(0.1, 0.4, 0.1) # Highlight Green
				
				slot.add_child(count_label)
				panel.add_child(slot)
		
		warehouse_grid.add_child(panel)
		
	# Upgrade Panel is currently disabled
	if upgrade_panel:
		upgrade_panel.hide()

func _on_warehouse_gui_input(event: InputEvent, w_type: int) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed() and dragging_weapon_type == 0:
			# Start drag
			dragging_weapon_type = w_type
			drag_preview = TextureRect.new()
			drag_preview.texture = _get_weapon_texture(w_type)
			drag_preview.custom_minimum_size = Vector2(80, 80)
			drag_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			drag_preview.z_index = 100
			drag_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(drag_preview)
			
			selected_weapon_for_upgrade = w_type
			update_ui()

func _on_equip_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed() and dragging_weapon_type == 0:
			if slot_index != 0: # Pistol (slot 0) is locked
				var equipped = SaveDataManager.get_val("equipped_weapons")
				var removed_type = equipped[slot_index]
				if removed_type != 0:
					# Return to warehouse inventory
					var inventory = SaveDataManager.get_val("weapon_inventory")
					if typeof(inventory) != TYPE_DICTIONARY: inventory = {"1": 99, "5": 5}
					var str_type = str(removed_type)
					inventory[str_type] = int(inventory.get(str_type, 0)) + 1
					
					equipped[slot_index] = 0
					
					var packed = []
					for w in equipped:
						if w != 0: packed.append(w)
					while packed.size() < 5: packed.append(0)
					equipped = packed
					
					SaveDataManager.set_val("weapon_inventory", inventory)
					SaveDataManager.set_val("equipped_weapons", equipped)
					
					if AudioManager: AudioManager.play_merge_sfx() # Reusing SFX
					update_ui()

func _handle_drop(pos: Vector2) -> void:
	var _dropped_on_slot = false
	
	for i in range(5):
		var slot = equip_slots[i]
		var panel = slot.get_parent() as Control
		if panel.get_global_rect().has_point(pos):
			var equipped = SaveDataManager.get_val("equipped_weapons")
			if typeof(equipped) != TYPE_ARRAY or equipped.size() < 5:
				equipped = [1, 0, 0, 0, 0]
				
			var inventory = SaveDataManager.get_val("weapon_inventory")
			if typeof(inventory) != TYPE_DICTIONARY: inventory = {"1": 99, "5": 5}
			
			# Prevent duplicates of the SAME weapon in the deck? 
			# The user's new logic allows stacks, so technically they could equip multiple of the same type
			# if they have multiple in inventory. Wait, user previously said:
			# "同じ種類の武器は重複して装備不可とします" (Cannot equip same weapon multiple times)
			# Let's enforce that. If it's already equipped in another slot, we just return it to inventory and swap.
			var old_type = equipped[i]
			
			# First, check if trying to equip a duplicate
			var is_duplicate = false
			for j in range(5):
				if j != i and equipped[j] == dragging_weapon_type:
					is_duplicate = true
					
			if not is_duplicate:
				# Consume from inventory
				var str_drag = str(dragging_weapon_type)
				if int(inventory.get(str_drag, 0)) > 0:
					inventory[str_drag] = int(inventory[str_drag]) - 1
					
					# Refund old weapon if there was one
					if old_type != 0:
						var str_old = str(old_type)
						inventory[str_old] = int(inventory.get(str_old, 0)) + 1
						
					equipped[i] = dragging_weapon_type
					
					var packed = []
					for w in equipped:
						if w != 0: packed.append(w)
					while packed.size() < 5: packed.append(0)
					equipped = packed
					
					SaveDataManager.set_val("weapon_inventory", inventory)
					SaveDataManager.set_val("equipped_weapons", equipped)
					
					if AudioManager: AudioManager.play_merge_sfx()
					update_ui()
			
			_dropped_on_slot = true
			break
			
	dragging_weapon_type = 0
	if drag_preview:
		drag_preview.queue_free()
		drag_preview = null

func _on_upgrade_selected_weapon() -> void:
	if selected_weapon_for_upgrade == -1: return
	var w_type = selected_weapon_for_upgrade
	
	var coins = SaveDataManager.get_val("coins")
	if coins == null: coins = 0
	
	var base_levels = SaveDataManager.get_val("weapon_base_levels")
	if typeof(base_levels) != TYPE_DICTIONARY:
		base_levels = {"1": 1, "2": 1, "3": 1, "4": 1, "5": 1}
		
	var b_level = int(base_levels.get(str(w_type), 1))
	var cost = b_level * 50
	
	if coins >= cost and b_level < 7:
		coins -= cost
		base_levels[str(w_type)] = b_level + 1
		
		SaveDataManager.set_val("coins", coins)
		SaveDataManager.set_val("weapon_base_levels", base_levels)
		
		if AudioManager: AudioManager.play_merge_sfx()
		update_ui()
		print("--- WEAPON " + str(w_type) + " UPGRADED ---")

func _on_heroine_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventMouseButton:
		if event.is_pressed():
			# 吹き出しアニメーション
			var tw = create_tween()
			tw.tween_property(heroine_speech, "modulate:a", 1.0, 0.2)
			tw.tween_interval(2.0)
			tw.tween_property(heroine_speech, "modulate:a", 0.0, 0.4)

func _on_start_pressed() -> void:
	start_button.disabled = true
	SceneManager.change_scene("res://scenes/Main.tscn")
