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
    await create_timer(0.25).timeout

    # v1.1 tiered enhancement durations.
    if not is_equal_approx(game._enhance_duration(0), 0.5) or not is_equal_approx(game._enhance_duration(5), 0.5):
        push_error("SMOKE_FAIL_DURATION_0_5")
        quit(20)
        return
    if not is_equal_approx(game._enhance_duration(6), 1.5) or not is_equal_approx(game._enhance_duration(10), 1.5):
        push_error("SMOKE_FAIL_DURATION_6_10")
        quit(21)
        return
    if not is_equal_approx(game._enhance_duration(11), 2.5) or not is_equal_approx(game._enhance_duration(15), 2.5):
        push_error("SMOKE_FAIL_DURATION_11_15")
        quit(22)
        return
    if not is_equal_approx(game._enhance_duration(16), 3.5) or not is_equal_approx(game._enhance_duration(20), 3.5):
        push_error("SMOKE_FAIL_DURATION_16_20")
        quit(23)
        return

    game.gold = 1000000.0
    var before_level: int = game._selected_level()
    print("SMOKE: before normal level=", before_level, " busy=", game.busy)
    game._on_enhance_pressed()
    print("SMOKE: pressed normal busy=", game.busy, " seq=", game.sequence_kind, " duration=", game.sequence_duration, " pending=", game.pending_result)

    await create_timer(0.85).timeout
    print("SMOKE: result shown busy=", game.busy, " seq=", game.sequence_kind, " pending=", game.pending_result, " visible=", game.result_panel.visible)
    if not game.busy or game.sequence_kind != "" or game.pending_result != "" or not game.result_panel.visible:
        push_error("SMOKE_FAIL_NORMAL_RESULT: result must persist until OK")
        quit(24)
        return

    await create_timer(1.0).timeout
    if not game.result_panel.visible or not game.busy:
        push_error("SMOKE_FAIL_RESULT_PERSISTENCE")
        quit(25)
        return

    game._dismiss_result()
    await process_frame
    if game.busy or game.result_panel.visible:
        push_error("SMOKE_FAIL_OK_DISMISS")
        quit(26)
        return

    game.has_lucky_coin = true
    game.normal_progress = 100
    game._confirm_coin_use()
    print("SMOKE: pressed coin busy=", game.busy, " seq=", game.sequence_kind, " pending=", game.pending_result)
    await create_timer(2.8).timeout
    if not game.busy or game.sequence_kind != "" or game.pending_result != "" or not game.result_panel.visible:
        push_error("SMOKE_FAIL_COIN_RESULT")
        quit(27)
        return

    game._dismiss_result()
    await process_frame
    if game.busy or game.result_panel.visible:
        push_error("SMOKE_FAIL_COIN_OK")
        quit(28)
        return

    print("SMOKE_OK_V1_1")
    quit(0)
