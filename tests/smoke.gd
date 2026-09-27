extends SceneTree

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed := load("res://Main.tscn") as PackedScene
    if packed == null:
        _fail("Main.tscn load failed")
        quit(1)
        return

    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame

    game.gold = 1000000.0
    game.selected_class = 0
    game.selected_slot = 3
    game._refresh_all()

    var before_level: int = game._selected_level()
    print("SMOKE: before enhance busy=", game.busy, " level=", before_level)
    game.enhance_button.emit_signal("pressed")
    await process_frame
    print("SMOKE: after press busy=", game.busy, " sequence=", game.sequence_kind, " progress=", game.progress_bar.value)

    if not game.busy:
        _fail("Enhancement did not enter busy state")
    if game.sequence_kind != "normal":
        _fail("Enhancement sequence did not start")

    await create_timer(1.0).timeout
    print("SMOKE: t=1 progress=", game.progress_bar.value, " busy=", game.busy)
    if game.progress_bar.value <= 1.0:
        _fail("Enhancement gauge did not advance")

    await create_timer(3.5).timeout
    print("SMOKE: t=4.5 result_hold=", game.result_hold, " pending=", game.pending_result, " busy=", game.busy)
    if game.pending_result != "":
        _fail("Pending enhancement result did not resolve after 4 seconds")

    await create_timer(2.0).timeout
    print("SMOKE: t=6.5 busy=", game.busy, " sequence=", game.sequence_kind, " result_hold=", game.result_hold)
    if game.busy:
        _fail("Enhancement remained busy after result display")
    if game.sequence_kind != "":
        _fail("Enhancement sequence did not clear")

    game.has_lucky_coin = true
    game.normal_progress = 100
    game._refresh_all()
    game.coin_button.emit_signal("pressed")
    await process_frame
    if not game.modal_overlay.visible:
        _fail("Lucky coin modal did not open")
    game._confirm_coin_use()
    await process_frame
    if game.sequence_kind != "coin":
        _fail("Lucky coin sequence did not start")
    await create_timer(4.8).timeout
    if game.busy:
        _fail("Lucky coin sequence remained busy")

    if failures.is_empty():
        print("SMOKE PASS: enhancement and lucky coin state machines complete.")
        quit(0)
    else:
        for f in failures:
            push_error("SMOKE FAIL: " + f)
        quit(1)

func _fail(message: String) -> void:
    failures.append(message)
