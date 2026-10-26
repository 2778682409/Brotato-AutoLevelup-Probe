extends Node

var _processed = {}
var locked_id = ""
var locked_tier = -1
var status_label: Label
var _auto_taken_this_wave = false # 防止一波内重复自动领取

func _ready():
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    
    status_label = Label.new()
    status_label.text = "✅ 自动升级已就绪"
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
        _auto_taken_this_wave = false
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        yield(get_tree(), "idle_frame")
        _setup_upgrade_ui(node)

func _setup_upgrade_ui(upgrade_ui: Node):
    var container = upgrade_ui.find_node("UpgradesContainer", true, false)
    if not container: return
    
    var hbox = container.find_node("HBoxContainer", true, false)
    if not hbox: return
    
    # 修复清除按钮位置：塞到刷新按钮所在HBox的下面
    var reroll_box = container.find_node("HBoxContainer2", true, false)
    if reroll_box and not reroll_box.has_node("ModClearLockButton"):
        var reroll_btn = reroll_box.find_node("RerollButton", true, false)
        if reroll_btn:
            # 把清除按钮当成刷新按钮的兄弟节点，排列在下方
            var clear_btn = Button.new()
            clear_btn.name = "ModClearLockButton"
            clear_btn.text = "清除锁定"
            clear_btn.rect_min_size = reroll_btn.rect_min_size
            clear_btn.connect("pressed", self, "_on_clear_lock_pressed")
            # 插在刷新按钮的后面（下方）
            reroll_box.add_child(clear_btn)
            reroll_box.move_child(clear_btn, reroll_btn.get_index() + 1)

    for card in hbox.get_children():
        if card is PanelContainer and "UpgradeUI" in card.name:
            _process_card_ui(card)

# 实时监控数据（解决刷新后不自动领取的问题）
func _process(_delta):
    var upgrade_ui = get_tree().root.find_node("UpgradesUI", true, false)
    if not upgrade_ui or not upgrade_ui.is_visible_in_tree(): return
    
    if _auto_taken_this_wave: return
    if locked_id == "": return

    var hbox = upgrade_ui.find_node("HBoxContainer", true, false)
    if not hbox: return
    
    for card in hbox.get_children():
        if card is PanelContainer and "UpgradeUI" in card.name:
            var data = card.get("item_data")
            if not data: data = card.get("upgrade_data")
            if data != null:
                var c_id = str(data.get("my_id")) if "my_id" in data else str(data.name)
                var c_tier = int(data.get("tier")) if "tier" in data else 0
                
                if c_id == locked_id and c_tier == locked_tier:
                    _auto_taken_this_wave = true
                    status_label.text = "⚡ 匹配成功，自动领取！"
                    var choose_btn = card.find_node("ChooseButton", true, false)
                    if choose_btn:
                        choose_btn.emit_signal("pressed")
                    return

func _process_card_ui(card: Control):
    if _processed.has(card): return
    _processed[card] = true
    
    # 修复按钮位置：把它塞进最顶层的 Margin 或直接挂在 Panel 下
    if card.has_node("ModLockButton"): return
    
    var lock_btn = TextureButton.new()
    lock_btn.name = "ModLockButton"
    # 使用原版的叉号图标作为锁的代替（如果没有专用的锁）
    lock_btn.texture_normal = load("res://items/global/baned_item.png")
    lock_btn.expand = true
    lock_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
    
    # 彻底解决变大白板的问题：强制物理大小
    lock_btn.rect_min_size = Vector2(40, 40)
    lock_btn.rect_size = Vector2(40, 40)
    
    # 手动定位到右上角
    lock_btn.anchor_left = 1.0
    lock_btn.anchor_right = 1.0
    lock_btn.margin_left = -50
    lock_btn.margin_right = -10
    lock_btn.margin_top = 10
    lock_btn.margin_bottom = 50
    
    # 给个暗色背景底
    var bg = ColorRect.new()
    bg.color = Color(0, 0, 0, 0.6)
    bg.rect_min_size = Vector2(40, 40)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    lock_btn.add_child(bg)
    lock_btn.move_child(bg, 0)
    
    lock_btn.modulate = Color(1, 1, 1, 0.3) # 未选中时变暗
    lock_btn.connect("pressed", self, "_on_lock_pressed", [card])
    
    # 添加到卡片节点
    card.add_child(lock_btn)

func _on_lock_pressed(card: Control):
    var data = card.get("item_data")
    if not data: data = card.get("upgrade_data")
    
    if data == null:
        status_label.text = "❌ 无法读取卡片数据"
        return
        
    var card_id = str(data.get("my_id")) if "my_id" in data else str(data.name)
    var card_tier = int(data.get("tier")) if "tier" in data else 0
    
    if locked_id == card_id and locked_tier == card_tier:
        locked_id = ""
        locked_tier = -1
        status_label.text = "✅ 已解除锁定"
    else:
        locked_id = card_id
        locked_tier = card_tier
        status_label.text = "✅ 已锁定: " + card_id + " (品" + str(card_tier) + ")"
    
    _refresh_all_buttons()

func _refresh_all_buttons():
    var upgrade_ui = get_tree().root.find_node("UpgradesUI", true, false)
    if not upgrade_ui: return
    var hbox = upgrade_ui.find_node("HBoxContainer", true, false)
    if not hbox: return
    
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
                
                if c_id == locked_id and c_tier == locked_tier:
                    b.modulate = Color(1, 1, 1, 1) # 亮起
                else:
                    b.modulate = Color(1, 1, 1, 0.3) # 变暗

func _on_clear_lock_pressed():
    locked_id = ""
    locked_tier = -1
    status_label.text = "🧹 已清除所有锁定"
    _refresh_all_buttons()
