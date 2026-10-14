extends SceneTree
## Actual GPU comparison with pinned renderers injected by -ReferenceVisuals.
## Only render modules from Git are loaded, never the legacy main/editor/profile.
var checks := 0
var failures: Array[String] = []

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures.append(label)

func _initialize() -> void:
	_run.call_deferred()

func viewport_for(reference: bool, profile: String, extent: Vector2i) -> Dictionary:
	seed(12345)
	var vp := SubViewport.new()
	vp.size = extent
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var bg = load("res://tests/reference_visuals/ambient.gd").new() if reference else Ambient.new()
	bg.size = Vector2(extent)
	vp.add_child(bg)
	bg.set_process(false)
	bg._layer.visible = false
	var shader := Shader.new()
	shader.code = Ambient.POOLS_SHADER.replace("TIME", "0.0")
	bg._classic_mat.shader = shader
	var board = load("res://tests/reference_visuals/board_view.gd" if reference else "res://scripts/board_view.gd").new()
	board.size = Vector2(extent) - Vector2(24,24)
	board.position = Vector2(12,12)
	board.logic = BoardLogic.new()
	board.number_font = UiKit.NUMBER_FONT
	board.feedback_font = load("res://ui/fonts/bold.tres")
	board.skin = "bright" if profile == "classic_run" else "classic"
	board.visual_profile = profile
	board.classic_feedback = true
	vp.add_child(board)
	board.set_process(false)
	load("res://tests/test_special_visuals.gd").new().fixture(board)
	board._glints.clear()
	return {"viewport":vp,"board":board,"ambient":bg}

func surface(sample: Dictionary, index: int) -> void:
	var fabrics := [Color(.05,.13,.14),Color("#563367"),Color("#612c3b"),Color("#273f79"),Color("#096080"),Color("#765329")]
	var fabric: Color = fabrics[index]
	var light := {"pool_a":Color(.18,.71,.66),"pool_b":Color(.48,.31,.84),"pool_c":Color(.82,.67,.33),"tint_top":Color(0,0,0,0),"tint_bottom":Color(0,0,0,0)}
	var color := Color(fabric,.55)
	if index > 0:
		light.pool_a = fabric.lightened(.15)
		light.pool_b = fabric.lightened(.08)
		light.pool_c = fabric.lightened(.22)
		var luminance := fabric.r*.2126+fabric.g*.7152+fabric.b*.0722
		var base := .05*.2126+.13*.7152+.14*.0722
		color = Color(fabric.r*base/luminance,fabric.g*base/luminance,fabric.b*base/luminance,.55)
	sample.ambient.fade_palette(Color("#3d63e0"),Color("#1b2c8c"),0,true,{"fabric":fabric,"strength":0.0 if index == 0 else 1.0,"lights":light})
	sample.board.set_run_surface(color)

func compare(pair: Array, label: String) -> void:
	for sample in pair:
		sample.board.queue_redraw()
		sample.board._fx.queue_redraw()
	for i in 3:
		await process_frame
	await RenderingServer.frame_post_draw
	var actual: Image = pair[0].viewport.get_texture().get_image()
	var reference: Image = pair[1].viewport.get_texture().get_image()
	check(actual.get_data() == reference.get_data(), "pixel equality " + label)
	var output := OS.get_environment("VISUAL_CAPTURE_DIR")
	check(actual.save_png(output.path_join(label+"_integration.png")) == OK, "save integration " + label)
	check(reference.save_png(output.path_join(label+"_refinement.png")) == OK, "save reference " + label)

func effects(b) -> void:
	seed(8181)
	b.clear_fx()
	var positions: Array[Vector2i] = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0)]
	var kinds: Array[int] = [0,1,2]
	b.play_knock(Vector2i(2,2),positions,kinds,28,4,true)
	b.play_bonus_feedback(Vector2i(2,2),{"color_streak_points":6,"color_streak_started":true,"double_hit_points":2},1,2,"COLOR CHAIN!","CHAIN 2","DOUBLE HIT!","TOTAL +28")
	b.play_wave(Vector2i(2,2),3,true)
	b.play_burst(Vector2i(2,2),90)
	b.play_confetti(90)
	b.flash(Color.WHITE,.4)
	b.shake(.3)
	b.play_thaw(positions)
	b.play_blast(Vector2i(4,2))
	b.play_clear_wave()
	b.glow()
	b._process(.1)

func _run() -> void:
	await process_frame
	root.get_node("Save").sound = false
	root.get_node("Save").music = false
	root.get_node("Sfx").update_music()
	if DisplayServer.get_name() == "headless":
		push_error("FAIL reference comparison requires tools/test_isolated.ps1 -Render -ReferenceVisuals")
		quit(1)
		return
	for extent in [Vector2i(600,420),Vector2i(360,520)]:
		for profile in ["classic", "classic_run"]:
			var pair := [viewport_for(false,profile,extent),viewport_for(true,profile,extent)]
			var label: String = profile+"_"+str(extent.x)
			await compare(pair,label+"_specials")
			if profile == "classic_run":
				for i in 6:
					for sample in pair:
						surface(sample,i)
					await compare(pair,label+"_palette"+str(i))
			for sample in pair:
				effects(sample.board)
			await compare(pair,label+"_effects")
			for sample in pair:
				# Bomb deal-in fontsize can round to zero in the legacy path.
				sample.board.clear_fx()
				sample.board._deal_t = .001
				sample.board._deal_delay.resize(sample.board.logic.cells.size())
				sample.board._deal_delay.fill(0)
				if profile == "classic" and sample == pair[1]:
					sample.board.number_font = null # pinned renderer lacks upstream's fs>0 guard
			if profile == "classic":
				var b = pair[0].board
				var gem_size: float = b.cell * .97 * b._deal_scale(10)
				check(gem_size > .5 and int(gem_size * .65 * .5) == 0 and b.number_font != null, "exercise upstream zero-size bomb guard " + label)
			await compare(pair,label+"_deal")
			for sample in pair:
				sample.viewport.queue_free()
			await process_frame
	print("VISUAL_REFERENCE ",JSON.stringify({"checks":checks,"failed":failures.size(),"failures":failures}))
	if not failures.is_empty():
		push_error("FAIL pinned visual comparison")
	print("VISUAL_REFERENCE_DONE")
	quit(0 if failures.is_empty() else 1)
