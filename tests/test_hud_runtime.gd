extends SceneTree
## Real scene signals/input; only platform/date/safe-area are fixtures. Isolated runner only.
var checks := 0
var failures: Array[String] = []
const A := Vector2i(3,3)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _initialize() -> void:
	_run.call_deferred()

func settle(count := 8) -> void:
	for i in count: await process_frame

func touch(vp: SubViewport, id: int, pressed: bool, pos: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.pressed = pressed
	event.position = pos
	vp.push_input(event,true)

func mouse(vp: SubViewport, pressed: bool, pos: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.device = InputEvent.DEVICE_ID_EMULATION
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	event.position = pos
	vp.push_input(event,true)

func point(main) -> Vector2:
	return main.board.get_global_transform_with_canvas()*main.board.slot_center(A)

func hit(main, vp: SubViewport, source, native: bool, n := 2) -> void:
	var colors: Array[int] = []
	for i in n: colors.append(0)
	source.fixture(main,colors)
	main.board._deal_t = 99
	if native:
		var before: int = main.strikes_done
		touch(vp,1,true,point(main))
		mouse(vp,true,point(main))
		check(main.strikes_done == before and main.board._hover == A,"scene touch aims without hitting")
		touch(vp,1,false,point(main))
		mouse(vp,false,point(main))
		check(main.strikes_done == before+1,"scene touch release emits exactly one real strike")
	else: main._on_slot(A)

func clocks(main) -> Array:
	return [main.play_time,main.time_left,main.keeper._last_hit,main.keeper._special_deadline,
		main.keeper.combo,main.keeper.precise_streak,main.keeper.color_streak_hits,main.score]

func _run() -> void:
	await process_frame
	root.get_node("Save").sound = false
	root.get_node("Save").music = false
	root.get_node("Sfx").update_music()
	Input.emulate_mouse_from_touch = false
	var source = load("res://tests/test_combo_runtime.gd").new()
	for native in [false,true]:
		for variant in ["classic","bright","daily","challenge"]:
			var vp := SubViewport.new()
			vp.handle_input_locally = true
			vp.size = Vector2i(853,480) if native and variant == "classic" else (Vector2i(480,850) if native else Vector2i(1280,720))
			root.add_child(vp)
			var main = load("res://scenes/main.tscn").instantiate()
			main.set_script(load("res://tests/hud_platform_fixture.gd"))
			main.simulate_android = native
			vp.add_child(main)
			main.set_process(false)
			var ch := {"mode":"bright","seed":9281,"dims":Vector2i(12,17),"score":100} if variant == "challenge" else {}
			await main.start_game("classic" if variant == "classic" else "bright",variant == "daily",ch)
			await settle()
			main.board.set_process(false)
			var context: String = str(native)+" "+variant
			await hit(main,vp,source,native,3)
			await hit(main,vp,source,native)
			check(main.keeper.combo == 2 and main.keeper.precise_streak == 1,context+" keeper ordinary/special independent")
			check(is_equal_approx(main.keeper.special_window_left(main.play_time),5.4),context+" intermediate pair extends special window")
			check(main.keeper.color_streak_hits == 2 and main.hud.chain_count.text == "2",context+" actual awarded chain reaches HUD")
			var rewards: Dictionary = source.receipt(main)
			check(rewards.double_hit_points > 0 and rewards.color_streak_points > 0,context+" existing named rewards preserved")
			check(main.score == main.keeper.score,context+" scene score is keeper total")
			var before := clocks(main)
			for i in 4: main._update_hud()
			check(clocks(main) == before,context+" HUD never awards or advances clocks")
			main._process(1.75)
			check(is_equal_approx(main.hud.combo_bar.value,50),context+" real controller ordinary window 3.5s")
			check(is_equal_approx(main.keeper.special_window_left(main.play_time),3.65),context+" special window remains separate")
			main.hud.btn_pause.pressed.emit()
			check(main.state == main.State.PAUSED and main.pause.visible and not main.board.interactive,context+" pause button connected")
			before = clocks(main)
			main._process(20)
			check(clocks(main) == before,context+" pause freezes both windows and clocks")
			main.pause.resume_pressed.emit()
			check(main.state == main.State.PLAYING and main.board.interactive,context+" resume route retained")
			main.hud.btn_settings.pressed.emit()
			check(main.settings.visible and main.state == main.State.PAUSED,context+" settings button pauses game")
			main._process(20)
			main._close_settings()
			check(main.state == main.State.PLAYING and clocks(main) == before,context+" settings returns with preserved windows")
			if main.hud.btn_hint:
				var hints: int = main.hints
				main.hud.btn_hint.pressed.emit()
				check(main.hints == hints-1 and main.board._hint.x >= 0,context+" hint button retains free hint function")
			if native:
				var pair: Array[int] = [0,0]
				source.fixture(main,pair)
				var strikes: int = main.strikes_done
				touch(vp,3,true,point(main))
				var hud_point: Vector2 = main.hud.btn_pause.get_global_rect().get_center()
				touch(vp,4,true,hud_point)
				check(main.board._android_blocked and main.board._hover == Vector2i(-1,-1),context+" second finger over real HUD cancels aim")
				touch(vp,3,false,point(main))
				touch(vp,4,false,hud_point)
				check(main.strikes_done == strikes,context+" HUD multitouch cannot award a false strike")
				# Godot forwards emulated mouse events to buttons; the board ignores them.
				await settle(1) # Let queued GUI focus/layout work settle after closing panels.
				var motion := InputEventMouseMotion.new()
				motion.position = hud_point
				motion.device = InputEvent.DEVICE_ID_EMULATION
				vp.push_input(motion,true)
				mouse(vp,true,hud_point)
				mouse(vp,false,hud_point)
				check(main.state == main.State.PAUSED,context+" emulated mouse still operates real HUD button")
				main._resume_play()
			var generation: int = main._game_generation
			main.hud.btn_restart.pressed.emit()
			await settle(16)
			check(main._game_generation == generation+1 and main.state == main.State.PLAYING,context+" restart signal starts one new game")
			check(main.keeper.combo == 0 and main.keeper.color_streak_hits == 0,context+" restart resets real keeper")
			check(main.challenge == ch and main.daily == (variant == "daily"),context+" restart keeps challenge/Daily selection")
			var cells: PackedInt32Array = main.logic.cells.duplicate()
			var shape := Vector2i(main.logic.cols,main.logic.rows)
			main.test_insets = Rect2(8,12,10,16)
			vp.size += Vector2i(40,0)
			main._on_viewport_resized()
			await settle()
			check(main.safe == main.test_insets,context+" safe area resize consumed")
			if variant != "classic":
				check(main.logic.cells == cells and Vector2i(main.logic.cols,main.logic.rows) == shape,context+" resize keeps generated Run geometry and cells")
				check(main.hud.run_badge.visible,context+" shared Run/Daily/Challenge badge after resize")
			main.go_menu()
			check(not main.game_layer.visible and not main.board.interactive,context+" menu route hides HUD and disables gestures")
			main.queue_free()
			await settle(2)
			vp.queue_free()
			await settle(2)
	print("HUD_RUNTIME ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	if not failures.is_empty(): push_error("FAIL HUD runtime")
	print("HUD_RUNTIME_DONE")
	quit(0 if failures.is_empty() else 1)
