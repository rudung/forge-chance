extends Control

var mode: String = "idle"
var phase: float = 0.0
var intensity: float = 1.0
var fx_color := Color(1.0, 0.52, 0.08, 0.95)

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_process(true)

func set_mode(value: String) -> void:
    mode = value
    phase = 0.0
    match mode:
        "charging", "success", "coin_front":
            fx_color = Color(1.0, 0.58, 0.08, 0.96)
        "stay":
            fx_color = Color(0.18, 0.58, 1.0, 0.94)
        "down":
            fx_color = Color(0.66, 0.18, 1.0, 0.94)
        "destroy", "coin_back":
            fx_color = Color(1.0, 0.07, 0.06, 0.97)
        "coin_spin":
            fx_color = Color(1.0, 0.76, 0.16, 0.97)
        _:
            fx_color = Color(1.0, 0.45, 0.06, 0.45)
    queue_redraw()

func _process(delta: float) -> void:
    phase += delta
    if mode != "idle":
        queue_redraw()

func _draw() -> void:
    if mode == "idle":
        return
    var c := size * 0.5
    var pulse := 0.5 + 0.5 * sin(phase * 5.0)

    if mode == "coin_spin":
        _draw_coin(c, pulse, true, false)
        return
    if mode == "coin_front":
        _draw_coin(c, pulse, false, true)
        return
    if mode == "coin_back":
        _draw_coin(c, pulse, false, false)
        return

    var ring_count := 5 if mode == "charging" else 3
    for i in range(ring_count):
        var r := 70.0 + float(i) * 50.0 + sin(phase * (1.8 + i * 0.15) + i) * 14.0
        var alpha := max(0.08, 0.38 - float(i) * 0.055) * intensity
        draw_arc(c, r, phase * (0.7 + i * 0.08), phase * (0.7 + i * 0.08) + TAU * 0.74, 64, Color(fx_color.r, fx_color.g, fx_color.b, alpha), 5.0 + pulse * 2.0, true)

    var particle_count := 48 if mode == "charging" else 32
    for i in range(particle_count):
        var a := phase * (0.50 + float(i % 6) * 0.055) + float(i) * 0.71
        var rr := 50.0 + float((i * 37) % 280)
        var p := c + Vector2(cos(a), sin(a)) * rr
        var s := 2.0 + float(i % 4) + pulse * 1.8
        draw_circle(p, s, Color(fx_color.r, fx_color.g, fx_color.b, 0.34 + 0.48 * pulse))

    if mode == "success":
        draw_circle(c, 135.0 + pulse * 30.0, Color(1.0, 0.74, 0.18, 0.11))
        for i in range(18):
            var a2 := float(i) / 18.0 * TAU
            draw_line(c + Vector2(cos(a2), sin(a2)) * 90.0, c + Vector2(cos(a2), sin(a2)) * (185.0 + pulse * 65.0), Color(1.0, 0.78, 0.18, 0.76), 4.0, true)
    elif mode == "stay":
        draw_circle(c, 122.0 + pulse * 18.0, Color(0.15, 0.52, 1.0, 0.10))
    elif mode == "down":
        draw_circle(c, 122.0 + pulse * 18.0, Color(0.55, 0.10, 0.85, 0.12))
        for i in range(8):
            var a3 := float(i) / 8.0 * TAU + phase * 0.15
            draw_line(c + Vector2(cos(a3), sin(a3)) * 60.0, c + Vector2(cos(a3), sin(a3)) * 150.0, Color(0.70, 0.20, 1.0, 0.72), 5.0, true)
    elif mode == "destroy":
        draw_circle(c, 150.0 + pulse * 26.0, Color(1.0, 0.03, 0.02, 0.12))
        for i in range(22):
            var a4 := float(i) / 22.0 * TAU + phase * 0.09
            var start := c + Vector2(cos(a4), sin(a4)) * 45.0
            var finish := c + Vector2(cos(a4), sin(a4)) * (180.0 + float(i % 4) * 40.0)
            draw_line(start, finish, Color(1.0, 0.08, 0.03, 0.88), 5.0, true)

func _draw_coin(c: Vector2, pulse: float, spinning: bool, front: bool) -> void:
    var sx := 1.0
    if spinning:
        sx = max(0.10, abs(cos(phase * 8.5)))
    draw_set_transform(c, 0.0, Vector2(sx, 1.0))
    var radius := 104.0 + pulse * 9.0
    var base_color := Color(1.0, 0.70, 0.08, 0.98) if (spinning or front) else Color(0.27, 0.28, 0.31, 0.98)
    var edge_color := Color(1.0, 0.93, 0.45, 1.0) if (spinning or front) else Color(0.85, 0.16, 0.12, 1.0)
    draw_circle(Vector2.ZERO, radius, base_color)
    draw_arc(Vector2.ZERO, radius - 4.0, 0.0, TAU, 64, edge_color, 9.0, true)
    draw_arc(Vector2.ZERO, radius - 18.0, 0.0, TAU, 64, Color(edge_color.r, edge_color.g, edge_color.b, 0.60), 4.0, true)
    if spinning:
        draw_circle(Vector2.ZERO, 38.0, Color(1.0, 0.92, 0.46, 0.72))
    elif front:
        for off in [Vector2(-28,-28), Vector2(28,-28), Vector2(-28,28), Vector2(28,28)]:
            draw_circle(off, 30.0, Color(1.0, 0.90, 0.32, 0.94))
        draw_circle(Vector2.ZERO, 18.0, Color(0.96, 0.55, 0.04, 1.0))
    else:
        draw_circle(Vector2(0,-10), 50.0, Color(0.10,0.10,0.11,0.96))
        draw_circle(Vector2(-19,-18), 10.0, Color(0.92,0.05,0.04,1.0))
        draw_circle(Vector2(19,-18), 10.0, Color(0.92,0.05,0.04,1.0))
        draw_rect(Rect2(-26,22,52,13), Color(0.75,0.75,0.78,0.75), true)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
