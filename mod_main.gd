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

# 缓存模组根目录路径
var _mod_dir = ""

func _ready():
    # 获取当前脚本所在的目录，比如 "res://mods/auto_upgrade"
    _mod_dir = get_script().resource_path.get_base_dir()

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

# 智能加载贴图（兼容不同格式，如果打包丢了图片会自动返回 null 不崩溃）
func _load_texture(filename: String) -> Texture:
    if _mod_dir == "": return null
    
    # 兼容 Godot 3 对 svg 的导出可能变成 png 的情况
    var check_names = [filename, filename.replace(".svg", ".png")]
    
    for name in check_names:
        var full_path = _mod_dir + "/" + name
        if ResourceLoader.exists(full_path):
            var res = load(full_path)
            if res is Texture:
                return res
    return null

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

    # --- 4. 动态添加清除按钮 ---
    var reroll_hbox = _container.find_node("HBoxContainer2", true, false)
    if reroll_hbox and not reroll_hbox.has_node("ModClearLockButton"):
        var reroll_btn = reroll_hbox.find_node("RerollButton", true, false)
        if reroll_btn:
            var clear_btn = Button.new()
            clear_btn.name = "ModClearLockButton"
            clear_btn.text = "清除锁定"
            
            var tex_gold1 = _load_texture("reroll_button_gold_1.png")
            var tex_gold2 = _load_texture("reroll_button_gold_2.png")
            
            # 如果有贴图就贴图，没贴图就继承原版样式
            if tex_gold1:
                var sb_normal = StyleBoxTexture.new()
                sb_normal.texture = tex_gold1
                clear_btn.add_stylebox_override("normal", sb_normal)
                clear_btn.add_stylebox_override("pressed", sb_normal)
                clear_btn.add_stylebox_override("disabled", sb_normal)
            if tex_gold2:
                var sb_hover = StyleBoxTexture.new()
                sb_hover.texture = tex_gold2
                clear_btn.add_stylebox_override("hover", sb_hover)
                
            # 如果没找到你的贴图，就完美复制刷新按钮的样式
            if not tex_gold1:
                for sb in ["normal", "hover", "pressed", "disabled", "focus"]:
                    var style = reroll_btn.get_stylebox(sb)
                    if style: clear_btn.add_stylebox_override(sb, style)

            # 继承基础尺寸和字体
            clear_btn.rect_min_size = reroll_btn.rect_min_size
            for c in ["font_color", "font_color_hover", "font_color_pressed"]:
                var col = reroll_btn.get_color(c)
                if col: clear_btn.add_color_override(c, col)
            var font = reroll_btn.get_font("font")
            if font: clear_btn.add_font_override("font", font)
            
            clear_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
            clear_btn.connect("pressed", self, "_on_clear_lock_pressed")
            
            reroll_hbox.add_child(clear_btn)
            reroll_hbox.move_child(clear_btn, reroll_btn.get_index() + 1)
            reroll_hbox.alignment = BoxContainer.ALIGN_CENTER

    # --- 5. 贴按钮 & 自动领取 ---
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
                    if not btn.get_meta("is_locked", false):
                        btn.set_meta("is_locked", true)
                        _update_lock_btn_visual(btn, true)
                else:
                    if btn.get_meta("is_locked", true):
                        btn.set_meta("is_locked", false)
                        _update_lock_btn_visual(btn, false)

            # 自动领取
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

# 更新按钮的视觉（区分图片和文字兜底）
func _update_lock_btn_visual(btn: Button, is_locked: bool):
    var tex_unlock = btn.get_meta("tex_unlock", null)
    var tex_lock = btn.get_meta("tex_lock", null)
    
    if tex_unlock and tex_lock:
        # 如果有图片，切换图片
        btn.icon = tex_lock if is_locked else tex_unlock
        btn.text = "" # 清空文字
    else:
        # 如果图片丢失，兜底使用文字
        if is_locked:
            btn.text = "已锁"
            btn.add_color_override("font_color", Color(0.3, 1, 0.4, 1))
            btn.add_color_override("font_color_hover", Color(0.5, 1, 0.6, 1))
        else:
            btn.text = "锁"
            btn.add_color_override("font_color", Color(1, 1, 1, 0.5))
            btn.add_color_override("font_color_hover", Color(1, 1, 1, 0.9))

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
    lock_btn.rect_min_size = Vector2(40, 40)
    lock_btn.focus_mode = Control.FOCUS_NONE
    lock_btn.expand_icon = true
    lock_btn.flat = true

    lock_btn.anchor_left = 1.0
    lock_btn.anchor_right = 1.0
    lock_btn.margin_left = -46
    lock_btn.margin_right = -6
    lock_btn.margin_top = 6
    lock_btn.margin_bottom = 46

    # 加载贴图并存入 meta
    var tex_unlock = _load_texture("hextechUnlock.svg")
    var tex_lock = _load_texture("hextechLock.svg")
    var tex_outline = _load_texture("relicOutlineEmpty.png")
    
    lock_btn.set_meta("tex_unlock", tex_unlock)
    lock_btn.set_meta("tex_lock", tex_lock)
    lock_btn.set_meta("is_locked", false)
    
    if tex_outline:
        var sb_hover = StyleBoxTexture.new()
        sb_hover.texture = tex_outline
        lock_btn.add_stylebox_override("hover", sb_hover)
        lock_btn.add_stylebox_override("pressed", sb_hover)
    
    # 初始化视觉状态
    _update_lock_btn_visual(lock_btn, false)
    
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
