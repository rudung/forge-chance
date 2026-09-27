extends Control

const SAVE_PATH := "user://save.json"
const MAX_LEVEL := 20
const MAX_OFFLINE_SECONDS := 12.0 * 60.0 * 60.0
const CLASSES := ["전사", "마법사", "궁수", "암살자"]
const CLASS_KEYS := ["warrior", "mage", "archer", "assassin"]
const CLASS_COLORS := [Color("ff9b2f"), Color("5f8cff"), Color("70cc63"), Color("c878ff")]
const SLOTS := ["머리", "상의", "하의", "무기", "보조장비", "신발", "장신구"]
const SLOT_ICON_FILES := ["slot_head", "slot_top", "slot_bottom", "slot_weapon", "slot_sub", "slot_shoes", "slot_accessory"]

const ITEM_NAMES := {
    "전사": ["전사의 투구", "전사의 갑옷", "전사의 각반", "용사의 검", "전사의 방패", "전사의 철제 장화", "전사의 팔찌"],
    "마법사": ["마법 모자", "마법사의 로브", "마법사의 바지", "별빛 지팡이", "마도서", "마법사의 신발", "마력 반지"],
    "궁수": ["사냥 모자", "사냥복", "사냥 바지", "수호자의 활", "화살통", "사냥 장화", "숲의 목걸이"],
    "암살자": ["암살 두건", "암살복", "암살 바지", "그림자 단검", "독약병", "암살 신발", "그림자 부적"]
}

const ENHANCE_TABLE := [
    [80,20,0,0],[76,24,0,0],[72,28,0,0],[68,32,0,0],[64,36,0,0],
    [60,30,10,0],[56,29,15,0],[52,28,20,0],[48,27,25,0],[44,26,25,5],
    [40,28,26,6],[36,29,28,7],[32,30,30,8],[28,31,32,9],[24,32,34,10],
    [20,33,36,11],[16,34,38,12],[12,35,40,13],[8,38,40,14],[5,40,40,15]
]

const GPS_BY_LEVEL := [1,2,3,4,5,7,10,14,20,28,40,58,82,115,160,225,315,440,620,880,1250]
const ENHANCE_COST := [100,150,220,320,450,650,900,1250,1700,2300,3100,4200,5600,7400,9800,13000,17000,22000,29000,38000]
const SYNERGY_TABLE := {
    5:{3:0.10,5:0.20,7:0.35},
    10:{3:0.25,5:0.45,7:0.75},
    15:{3:0.50,5:0.90,7:1.50},
    20:{3:0.80,5:1.60,7:3.00}
}

const ACHIEVEMENTS := [
    {"id":"first_enhance", "title":"첫 담금질", "desc":"일반 강화를 1회 완료"},
    {"id":"enhance_100", "title":"이제 시작이다", "desc":"일반 강화 100회 완료"},
    {"id":"enhance_1000", "title":"망치 중독", "desc":"일반 강화 1,000회 완료"},
    {"id":"first_10", "title":"위험한 선택", "desc":"처음으로 +10 달성"},
    {"id":"first_15", "title":"불꽃을 넘어서", "desc":"처음으로 +15 달성"},
    {"id":"first_20", "title":"전설의 장비", "desc":"처음으로 +20 달성"},
    {"id":"first_destroy", "title":"산산조각", "desc":"첫 장비 파괴"},
    {"id":"destroy_100", "title":"익숙한 파열음", "desc":"장비 파괴 100회"},
    {"id":"warrior_complete", "title":"전사의 완성", "desc":"전사 7부위 모두 +20"},
    {"id":"mage_complete", "title":"마법사의 완성", "desc":"마법사 7부위 모두 +20"},
    {"id":"archer_complete", "title":"궁수의 완성", "desc":"궁수 7부위 모두 +20"},
    {"id":"assassin_complete", "title":"암살자의 완성", "desc":"암살자 7부위 모두 +20"},
    {"id":"all_complete", "title":"대장장이의 끝", "desc":"28부위 모두 +20"}
]

var rng := RandomNumberGenerator.new()
var gold := 1000.0
var levels: Dictionary = {}
var selected_class := 0
var selected_slot := 3
var normal_progress := 0
var has_lucky_coin := false
var total_normal_attempts := 0
var total_destroys := 0
var unlocked: Dictionary = {}
var unseen_achievement := false
var busy := false
var pending_result := ""
var pending_class := 0
var pending_slot := 0
var pending_is_coin := false
var passive_fraction := 0.0
var save_accumulator := 0.0
var last_offline_gain := 0.0
var sequence_kind := ""
var sequence_elapsed := 0.0
var result_hold := 0.0

var main_layer: Control
var background: TextureRect
var class_panels: Array = []
var class_buttons: Array = []
var slot_buttons: Array = []
var gold_label: Label
var gps_label: Label
var item_name_label: Label
var item_level_label: Label
var item_icon: TextureRect
var info_current_label: Label
var info_synergy_label: Label
var info_success_label: Label
var probability_label: Label
var stage_label: Label
var status_label: Label
var progress_bar: ProgressBar
var enhance_button: Button
var coin_button: Button
var forge_nav_button: Button
var achievement_nav_button: Button
var fx: Control
var result_panel: Panel
var result_title: Label
var result_detail: Label
var modal_overlay: ColorRect
var coin_modal: Panel
var achievements_screen: Control
var achievements_list: VBoxContainer

func _ready() -> void:
    rng.randomize()
    _init_levels()
    _load_game()
    _build_ui()
    if pending_result != "":
        _resolve_pending_immediately()
    _refresh_all()
    if last_offline_gain > 0.0:
        _flash("오프라인 수입 +%sG 정산" % _fmt(last_offline_gain))
    _save_game()

func _process(delta: float) -> void:
    if sequence_kind != "":
        sequence_elapsed += delta
        if sequence_kind == "normal":
            progress_bar.visible = true
            progress_bar.value = minf(100.0, sequence_elapsed / 4.0 * 100.0)
            if sequence_elapsed >= 4.0:
                sequence_kind = ""
                progress_bar.visible = false
                _apply_and_show_result(false)
        elif sequence_kind == "coin":
            if sequence_elapsed >= 2.4:
                sequence_kind = ""
                _apply_and_show_result(true)

    if result_hold > 0.0:
        result_hold -= delta
        if result_hold <= 0.0:
            result_panel.visible = false
            fx.set_mode("idle")
            status_label.text = ""
            busy = false
            _refresh_all()
            _save_game()
            print("ENHANCE_DONE level=", _selected_level(), " busy=", busy)

    if not busy:
        gold += _total_gps() * delta

    passive_fraction += delta
    if passive_fraction >= 0.10:
        passive_fraction = 0.0
        _refresh_top_bar()

    save_accumulator += delta
    if save_accumulator >= 8.0:
        save_accumulator = 0.0
        _save_game()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
        _save_game()

func _init_levels() -> void:
    levels.clear()
    for c in CLASSES:
        levels[c] = []
        for _i in range(SLOTS.size()):
            levels[c].append(0)

func _build_ui() -> void:
    main_layer = Control.new()
    main_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    add_child(main_layer)

    background = TextureRect.new()
    background.texture = load("res://assets/forge_bg.svg")
    background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    background.stretch_mode = TextureRect.STRETCH_SCALE
    background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    background.mouse_filter = Control.MOUSE_FILTER_IGNORE
    main_layer.add_child(background)

    var dim := ColorRect.new()
    dim.color = Color(0.0, 0.0, 0.0, 0.16)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    main_layer.add_child(dim)

    _build_top_bar()
    _build_class_tabs()
    _build_slot_list()
    _build_center_area()
    _build_info_panel()
    _build_action_area()
    _build_bottom_nav()
    _build_result_panel()
    _build_coin_modal()
    _build_achievements_screen()

func _build_top_bar() -> void:
    var p := _panel(Rect2(118, 22, 844, 88), Color(0.035,0.025,0.020,0.95), Color("9d632e"), 4)
    main_layer.add_child(p)
    gold_label = _label("", 34, Color("ffe1a0"), HORIZONTAL_ALIGNMENT_LEFT)
    _place(gold_label, 48, 15, 360, 58)
    p.add_child(gold_label)
    gps_label = _label("", 34, Color("ffd05a"), HORIZONTAL_ALIGNMENT_RIGHT)
    _place(gps_label, 430, 15, 365, 58)
    p.add_child(gps_label)

func _build_class_tabs() -> void:
    var x0 := 78.0
    var y := 126.0
    var w := 220.0
    var h := 164.0
    var gap := 10.0
    for i in range(CLASSES.size()):
        var p := _panel(Rect2(x0 + i * (w + gap), y, w, h), Color(0.025,0.020,0.018,0.95), Color("6e4b31"), 3)
        main_layer.add_child(p)
        class_panels.append(p)

        var tex := TextureRect.new()
        tex.texture = load("res://assets/class_%s.svg" % CLASS_KEYS[i])
        tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        _place(tex, 5, 5, w - 10, 118)
        tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
        p.add_child(tex)

        var name := _label(CLASSES[i], 27, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
        _place(name, 0, 122, w, 38)
        p.add_child(name)

        var b := Button.new()
        b.flat = true
        b.text = ""
        b.focus_mode = Control.FOCUS_NONE
        _place(b, 0, 0, w, h)
        b.pressed.connect(_on_class_pressed.bind(i))
        p.add_child(b)
        class_buttons.append(b)

func _build_slot_list() -> void:
    var x := 28.0
    var y0 := 325.0
    var w := 275.0
    var h := 105.0
    var gap := 8.0
    for i in range(SLOTS.size()):
        var b := Button.new()
        b.text = ""
        b.focus_mode = Control.FOCUS_NONE
        _place(b, x, y0 + i * (h + gap), w, h)
        b.pressed.connect(_on_slot_pressed.bind(i))
        main_layer.add_child(b)
        slot_buttons.append(b)

        var icon := TextureRect.new()
        icon.texture = load("res://assets/%s.svg" % SLOT_ICON_FILES[i])
        icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
        icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
        icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
        _place(icon, 8, 6, 92, 92)
        b.add_child(icon)

        var slot_name := _label(SLOTS[i], 26, Color("f4dfc2"), HORIZONTAL_ALIGNMENT_LEFT)
        slot_name.name = "SlotName"
        _place(slot_name, 108, 12, 150, 36)
        b.add_child(slot_name)

        var lv := _label("+0", 29, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
        lv.name = "Level"
        _place(lv, 110, 53, 142, 38)
        b.add_child(lv)

func _build_center_area() -> void:
    var title_panel := _panel(Rect2(336, 350, 360, 90), Color(0.03,0.02,0.018,0.88), Color("7b4d2a"), 3)
    main_layer.add_child(title_panel)
    item_name_label = _label("", 34, Color("ff6a3d"), HORIZONTAL_ALIGNMENT_CENTER)
    _place(item_name_label, 8, 10, 344, 42)
    title_panel.add_child(item_name_label)
    item_level_label = _label("", 24, Color("ffe2ad"), HORIZONTAL_ALIGNMENT_CENTER)
    _place(item_level_label, 8, 50, 344, 32)
    title_panel.add_child(item_level_label)

    var icon_holder := _panel(Rect2(340, 462, 360, 470), Color(0.02,0.015,0.012,0.24), Color(1,0.45,0.08,0.18), 2)
    main_layer.add_child(icon_holder)

    item_icon = TextureRect.new()
    item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    item_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    item_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _place(item_icon, 70, 70, 220, 220)
    icon_holder.add_child(item_icon)

    var anvil_text := _label("◆  모루  ◆", 34, Color("ffb04b"), HORIZONTAL_ALIGNMENT_CENTER)
    _place(anvil_text, 20, 330, 320, 52)
    icon_holder.add_child(anvil_text)

    fx = preload("res://scripts/ForgeFX.gd").new()
    _place(fx, 0, 0, 360, 470)
    icon_holder.add_child(fx)

    progress_bar = ProgressBar.new()
    progress_bar.min_value = 0
    progress_bar.max_value = 100
    progress_bar.value = 0
    progress_bar.show_percentage = false
    progress_bar.visible = false
    _place(progress_bar, 24, 405, 312, 26)
    icon_holder.add_child(progress_bar)
    _style_progress(progress_bar)

func _build_info_panel() -> void:
    var p := _panel(Rect2(720, 350, 332, 682), Color(0.025,0.020,0.018,0.95), Color("8e603a"), 4)
    main_layer.add_child(p)
    var header := _label("장비 정보", 30, Color("ff9255"), HORIZONTAL_ALIGNMENT_CENTER)
    _place(header, 12, 14, 308, 44)
    p.add_child(header)

    var line1 := ColorRect.new()
    line1.color = Color("6b4329")
    _place(line1, 20, 68, 292, 2)
    p.add_child(line1)

    var current_title := _label("현재 효과", 26, Color("ffc85b"), HORIZONTAL_ALIGNMENT_LEFT)
    _place(current_title, 24, 90, 280, 38)
    p.add_child(current_title)
    info_current_label = _label("", 28, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
    _place(info_current_label, 24, 132, 284, 94)
    p.add_child(info_current_label)

    var synergy_title := _label("적용된 강화단계 시너지", 24, Color("ffc85b"), HORIZONTAL_ALIGNMENT_LEFT)
    _place(synergy_title, 24, 250, 284, 42)
    p.add_child(synergy_title)
    info_synergy_label = _label("", 27, Color("b9f59e"), HORIZONTAL_ALIGNMENT_LEFT)
    _place(info_synergy_label, 24, 294, 284, 86)
    p.add_child(info_synergy_label)

    var success_title := _label("강화 성공 시", 26, Color("bdf28f"), HORIZONTAL_ALIGNMENT_LEFT)
    _place(success_title, 24, 414, 284, 40)
    p.add_child(success_title)
    info_success_label = _label("", 27, Color("e7ffd0"), HORIZONTAL_ALIGNMENT_LEFT)
    _place(info_success_label, 24, 456, 284, 106)
    p.add_child(info_success_label)

    probability_label = _label("", 21, Color("e9c7a8"), HORIZONTAL_ALIGNMENT_LEFT)
    probability_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _place(probability_label, 24, 588, 284, 76)
    p.add_child(probability_label)

func _build_action_area() -> void:
    var stage_panel := _panel(Rect2(335, 1056, 382, 86), Color(0.025,0.020,0.018,0.96), Color("a66a31"), 4)
    main_layer.add_child(stage_panel)
    stage_label = _label("", 39, Color("ffe38f"), HORIZONTAL_ALIGNMENT_CENTER)
    _place(stage_label, 0, 14, 382, 56)
    stage_panel.add_child(stage_label)

    enhance_button = Button.new()
    enhance_button.focus_mode = Control.FOCUS_NONE
    _place(enhance_button, 245, 1170, 550, 168)
    enhance_button.pressed.connect(_on_enhance_pressed)
    main_layer.add_child(enhance_button)
    _style_enhance_button(enhance_button)

    var hammer_icon := TextureRect.new()
    hammer_icon.texture = load("res://assets/hammer.svg")
    hammer_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    hammer_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    hammer_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    hammer_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _place(hammer_icon, 18, 18, 150, 130)
    enhance_button.add_child(hammer_icon)

    var enh_text := _label("강화하기", 43, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    enh_text.name = "ActionText"
    _place(enh_text, 150, 30, 355, 58)
    enhance_button.add_child(enh_text)
    var cost_text := _label("", 30, Color("ffe2a5"), HORIZONTAL_ALIGNMENT_CENTER)
    cost_text.name = "CostText"
    _place(cost_text, 150, 93, 355, 42)
    enhance_button.add_child(cost_text)

    coin_button = Button.new()
    coin_button.focus_mode = Control.FOCUS_NONE
    _place(coin_button, 812, 1170, 225, 168)
    coin_button.pressed.connect(_on_coin_pressed)
    main_layer.add_child(coin_button)

    var coin_icon := TextureRect.new()
    coin_icon.texture = load("res://assets/coin.svg")
    coin_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    coin_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coin_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    coin_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
    coin_icon.name = "CoinIcon"
    _place(coin_icon, 48, 14, 128, 112)
    coin_button.add_child(coin_icon)
    var coin_count := _label("0/100", 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    coin_count.name = "CoinCount"
    _place(coin_count, 15, 124, 195, 34)
    coin_button.add_child(coin_count)

    status_label = _label("", 25, Color("ffe0b0"), HORIZONTAL_ALIGNMENT_CENTER)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _place(status_label, 170, 1380, 740, 88)
    main_layer.add_child(status_label)

func _build_bottom_nav() -> void:
    forge_nav_button = Button.new()
    forge_nav_button.text = "⚒  대장간"
    forge_nav_button.add_theme_font_size_override("font_size", 35)
    forge_nav_button.focus_mode = Control.FOCUS_NONE
    _place(forge_nav_button, 75, 1690, 455, 160)
    forge_nav_button.pressed.connect(_show_forge)
    main_layer.add_child(forge_nav_button)
    _style_nav(forge_nav_button, true)

    achievement_nav_button = Button.new()
    achievement_nav_button.text = "🏆  업적"
    achievement_nav_button.add_theme_font_size_override("font_size", 35)
    achievement_nav_button.focus_mode = Control.FOCUS_NONE
    _place(achievement_nav_button, 550, 1690, 455, 160)
    achievement_nav_button.pressed.connect(_show_achievements)
    main_layer.add_child(achievement_nav_button)
    _style_nav(achievement_nav_button, false)

func _build_result_panel() -> void:
    result_panel = _panel(Rect2(275, 520, 530, 350), Color(0.02,0.015,0.012,0.96), Color("b76d31"), 5)
    result_panel.visible = false
    main_layer.add_child(result_panel)
    result_title = _label("", 54, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    _place(result_title, 16, 72, 498, 80)
    result_panel.add_child(result_title)
    result_detail = _label("", 38, Color("ffe3a5"), HORIZONTAL_ALIGNMENT_CENTER)
    _place(result_detail, 16, 175, 498, 86)
    result_panel.add_child(result_detail)

func _build_coin_modal() -> void:
    modal_overlay = ColorRect.new()
    modal_overlay.color = Color(0,0,0,0.72)
    modal_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    modal_overlay.visible = false
    main_layer.add_child(modal_overlay)

    coin_modal = _panel(Rect2(145, 610, 790, 650), Color(0.025,0.018,0.015,0.985), Color("d99032"), 5)
    modal_overlay.add_child(coin_modal)
    var title := _label("행운의 동전 사용", 45, Color("ffd25e"), HORIZONTAL_ALIGNMENT_CENTER)
    _place(title, 40, 45, 710, 65)
    coin_modal.add_child(title)
    var coin_image := TextureRect.new()
    coin_image.texture = load("res://assets/coin.svg")
    coin_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    coin_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    coin_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
    _place(coin_image, 275, 125, 240, 190)
    coin_modal.add_child(coin_image)
    var desc := _label("앞면 50%  →  무조건 +1\n뒷면 50%  →  무조건 -1\n\n유지 없음 · 파괴 없음\n현재 강화단계와 무관하게 적용됩니다.", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
    desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _place(desc, 60, 315, 670, 190)
    coin_modal.add_child(desc)
    var cancel := Button.new()
    cancel.text = "취소"
    cancel.add_theme_font_size_override("font_size", 31)
    _place(cancel, 90, 535, 270, 82)
    cancel.pressed.connect(_close_coin_modal)
    coin_modal.add_child(cancel)
    _style_small_button(cancel, false)
    var use := Button.new()
    use.text = "사용하기"
    use.add_theme_font_size_override("font_size", 31)
    _place(use, 430, 535, 270, 82)
    use.pressed.connect(_confirm_coin_use)
    coin_modal.add_child(use)
    _style_small_button(use, true)

func _build_achievements_screen() -> void:
    achievements_screen = Control.new()
    achievements_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    achievements_screen.visible = false
    add_child(achievements_screen)

    var bg := TextureRect.new()
    bg.texture = load("res://assets/forge_bg.svg")
    bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    bg.stretch_mode = TextureRect.STRETCH_SCALE
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    achievements_screen.add_child(bg)
    var dim := ColorRect.new()
    dim.color = Color(0,0,0,0.58)
    dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    achievements_screen.add_child(dim)

    var title_panel := _panel(Rect2(90, 65, 900, 125), Color(0.025,0.018,0.015,0.96), Color("b57a38"), 4)
    achievements_screen.add_child(title_panel)
    var title := _label("🏆  업적", 48, Color("ffd05c"), HORIZONTAL_ALIGNMENT_CENTER)
    _place(title, 0, 26, 900, 68)
    title_panel.add_child(title)

    var scroll := ScrollContainer.new()
    _place(scroll, 90, 225, 900, 1420)
    achievements_screen.add_child(scroll)
    achievements_list = VBoxContainer.new()
    achievements_list.custom_minimum_size = Vector2(860, 0)
    achievements_list.add_theme_constant_override("separation", 18)
    scroll.add_child(achievements_list)

    var back := Button.new()
    back.text = "← 대장간으로"
    back.add_theme_font_size_override("font_size", 34)
    _place(back, 255, 1695, 570, 120)
    back.pressed.connect(_show_forge)
    achievements_screen.add_child(back)
    _style_nav(back, true)

func _on_class_pressed(index: int) -> void:
    if busy:
        return
    selected_class = index
    _refresh_all()
    _save_game()

func _on_slot_pressed(index: int) -> void:
    if busy:
        return
    selected_slot = index
    _refresh_all()
    _save_game()

func _on_enhance_pressed() -> void:
    if busy:
        return
    var lv := _selected_level()
    if lv >= MAX_LEVEL:
        _flash("+20 장비는 졸업했습니다.")
        return
    var cost: int = int(ENHANCE_COST[lv])
    if gold < cost:
        _flash("골드가 부족합니다. 필요 %sG" % _fmt(cost))
        return

    gold -= cost
    total_normal_attempts += 1
    if not has_lucky_coin:
        normal_progress += 1
        if normal_progress >= 100:
            normal_progress = 100
            has_lucky_coin = true
    pending_result = _roll_normal_result(lv)
    pending_class = selected_class
    pending_slot = selected_slot
    pending_is_coin = false
    _check_achievements()
    _save_game()
    _begin_normal_enhancement()

func _on_coin_pressed() -> void:
    if busy:
        return
    if not has_lucky_coin:
        _flash("일반 강화 %d/100" % normal_progress)
        return
    if _selected_level() >= MAX_LEVEL:
        _flash("+20 장비에는 행운의 동전을 사용할 수 없습니다.")
        return
    modal_overlay.visible = true

func _close_coin_modal() -> void:
    modal_overlay.visible = false

func _confirm_coin_use() -> void:
    if busy or not has_lucky_coin:
        modal_overlay.visible = false
        return
    var lv := _selected_level()
    if lv >= MAX_LEVEL:
        modal_overlay.visible = false
        return
    var cost: int = int(ENHANCE_COST[lv])
    if gold < cost:
        modal_overlay.visible = false
        _flash("행운의 동전도 강화비 %sG가 필요합니다." % _fmt(cost))
        return

    modal_overlay.visible = false
    gold -= cost
    has_lucky_coin = false
    normal_progress = 0
    pending_result = "coin_front" if rng.randf() < 0.5 else "coin_back"
    pending_class = selected_class
    pending_slot = selected_slot
    pending_is_coin = true
    _save_game()
    _begin_coin_enhancement()

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

func _begin_normal_enhancement() -> void:
    busy = true
    print("ENHANCE_START normal class=", CLASSES[selected_class], " slot=", SLOTS[selected_slot], " level=", _selected_level())
    enhance_button.release_focus()
    coin_button.release_focus()
    _refresh_interaction_state()
    result_panel.visible = false
    result_hold = 0.0
    sequence_kind = "normal"
    sequence_elapsed = 0.0
    status_label.text = "빛나는 기운이 장비로 모여듭니다..."
    fx.set_mode("charging")
    progress_bar.visible = true
    progress_bar.value = 0.0

func _begin_coin_enhancement() -> void:
    busy = true
    print("ENHANCE_START coin class=", CLASSES[selected_class], " slot=", SLOTS[selected_slot], " level=", _selected_level())
    enhance_button.release_focus()
    coin_button.release_focus()
    _refresh_interaction_state()
    result_panel.visible = false
    result_hold = 0.0
    sequence_kind = "coin"
    sequence_elapsed = 0.0
    status_label.text = "행운의 동전이 모루 위로 떠오릅니다..."
    fx.set_mode("coin_spin")
    progress_bar.visible = false

func _apply_and_show_result(is_coin: bool) -> void:
    var c := pending_class
    var s := pending_slot
    var cname: String = CLASSES[c]
    var old_level := int(levels[cname][s])
    var new_level := old_level
    var title := ""
    var detail := ""
    var mode := "stay"

    match pending_result:
        "success":
            new_level = min(MAX_LEVEL, old_level + 1)
            levels[cname][s] = new_level
            title = "강화 성공!"
            detail = "+%d  ▶  +%d" % [old_level, new_level]
            mode = "success"
        "stay":
            title = "강화 유지"
            detail = "+%d  (변화 없음)" % old_level
            mode = "stay"
        "down":
            new_level = max(0, old_level - 1)
            levels[cname][s] = new_level
            title = "강화 하락!"
            detail = "+%d  ▶  +%d" % [old_level, new_level]
            mode = "down"
        "destroy":
            levels[cname][s] = 0
            new_level = 0
            total_destroys += 1
            title = "강화 파괴!"
            detail = "+%d  ▶  +0" % old_level
            mode = "destroy"
        "coin_front":
            new_level = min(MAX_LEVEL, old_level + 1)
            levels[cname][s] = new_level
            title = "앞면!  무조건 +1"
            detail = "+%d  ▶  +%d" % [old_level, new_level]
            mode = "coin_front"
        "coin_back":
            new_level = max(0, old_level - 1)
            levels[cname][s] = new_level
            title = "뒷면!  무조건 -1"
            detail = "+%d  ▶  +%d" % [old_level, new_level]
            mode = "coin_back"

    pending_result = ""
    pending_is_coin = false
    _check_achievements()
    _save_game()
    fx.set_mode(mode)
    _show_result(title, detail, mode)
    print("ENHANCE_RESULT mode=", mode, " old=", old_level, " new=", new_level)
    if mode == "destroy":
        _screen_shake()
    result_hold = 1.9 if is_coin else 1.65

func _resolve_pending_immediately() -> void:
    var c := clampi(pending_class, 0, CLASSES.size() - 1)
    var s := clampi(pending_slot, 0, SLOTS.size() - 1)
    var cname: String = CLASSES[c]
    var old_level := int(levels[cname][s])
    match pending_result:
        "success", "coin_front":
            levels[cname][s] = min(MAX_LEVEL, old_level + 1)
        "stay":
            pass
        "down", "coin_back":
            levels[cname][s] = max(0, old_level - 1)
        "destroy":
            levels[cname][s] = 0
            total_destroys += 1
    pending_result = ""
    pending_is_coin = false
    _check_achievements()
    _save_game()

func _show_result(title: String, detail: String, mode: String) -> void:
    result_title.text = title
    result_detail.text = detail
    match mode:
        "success", "coin_front":
            result_title.add_theme_color_override("font_color", Color("ffd05a"))
            result_detail.add_theme_color_override("font_color", Color("fff0ad"))
        "stay":
            result_title.add_theme_color_override("font_color", Color("65b9ff"))
            result_detail.add_theme_color_override("font_color", Color("c8e9ff"))
        "down":
            result_title.add_theme_color_override("font_color", Color("c87aff"))
            result_detail.add_theme_color_override("font_color", Color("ead3ff"))
        "destroy", "coin_back":
            result_title.add_theme_color_override("font_color", Color("ff5548"))
            result_detail.add_theme_color_override("font_color", Color("ffb0a9"))
    result_panel.visible = true

func _screen_shake() -> void:
    var base := main_layer.position
    var t := create_tween()
    for off in [Vector2(-16,8), Vector2(14,-10), Vector2(-12,-7), Vector2(10,8), Vector2(-7,4), Vector2(5,-3)]:
        t.tween_property(main_layer, "position", base + off, 0.045)
    t.tween_property(main_layer, "position", base, 0.055)

func _show_achievements() -> void:
    if busy:
        return
    unseen_achievement = false
    _refresh_achievement_list()
    achievements_screen.visible = true
    main_layer.visible = false
    _save_game()

func _show_forge() -> void:
    achievements_screen.visible = false
    main_layer.visible = true
    _refresh_all()

func _refresh_all() -> void:
    _refresh_top_bar()
    _refresh_class_tabs()
    _refresh_slot_buttons()
    _refresh_selected_item()
    _refresh_action_area()
    _refresh_interaction_state()
    _refresh_nav()

func _refresh_top_bar() -> void:
    gold_label.text = "●  %s" % _fmt(floor(gold))
    gps_label.text = "✦  +%s G/s" % _fmt(round(_total_gps()))

func _refresh_class_tabs() -> void:
    for i in range(class_panels.size()):
        var p: Panel = class_panels[i]
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.025,0.020,0.018,0.94)
        style.border_width_left = 5 if i == selected_class else 2
        style.border_width_top = 5 if i == selected_class else 2
        style.border_width_right = 5 if i == selected_class else 2
        style.border_width_bottom = 5 if i == selected_class else 2
        style.border_color = Color("ffad35") if i == selected_class else Color("62442e")
        style.corner_radius_top_left = 6
        style.corner_radius_top_right = 6
        style.corner_radius_bottom_left = 6
        style.corner_radius_bottom_right = 6
        p.add_theme_stylebox_override("panel", style)

func _refresh_slot_buttons() -> void:
    var cname: String = CLASSES[selected_class]
    for i in range(slot_buttons.size()):
        var b: Button = slot_buttons[i]
        var lv := int(levels[cname][i])
        var level_label := b.get_node("Level") as Label
        level_label.text = "+%d" % lv
        level_label.add_theme_color_override("font_color", _level_color(lv))
        _style_slot_button(b, i == selected_slot)

func _refresh_selected_item() -> void:
    var cname: String = CLASSES[selected_class]
    var lv := _selected_level()
    item_name_label.text = ITEM_NAMES[cname][selected_slot]
    item_name_label.add_theme_color_override("font_color", CLASS_COLORS[selected_class])
    item_level_label.text = "%s · +%d" % [SLOTS[selected_slot], lv]
    item_icon.texture = load("res://assets/%s.svg" % SLOT_ICON_FILES[selected_slot])
    item_icon.modulate = Color.WHITE

    var base_gps: int = int(GPS_BY_LEVEL[lv])
    var synergy := _class_synergy_bonus(cname)
    info_current_label.text = "선택 장비\n+%s G/s" % _fmt(base_gps)
    info_synergy_label.text = "%s 시너지\n+%d%%" % [cname, int(round(synergy * 100.0))]

    if lv < MAX_LEVEL:
        var current_total := _total_gps()
        levels[cname][selected_slot] = lv + 1
        var next_total := _total_gps()
        levels[cname][selected_slot] = lv
        var gain: float = maxf(0.0, next_total - current_total)
        info_success_label.text = "계정 수입\n+%s G/s 증가" % _fmt(round(gain))
        var row = ENHANCE_TABLE[lv]
        probability_label.text = "성공 %d%% · 유지 %d%%\n하락 %d%% · 파괴 %d%%" % [row[0], row[1], row[2], row[3]]
        stage_label.text = "+%d  ▶  +%d" % [lv, lv + 1]
    else:
        info_success_label.text = "최종 강화 완료\n+20 졸업 장비"
        probability_label.text = "더 이상 강화할 수 없습니다."
        stage_label.text = "+20  ★  졸업"

func _refresh_action_area() -> void:
    var lv := _selected_level()
    var cost_label := enhance_button.get_node("CostText") as Label
    if lv < MAX_LEVEL:
        cost_label.text = "●  %s" % _fmt(ENHANCE_COST[lv])
    else:
        cost_label.text = "MAX"

    var coin_icon := coin_button.get_node("CoinIcon") as TextureRect
    var coin_count := coin_button.get_node("CoinCount") as Label
    if has_lucky_coin:
        coin_icon.modulate = Color(1.0, 0.86, 0.35, 1.0)
        coin_count.text = ""
        _style_coin_button(true)
    else:
        coin_icon.modulate = Color(0.46,0.46,0.48,1.0)
        coin_count.text = "%d/100" % normal_progress
        _style_coin_button(false)

func _refresh_interaction_state() -> void:
    var lv := _selected_level()
    enhance_button.disabled = busy or lv >= MAX_LEVEL
    coin_button.disabled = busy or lv >= MAX_LEVEL or not has_lucky_coin
    for b in class_buttons:
        b.disabled = busy
    for b in slot_buttons:
        b.disabled = busy
    achievement_nav_button.disabled = busy

func _refresh_nav() -> void:
    achievement_nav_button.text = "🏆  업적%s" % ("  ●" if unseen_achievement else "")

func _refresh_achievement_list() -> void:
    for child in achievements_list.get_children():
        child.queue_free()
    for ach in ACHIEVEMENTS:
        var is_unlocked := bool(unlocked.get(ach.id, false))
        var p := Panel.new()
        p.custom_minimum_size = Vector2(850, 125)
        var style := StyleBoxFlat.new()
        style.bg_color = Color(0.025,0.020,0.018,0.95)
        style.border_width_left = 3
        style.border_width_top = 3
        style.border_width_right = 3
        style.border_width_bottom = 3
        style.border_color = Color("d58a35") if is_unlocked else Color("4c4038")
        style.corner_radius_top_left = 7
        style.corner_radius_top_right = 7
        style.corner_radius_bottom_left = 7
        style.corner_radius_bottom_right = 7
        p.add_theme_stylebox_override("panel", style)
        achievements_list.add_child(p)
        var icon := _label("★" if is_unlocked else "◇", 42, Color("ffd05a") if is_unlocked else Color("6d6864"), HORIZONTAL_ALIGNMENT_CENTER)
        _place(icon, 18, 30, 70, 60)
        p.add_child(icon)
        var title := _label(ach.title, 30, Color.WHITE if is_unlocked else Color("99918b"), HORIZONTAL_ALIGNMENT_LEFT)
        _place(title, 100, 20, 700, 44)
        p.add_child(title)
        var desc := _label(ach.desc, 23, Color("e4cdbb") if is_unlocked else Color("786e68"), HORIZONTAL_ALIGNMENT_LEFT)
        _place(desc, 100, 69, 700, 34)
        p.add_child(desc)

func _selected_level() -> int:
    return int(levels[CLASSES[selected_class]][selected_slot])

func _class_base_gps(cname: String) -> float:
    var total := 0.0
    for lv in levels[cname]:
        total += GPS_BY_LEVEL[int(lv)]
    return total

func _class_synergy_bonus(cname: String) -> float:
    var best := 0.0
    for threshold in [5, 10, 15, 20]:
        var count := 0
        for lv in levels[cname]:
            if int(lv) >= threshold:
                count += 1
        for need in [3, 5, 7]:
            if count >= need:
                best = max(best, float(SYNERGY_TABLE[threshold][need]))
    return best

func _class_gps(cname: String) -> float:
    return _class_base_gps(cname) * (1.0 + _class_synergy_bonus(cname))

func _total_gps() -> float:
    var total := 0.0
    for cname in CLASSES:
        total += _class_gps(cname)
    return total

func _check_achievements() -> void:
    _unlock_if("first_enhance", total_normal_attempts >= 1)
    _unlock_if("enhance_100", total_normal_attempts >= 100)
    _unlock_if("enhance_1000", total_normal_attempts >= 1000)
    _unlock_if("first_destroy", total_destroys >= 1)
    _unlock_if("destroy_100", total_destroys >= 100)

    var max_lv := 0
    for cname in CLASSES:
        for lv in levels[cname]:
            max_lv = max(max_lv, int(lv))
    _unlock_if("first_10", max_lv >= 10)
    _unlock_if("first_15", max_lv >= 15)
    _unlock_if("first_20", max_lv >= 20)

    _unlock_if("warrior_complete", _class_complete("전사"))
    _unlock_if("mage_complete", _class_complete("마법사"))
    _unlock_if("archer_complete", _class_complete("궁수"))
    _unlock_if("assassin_complete", _class_complete("암살자"))
    _unlock_if("all_complete", _class_complete("전사") and _class_complete("마법사") and _class_complete("궁수") and _class_complete("암살자"))

func _unlock_if(id: String, condition: bool) -> void:
    if condition and not bool(unlocked.get(id, false)):
        unlocked[id] = true
        unseen_achievement = true

func _class_complete(cname: String) -> bool:
    for lv in levels[cname]:
        if int(lv) < MAX_LEVEL:
            return false
    return true

func _flash(message: String) -> void:
    status_label.text = message
    var t := create_tween()
    t.tween_interval(1.6)
    t.tween_callback(func():
        if not busy:
            status_label.text = ""
    )

func _save_game() -> void:
    var data := {
        "version": 10,
        "gold": gold,
        "levels": levels,
        "selected_class": selected_class,
        "selected_slot": selected_slot,
        "normal_progress": normal_progress,
        "has_lucky_coin": has_lucky_coin,
        "total_normal_attempts": total_normal_attempts,
        "total_destroys": total_destroys,
        "unlocked": unlocked,
        "unseen_achievement": unseen_achievement,
        "pending_result": pending_result,
        "pending_class": pending_class,
        "pending_slot": pending_slot,
        "pending_is_coin": pending_is_coin,
        "last_saved_unix": Time.get_unix_time_from_system()
    }
    var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
    if f:
        f.store_string(JSON.stringify(data))

func _load_game() -> void:
    if not FileAccess.file_exists(SAVE_PATH):
        return
    var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if not f:
        return
    var parsed = JSON.parse_string(f.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY:
        return

    gold = float(parsed.get("gold", 1000.0))
    selected_class = clampi(int(parsed.get("selected_class", 0)), 0, CLASSES.size() - 1)
    selected_slot = clampi(int(parsed.get("selected_slot", 3)), 0, SLOTS.size() - 1)
    normal_progress = clampi(int(parsed.get("normal_progress", parsed.get("normal_enhance_progress", 0))), 0, 100)
    has_lucky_coin = bool(parsed.get("has_lucky_coin", false))
    total_normal_attempts = int(parsed.get("total_normal_attempts", 0))
    total_destroys = int(parsed.get("total_destroys", 0))
    unlocked = parsed.get("unlocked", {}) if typeof(parsed.get("unlocked", {})) == TYPE_DICTIONARY else {}
    unseen_achievement = bool(parsed.get("unseen_achievement", false))
    pending_result = str(parsed.get("pending_result", ""))
    pending_class = int(parsed.get("pending_class", selected_class))
    pending_slot = int(parsed.get("pending_slot", selected_slot))
    pending_is_coin = bool(parsed.get("pending_is_coin", false))

    var loaded_levels = parsed.get("levels", null)
    if typeof(loaded_levels) == TYPE_DICTIONARY:
        for cname in CLASSES:
            if loaded_levels.has(cname) and typeof(loaded_levels[cname]) == TYPE_ARRAY:
                for i in range(min(SLOTS.size(), loaded_levels[cname].size())):
                    levels[cname][i] = clampi(int(loaded_levels[cname][i]), 0, MAX_LEVEL)
    else:
        _migrate_v03_equipment(parsed)

    if has_lucky_coin:
        normal_progress = 100

    _check_achievements()
    var last_saved := float(parsed.get("last_saved_unix", Time.get_unix_time_from_system()))
    var offline_seconds: float = clampf(Time.get_unix_time_from_system() - last_saved, 0.0, MAX_OFFLINE_SECONDS)
    if offline_seconds > 2.0:
        last_offline_gain = _total_gps() * offline_seconds
        gold += last_offline_gain

func _migrate_v03_equipment(parsed: Dictionary) -> void:
    var old_equipped = parsed.get("equipped", {})
    if typeof(old_equipped) != TYPE_DICTIONARY:
        return
    var old_slots := ["머리", "상의", "하의", "무기", "보조장비", "신발", "장신구"]
    for cname in CLASSES:
        if not old_equipped.has(cname) or typeof(old_equipped[cname]) != TYPE_DICTIONARY:
            continue
        var cdata = old_equipped[cname]
        for i in range(SLOTS.size()):
            var key: String = old_slots[i]
            if cdata.has(key) and cdata[key] != null and typeof(cdata[key]) == TYPE_DICTIONARY:
                levels[cname][i] = clampi(int(cdata[key].get("level", 0)), 0, MAX_LEVEL)

func _fmt(value) -> String:
    var n := int(round(float(value)))
    var negative := n < 0
    n = abs(n)
    var s := str(n)
    var out := ""
    while s.length() > 3:
        out = "," + s.substr(s.length() - 3, 3) + out
        s = s.substr(0, s.length() - 3)
    out = s + out
    return "-" + out if negative else out

func _level_color(lv: int) -> Color:
    if lv >= 20:
        return Color("ffcf3e")
    if lv >= 15:
        return Color("ff6b3c")
    if lv >= 10:
        return Color("d48cff")
    if lv >= 5:
        return Color("7fdcff")
    return Color.WHITE

func _place(node: Control, x: float, y: float, w: float, h: float) -> void:
    node.position = Vector2(x, y)
    node.size = Vector2(w, h)

func _label(text_value: String, font_size: int, color: Color, align: HorizontalAlignment) -> Label:
    var l := Label.new()
    l.text = text_value
    l.add_theme_font_size_override("font_size", font_size)
    l.add_theme_color_override("font_color", color)
    l.horizontal_alignment = align
    l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    l.mouse_filter = Control.MOUSE_FILTER_IGNORE
    return l

func _panel(rect: Rect2, bg: Color, border: Color, width: int) -> Panel:
    var p := Panel.new()
    _place(p, rect.position.x, rect.position.y, rect.size.x, rect.size.y)
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_width_left = width
    style.border_width_top = width
    style.border_width_right = width
    style.border_width_bottom = width
    style.border_color = border
    style.corner_radius_top_left = 8
    style.corner_radius_top_right = 8
    style.corner_radius_bottom_left = 8
    style.corner_radius_bottom_right = 8
    p.add_theme_stylebox_override("panel", style)
    return p

func _button_style(bg: Color, border: Color, border_width: int = 3) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = bg
    s.border_width_left = border_width
    s.border_width_top = border_width
    s.border_width_right = border_width
    s.border_width_bottom = border_width
    s.border_color = border
    s.corner_radius_top_left = 8
    s.corner_radius_top_right = 8
    s.corner_radius_bottom_left = 8
    s.corner_radius_bottom_right = 8
    return s

func _style_slot_button(b: Button, selected: bool) -> void:
    var border := Color("ffae37") if selected else Color("6b4933")
    b.add_theme_stylebox_override("normal", _button_style(Color(0.03,0.022,0.019,0.95), border, 4 if selected else 2))
    b.add_theme_stylebox_override("hover", _button_style(Color(0.08,0.045,0.025,0.98), Color("ffc259"), 4))
    b.add_theme_stylebox_override("pressed", _button_style(Color(0.12,0.055,0.020,0.98), Color("ffe08a"), 5))
    b.add_theme_stylebox_override("disabled", _button_style(Color(0.025,0.020,0.018,0.78), Color("4c4038"), 2))

func _style_enhance_button(b: Button) -> void:
    b.add_theme_stylebox_override("normal", _button_style(Color("7d210f"), Color("ff9f24"), 5))
    b.add_theme_stylebox_override("hover", _button_style(Color("9e2c10"), Color("ffc34c"), 6))
    b.add_theme_stylebox_override("pressed", _button_style(Color("5f160c"), Color("fff09c"), 6))
    b.add_theme_stylebox_override("disabled", _button_style(Color("31251f"), Color("5a4b42"), 4))

func _style_coin_button(active: bool) -> void:
    var normal_bg := Color("56390d") if active else Color("202022")
    var normal_border := Color("ffc93e") if active else Color("68686d")
    coin_button.add_theme_stylebox_override("normal", _button_style(normal_bg, normal_border, 5))
    coin_button.add_theme_stylebox_override("hover", _button_style(Color("6c480f") if active else Color("242426"), Color("ffe16e") if active else Color("77777d"), 5))
    coin_button.add_theme_stylebox_override("pressed", _button_style(Color("3e290a") if active else Color("1c1c1e"), Color("fff1a1") if active else Color("696970"), 6))
    coin_button.add_theme_stylebox_override("disabled", _button_style(Color("1e1e20"), Color("5c5c61"), 4))

func _style_nav(b: Button, selected: bool) -> void:
    var border := Color("ffab32") if selected else Color("6f4a30")
    b.add_theme_stylebox_override("normal", _button_style(Color(0.035,0.025,0.020,0.97), border, 4))
    b.add_theme_stylebox_override("hover", _button_style(Color(0.075,0.043,0.022,0.98), Color("ffc65b"), 4))
    b.add_theme_stylebox_override("pressed", _button_style(Color(0.10,0.05,0.02,0.98), Color("ffe48a"), 5))

func _style_small_button(b: Button, primary: bool) -> void:
    var bg := Color("7a270f") if primary else Color("25211f")
    var border := Color("ffc04b") if primary else Color("746157")
    b.add_theme_stylebox_override("normal", _button_style(bg, border, 4))
    b.add_theme_stylebox_override("hover", _button_style(bg.lightened(0.08), border.lightened(0.08), 4))
    b.add_theme_stylebox_override("pressed", _button_style(bg.darkened(0.10), border.lightened(0.15), 5))

func _style_progress(bar: ProgressBar) -> void:
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.02,0.018,0.017,0.95)
    bg.border_width_left = 2
    bg.border_width_top = 2
    bg.border_width_right = 2
    bg.border_width_bottom = 2
    bg.border_color = Color("6d4a30")
    bg.corner_radius_top_left = 7
    bg.corner_radius_top_right = 7
    bg.corner_radius_bottom_left = 7
    bg.corner_radius_bottom_right = 7
    var fill := StyleBoxFlat.new()
    fill.bg_color = Color("ffae2f")
    fill.corner_radius_top_left = 6
    fill.corner_radius_top_right = 6
    fill.corner_radius_bottom_left = 6
    fill.corner_radius_bottom_right = 6
    bar.add_theme_stylebox_override("background", bg)
    bar.add_theme_stylebox_override("fill", fill)
