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

    # 每帧持续监控，再也不用担心节点生成延迟
    set_process(true)

func _process(_delta):
    # 1. 寻找升级界面
    var upgrade_ui = get_tree().root.find_node("UpgradesUI", true, false)
    if not upgrade_ui or not upgrade_ui.is_visible_in_tree(): return
    
    var container = upgrade_ui.find_node("UpgradesContainer", true, false)
    if not container: return
    
    var hbox = container.find_node("HBoxContainer", true, false)
    if not hbox: return
    
    # 2. 动态添加清除按钮（如果还没有）
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

    # 3. 给卡片贴按钮 & 检查是否自动领取
    for card in hbox.get_children():
        if card is PanelContainer and "UpgradeUI" in card.name:
            # 先确保按钮生成了
            if not card.has_node("ModLockButton"):
                _create_lock_button(card)
                
            # 获取卡片数据
            var data = card.get("upgrade_data")
            if data == null: continue # 如果数据还没挂载，这帧跳过，下帧再查
            
            var c_id = str(data.my_id)
            var c_tier = int(data.tier)
            var is_matched = (c_id == locked_id and locked_tier != -1 and c_tier == locked_tier)
            
            # 更新锁定按钮的视觉状态
            var btn = card.find_node("ModLockButton", true, false)
            if btn:
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
                return # 领完一个立刻退出本帧，等待刷新

# 生成右上角按钮
func _create_lock_button(card: Control):
    var lock_btn = Button.new()
    lock_btn.name = "ModLockButton"
    lock_btn.text = "解"
    lock_btn.rect_min_size = Vector2(40, 40)
    lock_btn.rect_size = Vector2(40, 40)
    lock_btn.focus_mode = Control.FOCUS_NONE
    
    # 定位右上角
    lock_btn.anchor_left = 1.0
    lock_btn.anchor_right = 1.0
    lock_btn.margin_left = -46
    lock_btn.margin_right = -6
    lock_btn.margin_top = 6
    lock_btn.margin_bottom = 46
    
    lock_btn.connect("pressed", self, "_on_lock_pressed", [card])
    card.add_child(lock_btn)

func _on_lock_pressed(card: Control):
    var data = card.get("upgrade_data")
    if data == null:
        status_label.text = "数据尚未加载"
        return
        
    var c_id = str(data.my_id)
    var c_tier = int(data.tier)
    
    # 互斥顶替逻辑
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
