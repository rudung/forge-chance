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

    game.gold = 1000000.0
    var before_level: int = game._selected_level()
    print("SMOKE: before normal level=", before_level, " busy=", game.busy)
    game._on_enhance_pressed()
    print("SMOKE: pressed normal busy=", game.busy, " seq=", game.sequence_kind, " pending=", game.pending_result)

    await create_timer(5.8).timeout
    print("SMOKE: after normal busy=", game.busy, " seq=", game.sequence_kind, " hold=", game.result_hold, " pending=", game.pending_result, " level=", game._selected_level())
    if game.busy or game.sequence_kind != "" or game.pending_result != "":
        push_error("SMOKE_FAIL_NORMAL: enhancement did not return to interactive state")
        quit(11)
        return

    game.has_lucky_coin = true
    game.normal_progress = 100
    var before_coin_level: int = game._selected_level()
    game._confirm_coin_use()
    print("SMOKE: pressed coin level=", before_coin_level, " busy=", game.busy, " seq=", game.sequence_kind, " pending=", game.pending_result)
    await create_timer(4.8).timeout
    print("SMOKE: after coin busy=", game.busy, " seq=", game.sequence_kind, " hold=", game.result_hold, " pending=", game.pending_result, " level=", game._selected_level())
    if game.busy or game.sequence_kind != "" or game.pending_result != "":
        push_error("SMOKE_FAIL_COIN: lucky coin did not return to interactive state")
        quit(12)
        return

    print("SMOKE_OK")
    quit(0)
