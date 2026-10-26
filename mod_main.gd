extends Node

var _has_logged = false
var _timer: Timer

const LOG_DIR = "/storage/emulated/0/Download/Brotato/"
const LOG_FILE = "/storage/emulated/0/Download/Brotato/upgrade_debug.txt"

func _ready():
    # 添加一个右上角小提示，证明探针活着
    var canvas = CanvasLayer.new()
    canvas.layer = 100
    add_child(canvas)
    var label = Label.new()
    label.text = "✅ 升级界面探针已加载"
    label.add_color_override("font_color", Color(0, 1, 0))
    label.add_color_override("font_outline_color", Color(0, 0, 0))
    label.add_constant_override("outline_size", 4)
    label.anchor_left = 1.0
    label.anchor_right = 1.0
    label.margin_left = -300
    label.margin_right = -20
    label.margin_top = 20
    label.align = Label.ALIGN_RIGHT
    canvas.add_child(label)

    # 定时寻找升级界面
    _timer = Timer.new()
    _timer.wait_time = 0.5
    _timer.autostart = true
    _timer.connect("timeout", self, "_check_for_upgrade_ui")
    add_child(_timer)

func _check_for_upgrade_ui():
    if _has_logged: return

    # 寻找名字叫 UpgradesUI 的节点（波次结束的升级界面）
    var upgrade_ui = get_tree().root.find_node("UpgradesUI", true, false)
    
    if upgrade_ui != null and upgrade_ui.is_visible_in_tree():
        _has_logged = true
        _timer.stop()
        # 延迟一点，等它排版完
        yield(get_tree().create_timer(0.5), "timeout")
        _write_to_file(upgrade_ui)

# 递归生成树状结构字符串
func _build_tree_string(node: Node, depth: int) -> String:
    var indent = ""
    for i in range(depth):
        indent += "  "
        
    var info = indent + "|-- [" + node.get_class() + "] " + str(node.name)
    
    if node is Control:
        info += " | 大小: " + str(node.rect_size)
    
    # 💥 核心探测：看看卡片里有没有 UpgradeData 的数据
    if "item_data" in node:
        var data = node.item_data
        if data != null:
            info += " | ID: " + str(data.my_id) + " | 品质: " + str(data.tier) + " | 数值: " + str(data.value)
            
    info += "\n" + indent + "    └ 路径: " + str(node.get_path()) + "\n"
    
    for child in node.get_children():
        info += _build_tree_string(child, depth + 1)
    return info

func _write_to_file(target: Node):
    var full_text = "=== 升级界面全量树 ===\n"
    full_text += _build_tree_string(target, 0)

    var dir = Directory.new()
    if not dir.dir_exists(LOG_DIR):
        dir.make_dir_recursive(LOG_DIR)

    var file = File.new()
    var err = file.open(LOG_FILE, File.WRITE)
    
    if err == OK:
        file.store_string(full_text)
        file.close()
        print("升级界面日志写入成功！")
        
        # 在屏幕上更新提示
        var canvas = get_node_or_null("CanvasLayer")
        if canvas:
            canvas.get_child(0).text = "✅ 升级日志已写入 Download/Brotato"
