extends Control

const SAVE_PATH := "user://save.json"
const MAX_OFFLINE_SECONDS := 12.0 * 60.0 * 60.0
const MAX_LEVEL := 20
const REROLL_COST := 50
const BAG_CAPACITY := 12

const CLASSES := ["전사", "마법사", "궁수", "암살자"]
const SLOTS := ["머리", "상의", "하의", "신발", "무기", "보조장비", "장신구"]

const ITEM_NAMES := {
    "전사": {"머리":"전사의 투구","상의":"전사의 갑옷","하의":"전사의 각반","신발":"전사의 철제 장화","무기":"전사의 대검","보조장비":"전사의 방패","장신구":"전사의 팔찌"},
    "마법사": {"머리":"마법사의 모자","상의":"마법사의 로브","하의":"마법사의 바지","신발":"마법사의 신발","무기":"마법사의 지팡이","보조장비":"마법사의 마도서","장신구":"마법사의 반지"},
    "궁수": {"머리":"궁수의 모자","상의":"궁수의 상의","하의":"궁수의 바지","신발":"궁수의 장화","무기":"궁수의 활","보조장비":"궁수의 화살통","장신구":"궁수의 목걸이"},
    "암살자": {"머리":"암살자의 두건","상의":"암살자의 상의","하의":"암살자의 바지","신발":"암살자의 신발","무기":"암살자의 단검","보조장비":"암살자의 독약병","장신구":"암살자의 부적"}
}

const ENHANCE_COST := [100,150,220,320,450,650,900,1250,1700,2300,3100,4200,5600,7400,9800,13000,17000,22000,29000,38000]
const HOURLY_INCOME := [20,30,45,65,90,150,210,290,400,550,900,1200,1600,2200,3000,4500,6500,9500,14000,21000,35000]
const SELL_VALUE := [0,75,190,380,660,1100,1800,3000,4800,8000,14000,24000,38000,53000,72000,110000,160000,230000,340000,500000,840000]
const ENHANCE_TABLE := [
    [80,20,0,0],[76,24,0,0],[72,28,0,0],[68,32,0,0],[64,36,0,0],
    [60,30,10,0],[56,29,15,0],[52,28,20,0],[48,27,25,0],[44,26,25,5],
    [40,28,26,6],[36,29,28,7],[32,30,30,8],[28,31,32,9],[24,32,34,10],
    [20,33,36,11],[16,34,38,12],[12,35,40,13],[8,38,40,14],[5,40,40,15]
]
const SYNERGY_TABLE := {5:{3:0.10,5:0.20,7:0.35},10:{3:0.25,5:0.45,7:0.75},15:{3:0.50,5:0.90,7:1.50},20:{3:0.80,5:1.60,7:3.00}}

var rng := RandomNumberGenerator.new()
var gold: float = 1000.0
var normal_enhance_progress := 0
var has_lucky_coin := false
var anvil_item: Dictionary = {}
var equipped: Dictionary = {}
var bag: Array = []
var selected_class := "전사"
var busy := false
var passive_accumulator := 0.0
var save_accumulator := 0.0
var pending_result := ""
var pending_is_coin := false
var last_offline_gain := 0.0

var gold_label: Label
var income_label: Label
var coin_label: Label
var result_label: Label
var item_title: Label
var item_meta: Label
var probability_label: Label
var progress_bar: ProgressBar
var enhance_button: Button
var coin_button: Button
var equip_button: Button
var sell_button: Button
var reroll_button: Button
var stash_button: Button
var class_selector: OptionButton
var character_income_label: Label
var synergy_label: Label
var equipment_grid: GridContainer
var bag_grid: GridContainer
var animation_bar: ProgressBar
var tabs: TabContainer

func _ready() -> void:
    rng.randomize()
    _init_equipment_structure()
    _load_game()
    if anvil_item.is_empty():
        anvil_item = _random_item(0)
    _build_ui()
    class_selector.select(CLASSES.find(selected_class))
    if not pending_result.is_empty():
        _resolve_pending_result(pending_is_coin)
        _save_game()
    _refresh_all()
    if last_offline_gain > 0.0:
        result_label.text = "오프라인 수입 +%sG가 정산되었습니다." % _fmt(last_offline_gain)

func _process(delta: float) -> void:
    passive_accumulator += delta
    if passive_accumulator >= 1.0:
        var seconds := floor(passive_accumulator)
        passive_accumulator -= seconds
        gold += _total_hourly_income() * seconds / 3600.0
        _refresh_top_bar()
    save_accumulator += delta
    if save_accumulator >= 10.0:
        save_accumulator = 0.0
        _save_game()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_game()

func _init_equipment_structure() -> void:
    equipped.clear()
    for c in CLASSES:
        equipped[c] = {}
        for slot in SLOTS:
            equipped[c][slot] = null

func _make_label(text_value: String, font_size := 28) -> Label:
    var l := Label.new()
    l.text = text_value
    l.add_theme_font_size_override("font_size", font_size)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return l

func _make_button(text_value: String, callback: Callable) -> Button:
    var b := Button.new()
    b.text = text_value
    b.custom_minimum_size = Vector2(0, 82)
    b.add_theme_font_size_override("font_size", 26)
    b.pressed.connect(callback)
    return b

func _build_ui() -> void:
    var root := VBoxContainer.new()
    root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root.offset_left = 28
    root.offset_top = 24
    root.offset_right = -28
    root.offset_bottom = -24
    root.add_theme_constant_override("separation", 18)
    add_child(root)
    var title := _make_label("강화 대장간 · Android Prototype v0.3", 36)
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    root.add_child(title)
    gold_label = _make_label("",30)
    income_label = _make_label("",26)
    coin_label = _make_label("",26)
    root.add_child(gold_label)
    root.add_child(income_label)
    root.add_child(coin_label)
    tabs = TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(tabs)
    _build_forge_tab()
    _build_character_tab()
    _build_bag_tab()
    result_label = _make_label("",28)
    result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result_label.custom_minimum_size.y = 72
    root.add_child(result_label)

func _build_forge_tab() -> void:
    var page := VBoxContainer.new()
    page.name = "대장간"
    page.add_theme_constant_override("separation",16)
    tabs.add_child(page)
    var forge_title := _make_label("거대한 모루",42)
    forge_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    page.add_child(forge_title)
    item_title = _make_label("",38)
    item_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    page.add_child(item_title)
    item_meta = _make_label("",26)
    item_meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    page.add_child(item_meta)
    probability_label = _make_label("",25)
    probability_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    page.add_child(probability_label)
    animation_bar = ProgressBar.new()
    animation_bar.max_value = 100
    animation_bar.custom_minimum_size.y = 34
    page.add_child(animation_bar)
    var buttons := GridContainer.new()
    buttons.columns = 2
    page.add_child(buttons)
    enhance_button = _make_button("망치로 강화",_on_enhance_pressed)
    coin_button = _make_button("행운의 동전 사용",_on_coin_pressed)
    equip_button = _make_button("해당 직업에 장착",_on_equip_pressed)
    sell_button = _make_button("판매",_on_sell_pressed)
    reroll_button = _make_button("+0 다시 뽑기",_on_reroll_pressed)
    stash_button = _make_button("가방 보관 + 새 장비 50G",_on_stash_pressed)
    for b in [enhance_button,coin_button,equip_button,sell_button,reroll_button,stash_button]:
        buttons.add_child(b)
    progress_bar = ProgressBar.new()
    progress_bar.max_value = 100
    progress_bar.custom_minimum_size.y = 44
    page.add_child(progress_bar)
    page.add_child(_make_label("일반 강화 100회 완료 시 행운의 동전 1개. 보유 중에는 다음 동전 진행도가 쌓이지 않습니다.",22))

func _build_character_tab() -> void:
    var page := VBoxContainer.new()
    page.name = "캐릭터"
    tabs.add_child(page)
    class_selector = OptionButton.new()
    class_selector.custom_minimum_size.y = 72
    for c in CLASSES:
        class_selector.add_item(c)
    class_selector.item_selected.connect(_on_class_selected)
    page.add_child(class_selector)
    character_income_label = _make_label("",28)
    synergy_label = _make_label("",24)
    page.add_child(character_income_label)
    page.add_child(synergy_label)
    equipment_grid = GridContainer.new()
    equipment_grid.columns = 1
    page.add_child(equipment_grid)

func _build_bag_tab() -> void:
    var page := VBoxContainer.new()
    page.name = "가방"
    tabs.add_child(page)
    page.add_child(_make_label("여분 장비 12칸. 장비를 누르면 현재 모루 장비와 교체합니다.",23))
    bag_grid = GridContainer.new()
    bag_grid.columns = 2
    page.add_child(bag_grid)

func _random_item(level: int = 0) -> Dictionary:
    var c: String = CLASSES[rng.randi_range(0,CLASSES.size()-1)]
    var slot: String = SLOTS[rng.randi_range(0,SLOTS.size()-1)]
    return {"class":c,"slot":slot,"level":level,"name":ITEM_NAMES[c][slot]}

func _duplicate_item(item) -> Dictionary:
    if item == null:
        return {}
    return {"class":str(item.get("class","전사")),"slot":str(item.get("slot","무기")),"level":int(item.get("level",0)),"name":str(item.get("name","장비"))}

func _item_string(item) -> String:
    if item == null or typeof(item) != TYPE_DICTIONARY or item.is_empty():
        return "비어 있음"
    return "+%d %s" % [int(item.level),str(item.name)]

func _on_enhance_pressed() -> void:
    if busy or anvil_item.is_empty():
        return
    var lv := int(anvil_item.level)
    if lv >= MAX_LEVEL:
        _flash("+20 장비는 이미 졸업했습니다.")
        return
    var cost := ENHANCE_COST[lv]
    if gold < cost:
        _flash("골드가 부족합니다. 필요: %sG" % _fmt(cost))
        return
    gold -= cost
    if not has_lucky_coin:
        normal_enhance_progress += 1
        if normal_enhance_progress >= 100:
            normal_enhance_progress = 0
            has_lucky_coin = true
    pending_result = _roll_normal_result(lv)
    pending_is_coin = false
    _save_game()
    _start_enhance_animation(false)

func _on_coin_pressed() -> void:
    if busy or not has_lucky_coin or anvil_item.is_empty():
        return
    var lv := int(anvil_item.level)
    if lv >= MAX_LEVEL:
        return
    var cost := ENHANCE_COST[lv]
    if gold < cost:
        _flash("동전 강화도 정상 강화비가 필요합니다: %sG" % _fmt(cost))
        return
    gold -= cost
    has_lucky_coin = false
    normal_enhance_progress = 0
    pending_result = "coin_success" if rng.randf() < 0.5 else "coin_down"
    pending_is_coin = true
    _save_game()
    _start_enhance_animation(true)

func _roll_normal_result(level: int) -> String:
    var row = ENHANCE_TABLE[level]
    var r := rng.randi_range(1,100)
    if r <= row[0]:
        return "success"
    r -= row[0]
    if r <= row[1]:
        return "stay"
    r -= row[1]
    if r <= row[2]:
        return "down"
    return "destroy"

func _start_enhance_animation(is_coin: bool) -> void:
    busy = true
    _set_action_buttons_enabled(false)
    result_label.text = "행운의 동전이 모루 위로 날아갑니다…" if is_coin else "망치가 장비를 두드립니다…"
    animation_bar.value = 0
    var tween := create_tween()
    tween.tween_property(animation_bar,"value",100.0,4.0)
    await tween.finished
    _resolve_pending_result(is_coin)
    busy = false
    _refresh_all()
    _save_game()

func _resolve_pending_result(is_coin: bool) -> void:
    var old_level := int(anvil_item.level)
    match pending_result:
        "success","coin_success":
            anvil_item.level = min(MAX_LEVEL,old_level+1)
            result_label.text = "성공! +%d → +%d" % [old_level,int(anvil_item.level)]
        "stay":
            result_label.text = "유지. +%d 그대로입니다." % old_level
        "down","coin_down":
            anvil_item.level = max(0,old_level-1)
            result_label.text = "%s +%d → +%d" % ["동전 뒷면." if is_coin else "하락.",old_level,int(anvil_item.level)]
        "destroy":
            var old_name := str(anvil_item.name)
            anvil_item = _random_item(0)
            result_label.text = "파괴! %s이(가) 부서지고 새로운 +0 장비가 지급되었습니다." % old_name
    pending_result = ""
    pending_is_coin = false

func _on_equip_pressed() -> void:
    if busy or anvil_item.is_empty():
        return
    var c := str(anvil_item["class"])
    var slot := str(anvil_item["slot"])
    var old = equipped[c][slot]
    equipped[c][slot] = _duplicate_item(anvil_item)
    if old == null:
        anvil_item = _random_item(0)
    else:
        anvil_item = _duplicate_item(old)
    selected_class = c
    class_selector.select(CLASSES.find(c))
    _refresh_all()
    _save_game()

func _on_sell_pressed() -> void:
    if busy:
        return
    var lv := int(anvil_item.level)
    if lv <= 0:
        return
    gold += SELL_VALUE[lv]
    anvil_item = _random_item(0)
    _refresh_all()
    _save_game()

func _on_reroll_pressed() -> void:
    if busy or int(anvil_item.level) != 0 or gold < REROLL_COST:
        return
    gold -= REROLL_COST
    anvil_item = _random_item(0)
    _refresh_all()
    _save_game()

func _on_stash_pressed() -> void:
    if busy or bag.size() >= BAG_CAPACITY or gold < REROLL_COST:
        return
    gold -= REROLL_COST
    bag.append(_duplicate_item(anvil_item))
    anvil_item = _random_item(0)
    _refresh_all()
    _save_game()

func _on_class_selected(index: int) -> void:
    selected_class = CLASSES[index]
    _refresh_character_panel()

func _bring_equipped_to_anvil(slot: String) -> void:
    if busy:
        return
    var item = equipped[selected_class][slot]
    if item == null or bag.size() >= BAG_CAPACITY:
        return
    bag.append(_duplicate_item(anvil_item))
    anvil_item = _duplicate_item(item)
    equipped[selected_class][slot] = null
    _refresh_all()
    _save_game()

func _swap_bag_with_anvil(index: int) -> void:
    if busy or index < 0 or index >= bag.size():
        return
    var temp := _duplicate_item(anvil_item)
    anvil_item = _duplicate_item(bag[index])
    bag[index] = temp
    _refresh_all()
    _save_game()

func _remove_bag_item(index: int) -> void:
    if busy or index < 0 or index >= bag.size():
        return
    var item = bag[index]
    var lv := int(item.level)
    if lv > 0:
        gold += SELL_VALUE[lv]
    bag.remove_at(index)
    _refresh_all()
    _save_game()

func _class_base_income(c: String) -> float:
    var total := 0.0
    for slot in SLOTS:
        var item = equipped[c][slot]
        if item != null:
            total += HOURLY_INCOME[int(item.level)]
    return total

func _class_synergy_bonus(c: String) -> float:
    var best := 0.0
    for threshold in [5,10,15,20]:
        var count := 0
        for slot in SLOTS:
            var item = equipped[c][slot]
            if item != null and int(item.level) >= threshold:
                count += 1
        for need in [3,5,7]:
            if count >= need:
                best = max(best,float(SYNERGY_TABLE[threshold][need]))
    return best

func _class_hourly_income(c: String) -> float:
    return _class_base_income(c) * (1.0 + _class_synergy_bonus(c))

func _total_hourly_income() -> float:
    var total := 0.0
    for c in CLASSES:
        total += _class_hourly_income(c)
    return total

func _refresh_all() -> void:
    _refresh_top_bar()
    _refresh_forge_panel()
    _refresh_character_panel()
    _refresh_bag_panel()

func _refresh_top_bar() -> void:
    if gold_label == null:
        return
    gold_label.text = "보유 골드 %s G" % _fmt(floor(gold))
    income_label.text = "4캐릭터 합산 시간당 수입 %s G/h" % _fmt(round(_total_hourly_income()))
    coin_label.text = "행운의 동전 %s | 다음 동전 %d/100" % ["보유 중" if has_lucky_coin else "없음",normal_enhance_progress]

func _refresh_forge_panel() -> void:
    if item_title == null:
        return
    var lv := int(anvil_item.level)
    item_title.text = _item_string(anvil_item)
    item_meta.text = "%s · %s | 기본 %sG/h | 판매 %sG" % [str(anvil_item["class"]),str(anvil_item["slot"]),_fmt(HOURLY_INCOME[lv]),_fmt(SELL_VALUE[lv])]
    if lv < MAX_LEVEL:
        var row = ENHANCE_TABLE[lv]
        probability_label.text = "비용 %sG · 성공 %d%% / 유지 %d%% / 하락 %d%% / 파괴 %d%%" % [_fmt(ENHANCE_COST[lv]),row[0],row[1],row[2],row[3]]
    else:
        probability_label.text = "+20 졸업 장비"
    progress_bar.value = normal_enhance_progress
    enhance_button.disabled = busy or lv >= MAX_LEVEL
    coin_button.disabled = busy or lv >= MAX_LEVEL or not has_lucky_coin
    sell_button.disabled = busy or lv <= 0
    reroll_button.disabled = busy or lv != 0
    stash_button.disabled = busy or bag.size() >= BAG_CAPACITY or gold < REROLL_COST
    equip_button.disabled = busy

func _refresh_character_panel() -> void:
    if equipment_grid == null:
        return
    for child in equipment_grid.get_children():
        child.queue_free()
    character_income_label.text = "%s 시간당 수입: %sG/h" % [selected_class,_fmt(round(_class_hourly_income(selected_class)))]
    synergy_label.text = "현재 시너지 +%d%%" % int(round(_class_synergy_bonus(selected_class)*100.0))
    for slot in SLOTS:
        var slot_name: String = slot
        var item = equipped[selected_class][slot_name]
        var b := _make_button("%s | %s" % [slot_name,_item_string(item)],func(): _bring_equipped_to_anvil(slot_name))
        b.disabled = item == null or busy
        equipment_grid.add_child(b)

func _refresh_bag_panel() -> void:
    if bag_grid == null:
        return
    for child in bag_grid.get_children():
        child.queue_free()
    for i in range(BAG_CAPACITY):
        var bag_index: int = i
        var box := VBoxContainer.new()
        if bag_index < bag.size():
            var b := _make_button("%d. %s" % [bag_index+1,_item_string(bag[bag_index])],func(): _swap_bag_with_anvil(bag_index))
            box.add_child(b)
            box.add_child(_make_button("판매/버리기",func(): _remove_bag_item(bag_index)))
        else:
            var empty := _make_button("%d. 빈 칸" % [bag_index+1],func(): pass)
            empty.disabled = true
            box.add_child(empty)
        bag_grid.add_child(box)

func _set_action_buttons_enabled(enabled: bool) -> void:
    for b in [enhance_button,coin_button,equip_button,sell_button,reroll_button,stash_button]:
        if b != null:
            b.disabled = not enabled

func _flash(message: String) -> void:
    result_label.text = message

func _fmt(value) -> String:
    var n := int(round(float(value)))
    var s := str(abs(n))
    var out := ""
    while s.length() > 3:
        out = "," + s.substr(s.length()-3,3) + out
        s = s.substr(0,s.length()-3)
    out = s + out
    return "-" + out if n < 0 else out

func _save_game() -> void:
    var equipment_data := {}
    for c in CLASSES:
        equipment_data[c] = {}
        for slot in SLOTS:
            var item = equipped[c][slot]
            equipment_data[c][slot] = null if item == null else _duplicate_item(item)
    var data := {
        "version":1,"gold":gold,"normal_enhance_progress":normal_enhance_progress,
        "has_lucky_coin":has_lucky_coin,"anvil_item":_duplicate_item(anvil_item),
        "equipped":equipment_data,"bag":bag,"selected_class":selected_class,
        "pending_result":pending_result,"pending_is_coin":pending_is_coin,
        "last_saved_unix":Time.get_unix_time_from_system()
    }
    var f := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data))

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH,FileAccess.READ)
    if not f:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    gold = float(parsed.get("gold",1000.0))
    normal_enhance_progress = int(parsed.get("normal_enhance_progress",0))
    has_lucky_coin = bool(parsed.get("has_lucky_coin",false))
    pending_result = str(parsed.get("pending_result",""))
    pending_is_coin = bool(parsed.get("pending_is_coin",false))
    anvil_item = _duplicate_item(parsed.get("anvil_item",_random_item(0)))
    selected_class = str(parsed.get("selected_class","전사"))
    var saved_equipped = parsed.get("equipped",{})
    for c in CLASSES:
        for slot in SLOTS:
            var item = null
            if typeof(saved_equipped) == TYPE_DICTIONARY and saved_equipped.has(c):
                var sc = saved_equipped[c]
                if typeof(sc) == TYPE_DICTIONARY and sc.has(slot):
                    item = sc[slot]
            equipped[c][slot] = null if item == null else _duplicate_item(item)
    bag.clear()
    var saved_bag = parsed.get("bag",[])
    if typeof(saved_bag) == TYPE_ARRAY:
        for item in saved_bag:
            if bag.size() >= BAG_CAPACITY:
                break
            if typeof(item) == TYPE_DICTIONARY:
                bag.append(_duplicate_item(item))
    var last_saved := float(parsed.get("last_saved_unix",Time.get_unix_time_from_system()))
    var offline_seconds := clamp(Time.get_unix_time_from_system()-last_saved,0.0,MAX_OFFLINE_SECONDS)
    if offline_seconds > 2.0:
        last_offline_gain = _total_hourly_income() * offline_seconds / 3600.0
        gold += last_offline_gain
