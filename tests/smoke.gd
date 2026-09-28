extends SceneTree

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://Main.tscn") as PackedScene
    if packed == null:
        push_error("SMOKE: Main.tscn failed to load")
        quit(10)
        return

    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await create_timer(0.20).timeout

    # v1.1.2 timing table.
    if not is_equal_approx(game._enhance_duration(0), 0.0) or not is_equal_approx(game._enhance_duration(10), 0.0):
        push_error("SMOKE_FAIL_DURATION_0_10")
        quit(20)
        return
    if not is_equal_approx(game._enhance_duration(11), 0.3) or not is_equal_approx(game._enhance_duration(14), 0.3):
        push_error("SMOKE_FAIL_DURATION_11_14")
        quit(21)
        return
    if not is_equal_approx(game._enhance_duration(15), 0.5) or not is_equal_approx(game._enhance_duration(20), 0.5):
        push_error("SMOKE_FAIL_DURATION_15_20")
        quit(22)
        return

    # v1.1.2 destruction rebalance: old / 2 - 1%p, remainder goes to stay.
    var expected_destroy := [0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,0.0,1.5,2.0,2.5,3.0,3.5,4.0,4.5,5.0,5.5,6.0,6.5]
    for lv in range(20):
        var row = game.ENHANCE_TABLE[lv]
        var total := float(row[0]) + float(row[1]) + float(row[2]) + float(row[3])
        if not is_equal_approx(total, 100.0):
            push_error("SMOKE_FAIL_PROB_SUM level=%d total=%s" % [lv, total])
            quit(23)
            return
        if not is_equal_approx(float(row[3]), expected_destroy[lv]):
            push_error("SMOKE_FAIL_DESTROY level=%d got=%s expected=%s" % [lv, row[3], expected_destroy[lv]])
            quit(24)
            return

    if not is_equal_approx(float(game.ENHANCE_TABLE[9][1]), 29.5):
        push_error("SMOKE_FAIL_STAY_9")
        quit(25)
        return
    if not is_equal_approx(float(game.ENHANCE_TABLE[19][1]), 48.5):
        push_error("SMOKE_FAIL_STAY_19")
        quit(26)
        return

    # OK button must exactly overlap enhance button.
    if game.result_ok_button.position != game.enhance_button.position or game.result_ok_button.size != game.enhance_button.size:
        push_error("SMOKE_FAIL_SAME_POSITION_OK")
        quit(27)
        return

    game.gold = 1000000.0
    game.levels[game.CLASSES[game.selected_class]][game.selected_slot] = 0
    game._refresh_all()

    # +0 is instant.
    game._on_enhance_pressed()
    await process_frame
    if not game.busy or game.sequence_kind != "" or game.pending_result != "" or not game.result_panel.visible or not game.result_ok_button.visible:
        push_error("SMOKE_FAIL_INSTANT_RESULT")
        quit(28)
        return

    # Same-position OK flow.
    game.result_ok_button.emit_signal("pressed")
    await process_frame
    if game.busy or game.result_panel.visible or game.result_ok_button.visible:
        push_error("SMOKE_FAIL_OK_DISMISS")
        quit(29)
        return

    # Timed 11 tier = 0.3 sec.
    game.levels[game.CLASSES[game.selected_class]][game.selected_slot] = 11
    game._refresh_all()
    game._on_enhance_pressed()
    if not is_equal_approx(game.sequence_duration, 0.3):
        push_error("SMOKE_FAIL_03_START")
        quit(30)
        return
    await create_timer(0.45).timeout
    if not game.result_panel.visible or not game.result_ok_button.visible:
        push_error("SMOKE_FAIL_03_RESULT")
        quit(31)
        return
    game._dismiss_result()
    await process_frame

    # Timed 15 tier = 0.5 sec.
    game.levels[game.CLASSES[game.selected_class]][game.selected_slot] = 15
    game._refresh_all()
    game._on_enhance_pressed()
    if not is_equal_approx(game.sequence_duration, 0.5):
        push_error("SMOKE_FAIL_05_START")
        quit(32)
        return
    await create_timer(0.65).timeout
    if not game.result_panel.visible or not game.result_ok_button.visible:
        push_error("SMOKE_FAIL_05_RESULT")
        quit(33)
        return
    game._dismiss_result()

    print("SMOKE_OK_V1_1_2")
    quit(0)
