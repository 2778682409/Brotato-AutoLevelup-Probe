extends Node

func _ready():
    # 右上角提示
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    var label = Label.new()
    label.text = "探针运行中"
    label.add_color_override("font_color", Color(0, 1, 0))
    label.add_color_override("font_outline_color", Color(0, 0, 0))
    label.add_constant_override("outline_size", 4)
    label.anchor_left = 1.0
    label.anchor_right = 1.0
    label.margin_left = -200
    label.margin_right = -20
    label.margin_top = 20
    label.align = Label.ALIGN_RIGHT
    canvas.add_child(label)

    # 延迟扫描
    call_deferred("_start_probe")

func _start_probe():
    # 每帧寻找升级界面
    set_process(true)

func _process(_delta):
    var upgrade_ui = get_tree().root.find_node("UpgradesUI", true, false)
    if not upgrade_ui or not upgrade_ui.is_visible_in_tree(): return
    
    # 找到了，如果还没处理过
    if not upgrade_ui.has_meta("probed"):
        upgrade_ui.set_meta("probed", true)
        _dump_card_properties(upgrade_ui)

func _dump_card_properties(upgrade_ui: Node):
    var hbox = upgrade_ui.find_node("UpgradesContainer", true, false).find_node("HBoxContainer", true, false)
    if not hbox: return
    
    var log_text = "=== 升级卡片属性探针 ===\n"
    for card in hbox.get_children():
        if card is PanelContainer and "UpgradeUI" in card.name:
            log_text += "\n[卡片: " + card.name + "]\n"
            # 打印卡片的所有自定义属性
            for prop in card.get_property_list():
                var name = prop.name
                var value = card.get(name)
                # 过滤掉引擎自带的几百个无用的 UI 属性
                if name.begins_with("_") or name in ["item_data", "upgrade", "data", "tier", "my_id", "value"]:
                    log_text += "  " + name + " = " + str(value) + "\n"
                elif not name in ["Script Variables"] and not name in ["Constants"]:
                    pass # 可以按需加更多过滤
    
    # 写入文件
    var file = File.new()
    if file.open("/storage/emulated/0/Download/Brotato/upgrade_data_probe.txt", File.WRITE) == OK:
        file.store_string(log_text)
        file.close()
        print("数据探针写入成功！")
        
        # 屏幕提示
        var canvas = get_node_or_null("CanvasLayer")
        if canvas:
            canvas.get_child(0).text = "探针已抓取，请查看文件"
