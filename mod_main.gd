extends Node

var _processed = {}
var locked_id = ""
var locked_tier = -1
var status_label: Label

var _ui: Node = null
var _container: Node = null
var _hbox: Node = null
var _tick := 0.0
const CHECK_INTERVAL := 0.15
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
    if _auto_pick_cooldown > 0.0:
        _auto_pick_cooldown -= delta

    _tick -= delta
    if _tick > 0.0:
        return
    _tick = CHECK_INTERVAL

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

    # 清除按钮：直接加到 reroll_hbox，自然和 RerollButton 同尺寸
    var reroll_hbox = _container.find_node("HBoxContainer2", true, false)
    if reroll_hbox and not reroll_hbox.has_node("ModClearLockButton"):
        var reroll_btn = reroll_hbox.find_node("RerollButton", true, false)
        if reroll_btn:
            var clear_btn = Button.new()
            clear_btn.name = "ModClearLockButton"
            clear_btn.text = "清除锁定"
            clear_btn.rect_min_size = reroll_btn.rect_min_size
            clear_btn.size_flags_horizontal = reroll_btn.size_flags_horizontal
            clear_btn.size_flags_vertical = reroll_btn.size_flags_vertical
            clear_btn.connect("pressed", self, "_on_clear_lock_pressed")
            reroll_hbox.add_child(clear_btn)

    # 卡片按钮 & 自动领取
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

            var btn = card.get_node_or_null("ModOverlay/ModLockButton")
            if btn:
                if is_matched:
                    if btn.text != "已锁":
                        btn.text = "已锁"
                        btn.add_color_override("font_color", Color(0.3, 1, 0.4, 1))
                else:
                    if btn.text != "锁":
                        btn.text = "锁"
                        btn.add_color_override("font_color", Color(1, 1, 1, 0.6))

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
    lock_btn.text = "锁"
    lock_btn.rect_min_size = Vector2(32, 32)
    lock_btn.focus_mode = Control.FOCUS_NONE

    lock_btn.anchor_left = 1.0
    lock_btn.anchor_right = 1.0
    lock_btn.anchor_top = 0.0
    lock_btn.anchor_bottom = 0.0
    lock_btn.margin_left = -36
    lock_btn.margin_right = -4
    lock_btn.margin_top = 4
    lock_btn.margin_bottom = 36

    var s_normal = StyleBoxFlat.new()
    s_normal.bg_color = Color(0, 0, 0, 0.45)
    s_normal.set_corner_radius_all(8)
    s_normal.set_border_width_all(1)
    s_normal.border_color = Color(1, 1, 1, 0.15)
    lock_btn.add_stylebox_override("normal", s_normal)

    var s_hover = StyleBoxFlat.new()
    s_hover.bg_color = Color(0.3, 0.55, 1.0, 0.65)
    s_hover.set_corner_radius_all(8)
    s_hover.set_border_width_all(1)
    s_hover.border_color = Color(1, 1, 1, 0.35)
    lock_btn.add_stylebox_override("hover", s_hover)

    var s_pressed = StyleBoxFlat.new()
    s_pressed.bg_color = Color(0.2, 0.4, 0.85, 0.8)
    s_pressed.set_corner_radius_all(8)
    lock_btn.add_stylebox_override("pressed", s_pressed)

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
