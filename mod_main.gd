extends Node

var _processed = {}

# 核心存储：锁定的属性 ID 和品质
var locked_id = ""
var locked_tier = -1
var locked_card_node = null

var status_label: Label

func _ready():
    # 右上角状态提示
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    
    status_label = Label.new()
    status_label.text = "✅ 自动升级已就绪 (未锁定)"
    status_label.add_color_override("font_color", Color(0, 1, 0))
    status_label.add_color_override("font_outline_color", Color(0, 0, 0))
    status_label.add_constant_override("outline_size", 4)
    status_label.anchor_left = 1.0
    status_label.anchor_right = 1.0
    status_label.margin_left = -300
    status_label.margin_right = -20
    status_label.margin_top = 20
    status_label.align = Label.ALIGN_RIGHT
    canvas.add_child(status_label)

    get_tree().connect("node_added", self, "_on_node_added")

func _on_node_added(node: Node):
    # 监听升级界面（UpgradesUI）的生成
    if node.name == "UpgradesUI":
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        _setup_upgrade_ui(node)

func _setup_upgrade_ui(upgrade_ui: Node):
    # 寻找装载 4 个卡片的容器
    var container = upgrade_ui.find_node("UpgradesContainer", true, false)
    if not container: return
    
    var hbox = container.find_node("HBoxContainer", true, false)
    if not hbox: return
    
    # 添加全局清除按钮到刷新按钮旁边
    var reroll_box = container.find_node("HBoxContainer2", true, false)
    if reroll_box and not reroll_box.has_node("ModClearLockButton"):
        var clear_btn = Button.new()
        clear_btn.name = "ModClearLockButton"
        clear_btn.text = "清除锁定"
        clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        clear_btn.connect("pressed", self, "_on_clear_lock_pressed")
        reroll_box.add_child(clear_btn)

    # 遍历 4 个卡片
    for card in hbox.get_children():
        if card is PanelContainer and "UpgradeUI" in card.name:
            _process_card(card)

func _process_card(card: Control):
    if _processed.has(card): return
    _processed[card] = true
    
    # 尝试获取卡片数据
    var data = card.get("item_data")
    if not data:
        data = card.get("upgrade_data")
        
    var card_id = ""
    var card_tier = -1
    
    if data != null:
        card_id = str(data.get("my_id")) if "my_id" in data else str(data.name)
        card_tier = int(data.get("tier")) if "tier" in data else 0
    else:
        # 如果取不到数据，退而求其次，用文字匹配（但无法精确区分品质，只做备用）
        var name_label = card.find_node("Name", true, false)
        if name_label:
            card_id = name_label.text
    
    # 生成右上角小按钮
    var lock_btn = Button.new()
    lock_btn.name = "ModLockButton"
    lock_btn.rect_min_size = Vector2(40, 40)
    lock_btn.anchor_left = 1.0
    lock_btn.anchor_right = 1.0
    lock_btn.margin_left = -45
    lock_btn.margin_right = -5
    lock_btn.margin_top = 5
    lock_btn.margin_bottom = 45
    lock_btn.focus_mode = Control.FOCUS_NONE
    
    # 判断当前卡片是否匹配锁定状态
    var is_locked = (card_id == locked_id and card_tier == locked_tier)
    _update_button_style(lock_btn, is_locked)
    
    # 绑定点击事件
    lock_btn.connect("pressed", self, "_on_lock_pressed", [card, lock_btn, card_id, card_tier])
    card.add_child(lock_btn)
    
    # 如果匹配，延迟一小会儿直接自动选择
    if is_locked:
        status_label.text = "⚡ 正在自动领取..."
        yield(get_tree().create_timer(0.2), "timeout")
        if is_instance_valid(card):
            var choose_btn = card.find_node("ChooseButton", true, false)
            if choose_btn:
                choose_btn.emit_signal("pressed")
                status_label.text = "✅ 自动领取成功！"

func _update_button_style(btn: Button, is_locked: bool):
    if is_locked:
        btn.text = "锁"
        btn.add_color_override("font_color", Color(1, 1, 1)) # 白色
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0.2, 0.6, 1.0, 0.8) # 亮色背景
        btn.add_stylebox_override("normal", style)
    else:
        btn.text = "解"
        btn.add_color_override("font_color", Color(0.5, 0.5, 0.5)) # 灰色
        var style = StyleBoxFlat.new()
        style.bg_color = Color(0, 0, 0, 0.5) # 黑色半透明
        btn.add_stylebox_override("normal", style)

func _on_lock_pressed(card: Control, btn: Button, card_id: String, card_tier: int):
    if locked_id == card_id and locked_tier == card_tier:
        # 取消锁定
        locked_id = ""
        locked_tier = -1
        status_label.text = "✅ 已解除锁定"
    else:
        # 互斥顶替：设置新的锁定
        locked_id = card_id
        locked_tier = card_tier
        status_label.text = "✅ 已锁定: " + card_id + " (品质 " + str(card_tier) + ")"
    
    # 刷新界面上所有按钮的样式（互斥）
    var upgrade_ui = get_tree().root.find_node("UpgradesUI", true, false)
    if upgrade_ui:
        var hbox = upgrade_ui.find_node("UpgradesContainer", true, false).find_node("HBoxContainer", true, false)
        for c in hbox.get_children():
            if c is PanelContainer and "UpgradeUI" in c.name:
                var b = c.find_node("ModLockButton", true, false)
                if b:
                    var d = c.get("item_data")
                    if not d: d = c.get("upgrade_data")
                    var c_id = ""
                    var c_tier = -1
                    if d != null:
                        c_id = str(d.get("my_id")) if "my_id" in d else str(d.name)
                        c_tier = int(d.get("tier")) if "tier" in d else 0
                    else:
                        var n_lbl = c.find_node("Name", true, false)
                        if n_lbl: c_id = n_lbl.text
                    _update_button_style(b, c_id == locked_id and c_tier == locked_tier)

func _on_clear_lock_pressed():
    locked_id = ""
    locked_tier = -1
    status_label.text = "🧹 已清除所有锁定"
    
    var upgrade_ui = get_tree().root.find_node("UpgradesUI", true, false)
    if upgrade_ui:
        var hbox = upgrade_ui.find_node("UpgradesContainer", true, false).find_node("HBoxContainer", true, false)
        for c in hbox.get_children():
            if c is PanelContainer and "UpgradeUI" in c.name:
                var b = c.find_node("ModLockButton", true, false)
                if b:
                    _update_button_style(b, false)
