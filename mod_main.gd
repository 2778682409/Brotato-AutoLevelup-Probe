extends Node

var _has_probed = false

func _ready():
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    var label = Label.new()
    label.text = "深度探针运行中"
    label.add_color_override("font_color", Color(0, 1, 0))
    label.add_color_override("font_outline_color", Color(0, 0, 0))
    label.add_constant_override("outline_size", 4)
    label.anchor_left = 1.0
    label.anchor_right = 1.0
    label.margin_left = -250
    label.margin_right = -20
    label.margin_top = 20
    label.align = Label.ALIGN_RIGHT
    canvas.add_child(label)

    set_process(true)

func _process(_delta):
    if _has_probed: return
    var upgrade_ui = get_tree().root.find_node("UpgradesUI", true, false)
    if not upgrade_ui or not upgrade_ui.is_visible_in_tree(): return
    
    _has_probed = true
    yield(get_tree().create_timer(0.5), "timeout")
    _dump_deep(upgrade_ui)

func _dump_deep(upgrade_ui: Node):
    var hbox = upgrade_ui.find_node("UpgradesContainer", true, false).find_node("HBoxContainer", true, false)
    if not hbox: return
    
    var log_text = "=== 深度探针 ===\n"
    for card in hbox.get_children():
        if card is PanelContainer and "UpgradeUI" in card.name:
            log_text += "\n================ [卡片: " + card.name + "] ================\n"
            log_text += _scan_node(card, 1)
    
    var file = File.new()
    if file.open("/storage/emulated/0/Download/Brotato/upgrade_deep_probe.txt", File.WRITE) == OK:
        file.store_string(log_text)
        file.close()
        print("深度探针写入成功！")
        var canvas = get_node_or_null("CanvasLayer")
        if canvas:
            canvas.get_child(0).text = "探针已抓取，请查看文件"

# 递归扫描节点及其所有属性
func _scan_node(node: Node, depth: int) -> String:
    var indent = ""
    for i in range(depth): indent += "  "
    
    var text = indent + "[" + node.get_class() + "] " + str(node.name) + "\n"
    
    # 扫描所有脚本暴露的变量，寻找可能的升级数据
    var found_data = false
    for prop in node.get_property_list():
        var p_name = prop.name
        # 只要名字里带 data, upgrade, item, tier 且不是默认的 UI 属性，都抓出来
        if ("data" in p_name or "upgrade" in p_name or "item" in p_name or "tier" in p_name):
            if p_name in ["item_data", "upgrade_data", "_item_data", "_upgrade_data", "data", "upgrade"]:
                var value = node.get(p_name)
                if value != null:
                    text += indent + "  --> " + p_name + " = " + str(value) + "\n"
                    if "my_id" in value:
                        text += indent + "      + my_id = " + str(value.my_id) + "\n"
                    if "tier" in value:
                        text += indent + "      + tier = " + str(value.tier) + "\n"
                    found_data = true

    for child in node.get_children():
        text += _scan_node(child, depth + 1)
        
    return text
