extends Node

var _processed = {}
var locked_id = ""
var locked_tier = -1
var status_label: Label

func _ready():
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    
    status_label = Label.new()
    status_label.text = "自动升级已就绪"
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
    if node.name == "UpgradesUI":
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        _setup_upgrade_ui(node)

func _setup_upgrade_ui(upgrade_ui: Node):
    var container = upgrade_ui.find_node("UpgradesContainer", true, false)
    if not container: return
    
    var hbox = container.find_node("HBoxContainer", true, false)
    if not hbox: return
    
    # 清除按钮位置：在刷新按钮的正下方新建一行
    var reroll_hbox = container.find_node("HBoxContainer2", true, false)
    if reroll_hbox and not container.has_node("ModClearContainer"):
        var reroll_btn = reroll_hbox.find_node("RerollButton", true, false)
        if reroll_btn:
            var clear_hbox = HBoxContainer.new()
            clear_hbox.name = "ModClearContainer"
            clear_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
            clear_hbox.alignment = BoxContainer.ALIGN_CENTER
            
            var clear_btn = Button.new()
            clear_btn.name = "ModClearLockButton"
            clear_btn.text = "清除锁定"
            clear_btn.rect_min_size = reroll_btn.rect_min_size
            clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
            clear_btn.connect("pressed", self, "_on_clear_lock_pressed")
            
            clear_hbox.add_child(clear_btn)
            
            container.add_child(clear_hbox)
            container.move_child(clear_hbox, reroll_hbox.get_index() + 1)

    for card in hbox.get_children():
        if card is PanelContainer and "UpgradeUI" in card.name:
            _create_lock_button(card)

# 核心绘图：生成不会拉伸的小方块按钮
func _create_lock_button(card: Control):
    if card.has_node("ModLockButton"): return
    
    var lock_btn = Button.new()
    lock_btn.name = "ModLockButton"
    lock_btn.text = "解"
    lock_btn.rect_min_size = Vector2(40, 40)
    lock_btn.rect_size = Vector2(40, 40)
    lock_btn.focus_mode = Control.FOCUS_NONE
    
    # 强制定位到右上角
    lock_btn.anchor_left = 1.0
    lock_btn.anchor_right = 1.0
    lock_btn.margin_left = -46
    lock_btn.margin_right = -6
    lock_btn.margin_top = 6
    lock_btn.margin_bottom = 46
    
    lock_btn.connect("pressed", self, "_on_lock_pressed", [card])
    card.add_child(lock_btn)

# 每帧监控：刷新实时追踪与自动领取
func _process(_delta):
    var upgrade_ui = get_tree().root.find_node("UpgradesUI", true, false)
    if not upgrade_ui or not upgrade_ui.is_visible_in_tree(): return

    var hbox = upgrade_ui.find_node("HBoxContainer", true, false)
    if not hbox: return
    
    for card in hbox.get_children():
        if card is PanelContainer and "UpgradeUI" in card.name:
            var btn = card.find_node("ModLockButton", true, false)
            if not btn: continue
            
            var data = _get_card_data(card)
            if data == null: continue
            
            var c_id = data[0]
            var c_tier = data[1]
            var is_matched = (c_id == locked_id and locked_tier != -1 and c_tier == locked_tier)
            
            # 更新UI外观
            if is_matched:
                btn.text = "已锁"
                btn.add_color_override("font_color", Color(0, 1, 0)) # 绿色高亮
            else:
                btn.text = "解"
                btn.add_color_override("font_color", Color(1, 1, 1, 0.5)) # 半透明白
                
            # 触发自动领取
            if is_matched:
                status_label.text = "匹配成功，自动领取"
                locked_id = ""
                locked_tier = -1
                var choose_btn = card.find_node("ChooseButton", true, false)
                if choose_btn:
                    choose_btn.emit_signal("pressed")
                return 

func _on_lock_pressed(card: Control):
    var data = _get_card_data(card)
    if data == null:
        status_label.text = "无法读取卡片数据"
        return
        
    var c_id = data[0]
    var c_tier = data[1]
    
    if locked_id == c_id and locked_tier == c_tier:
        locked_id = ""
        locked_tier = -1
        status_label.text = "已解除锁定"
    else:
        locked_id = c_id
        locked_tier = c_tier
        status_label.text = "已锁定: " + c_id + " (品" + str(c_tier) + ")"

func _on_clear_lock_pressed():
    locked_id = ""
    locked_tier = -1
    status_label.text = "已清除所有锁定"

func _get_card_data(card: Control) -> Array:
    var data = card.get("item_data")
    if not data: data = card.get("upgrade_data")
    
    if data == null:
        return null
        
    var c_id = str(data.get("my_id")) if "my_id" in data else str(data.name)
    var c_tier = int(data.get("tier")) if "tier" in data else 0
    return [c_id, c_tier]
