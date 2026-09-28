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

    # v1.1.1 hotfix timing table.
    if not is_equal_approx(game._enhance_duration(0), 0.0) or not is_equal_approx(game._enhance_duration(5), 0.0):
        push_error("SMOKE_FAIL_DURATION_0_5")
        quit(20)
        return
    if not is_equal_approx(game._enhance_duration(6), 0.2) or not is_equal_approx(game._enhance_duration(10), 0.2):
        push_error("SMOKE_FAIL_DURATION_6_10")
        quit(21)
        return
    if not is_equal_approx(game._enhance_duration(11), 0.5) or not is_equal_approx(game._enhance_duration(15), 0.5):
        push_error("SMOKE_FAIL_DURATION_11_15")
        quit(22)
        return
    if not is_equal_approx(game._enhance_duration(16), 1.0) or not is_equal_approx(game._enhance_duration(20), 1.0):
        push_error("SMOKE_FAIL_DURATION_16_20")
        quit(23)
        return

    # OK button must exactly overlap enhance button.
    if game.result_ok_button.position != game.enhance_button.position or game.result_ok_button.size != game.enhance_button.size:
        push_error("SMOKE_FAIL_SAME_POSITION_OK")
        quit(24)
        return

    game.gold = 1000000.0
    game.levels[game.CLASSES[game.selected_class]][game.selected_slot] = 0
    game._refresh_all()

    # First tap: instant enhancement result.
    game._on_enhance_pressed()
    await process_frame
    if not game.busy or game.sequence_kind != "" or game.pending_result != "" or not game.result_panel.visible or not game.result_ok_button.visible:
        push_error("SMOKE_FAIL_INSTANT_RESULT")
        quit(25)
        return

    # Second tap at same control: OK.
    game.result_ok_button.emit_signal("pressed")
    await process_frame
    if game.busy or game.result_panel.visible or game.result_ok_button.visible:
        push_error("SMOKE_FAIL_OK_DISMISS")
        quit(26)
        return

    # Third tap at the same screen location should be able to start enhancement again.
    game._on_enhance_pressed()
    await process_frame
    if not game.busy or not game.result_panel.visible or not game.result_ok_button.visible:
        push_error("SMOKE_FAIL_REPEAT_SAME_SPOT_FLOW")
        quit(27)
        return

    game._dismiss_result()
    await process_frame

    # Verify a timed tier too.
    game.levels[game.CLASSES[game.selected_class]][game.selected_slot] = 6
    game._refresh_all()
    game._on_enhance_pressed()
    if not is_equal_approx(game.sequence_duration, 0.2):
        push_error("SMOKE_FAIL_02_START")
        quit(28)
        return
    await create_timer(0.35).timeout
    if not game.result_panel.visible or not game.result_ok_button.visible:
        push_error("SMOKE_FAIL_02_RESULT")
        quit(29)
        return
    game._dismiss_result()

    print("SMOKE_OK_V1_1_1")
    quit(0)
