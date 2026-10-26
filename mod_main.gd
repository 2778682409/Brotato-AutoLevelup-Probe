extends Node

var _processed = {}
var locked_id = ""
var locked_tier = -1
var status_label: Label

# --- 缓存 & 节流 ---
var _ui: Node = null
var _container: Node = null
var _hbox: Node = null
var _tick := 0.0
const CHECK_INTERVAL := 0.15

# --- 冷却防抖（只拦自动领取）---
var _auto_pick_cooldown := 0.0

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
    status_label.margin_bottom = 60
    status_label.align = Label.ALIGN_RIGHT
    canvas.add_child(status_label)

func _process(delta):
    # 1. 冷却倒计时（不 return，只递减）
    if _auto_pick_cooldown > 0.0:
        _auto_pick_cooldown -= delta

    # 2. 节流
    _tick -= delta
    if _tick > 0.0:
        return
    _tick = CHECK_INTERVAL

    # 3. 寻找节点（带缓存）
    if not is_instance_valid(_ui):
        _ui = get_tree().root.find_node("UpgradesUI", true, false)
    if not _ui or not _ui.is_visible_in_tree():
        return

    if not is_instance_valid(_container):
        _container = _ui.find_node("UpgradesContainer", true, false)
    if not _container:
        return

    if not is_instance_valid(_hbox):
        _hbox = _container.find_node("HBoxContainer", true, false)
    if not _hbox:
        return

    # 4. 动态添加清除按钮（查询和插入用同一父节点）
    var reroll_hbox = _container.find_node("HBoxContainer2", true, false)
    if reroll_hbox:
        var reroll_parent = reroll_hbox.get_parent()
        if reroll_parent and not reroll_parent.has_node("ModClearContainer"):
            var reroll_btn = reroll_hbox.find_node("RerollButton", true, false)
            if reroll_btn:
                var clear_hbox = HBoxContainer.new()
                clear_hbox.name = "ModClearContainer"
                clear_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
                clear_hbox.alignment = BoxContainer.ALIGN_CENTER

                var clear_btn = Button.new()
                clear_btn.name = "ModClearLockButton"
                clear_btn.text = "清除锁定"
                clear_btn.rect_min_size = Vector2(
                    max(80, reroll_btn.rect_min_size.x),
                    max(32, reroll_btn.rect_min_size.y)
                )
                clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
                clear_btn.connect("pressed", self, "_on_clear_lock_pressed")

                clear_hbox.add_child(clear_btn)
                reroll_parent.add_child(clear_hbox)
                reroll_parent.move_child(clear_hbox, reroll_hbox.get_index() + 1)

    # 5. 贴按钮 & 自动领取
    for card in _hbox.get_children():
        if card is PanelContainer and "UpgradeUI" in card.name:
            if not card.has_node("ModOverlay/ModLockButton"):
                _create_lock_button(card)

            var data = card.get("upgrade_data")
            if data == null:
                continue

            var c_id = str(data.my_id)
            var c_tier = int(data.tier)
            var is_matched = (c_id == locked_id and locked_tier != -1 and c_tier == locked_tier)

            # 视觉更新（不受冷却影响，玩家手动操作立即反馈）
            var btn = card.get_node_or_null("ModOverlay/ModLockButton")
            if btn:
                if is_matched:
                    if btn.text != "已锁":
                        btn.text = "已锁"
                        btn.add_color_override("font_color", Color(0, 1, 0))
                else:
                    if btn.text != "解":
                        btn.text = "解"
                        btn.add_color_override("font_color", Color(1, 1, 1, 0.5))

            # 自动领取（冷却只在这里拦）
            if is_matched:
                if _auto_pick_cooldown > 0.0:
                    continue

                var choose_btn = card.find_node("ChooseButton", true, false)
                if not choose_btn or choose_btn.disabled:
                    continue

                status_label.text = "匹配成功，自动领取"
                choose_btn.emit_signal("pressed")
                _auto_pick_cooldown = 0.5
                continue

func _create_lock_button(card: Control):
    var overlay: Control
    if card.has_node("ModOverlay"):
        overlay = card.get_node("ModOverlay")
    else:
        overlay = Control.new()
        overlay.name = "ModOverlay"
        overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
        overlay.set_anchors_and_margins_preset(Control.PRESET_WIDE)
        card.add_child(overlay)

    var lock_btn = Button.new()
    lock_btn.name = "ModLockButton"
    lock_btn.text = "解"
    lock_btn.rect_min_size = Vector2(40, 40)
    lock_btn.focus_mode = Control.FOCUS_NONE

    lock_btn.anchor_left = 1.0
    lock_btn.anchor_right = 1.0
    lock_btn.margin_left = -46
    lock_btn.margin_right = -6
    lock_btn.margin_top = 6
    lock_btn.margin_bottom = 46

    lock_btn.connect("pressed", self, "_on_lock_pressed", [card])
    overlay.add_child(lock_btn)

func _on_lock_pressed(card: Control):
    var data = card.get("upgrade_data")
    if data == null:
        status_label.text = "数据尚未加载"
        return

    var c_id = str(data.my_id)
    var c_tier = int(data.tier)

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
