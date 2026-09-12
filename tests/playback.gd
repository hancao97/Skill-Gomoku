extends Node

var game
var failures := 0
var checks := 0
var output := ""
var impacts: Array[Dictionary] = []

func pause(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("PLAYBACK FAILED: "+message)
	else:
		print("PLAYBACK PASS: "+message)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	picture.save_png(output+"/"+name+".png")
	print("CAPTURE: ",name,"  ",picture.get_size(),"  FPS: ",Engine.get_frames_per_second())

func mouse_button(pos: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = pos
	event.global_position = pos
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	get_viewport().push_input(event,true)

func move_mouse(pos: Vector2, relative: Vector2 = Vector2.ZERO, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = pos
	event.global_position = pos
	event.relative = relative
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	get_viewport().push_input(event,true)

func click_cell(p: Vector2i) -> void:
	var pos: Vector2 = game.scenery.camera.unproject_position(game.world(p))
	mouse_button(pos,true)
	mouse_button(pos,false)
	await pause(.65)

func idle() -> void:
	var elapsed := 0.0
	while game.busy and elapsed < 15:
		await pause(.1)
		elapsed += .1
	check(not game.busy,"animation returned input control")

func wait_inscription(words:String) -> void:
	var elapsed := 0.0
	while elapsed < 7:
		if game.ui.calligraphy.visible and game.ui.calligraphy.get_children().any(func(n:Node):return n is Label and n.text==words):
			await pause(.32)
			check(true,"calligraphy appears: "+words)
			return
		await pause(.05)
		elapsed += .05
	check(false,"calligraphy appears: "+words)

func seed_board(cells: Array, color: int) -> void:
	for point in cells:
		var p := Vector2i(point[0],point[1])
		game.rules.put(p,color)
		game._make_stone(p,color)

func fixture(index: int, score: Array, turn: int) -> void:
	game.rules.reset_match()
	game.rules.round_index = index
	game.rules.wins.assign(score)
	game.rules.turn = turn
	game._start_board()
	await pause(1.6)

func run(target) -> void:
	game = target
	game.apply_settings(true,true,true)
	game.fx.child_entered_tree.connect(func(node:Node):
		if node is AudioStreamPlayer and node.stream.resource_path.contains("/stone_"):
			var stone:Node3D = game.stones.get(game.rules.last)
			impacts.append({"sample":node.stream.resource_path,"height":stone.position.y if stone else -1.0,
				"format":node.stream.format,"rate":node.stream.mix_rate})
	)
	output = ProjectSettings.globalize_path("res://verification")
	await pause(3)
	await capture("01-menu")
	print("VIEWPORT: ",get_viewport().get_visible_rect()," UI: ",game.ui.root.size)
	game.begin_match(["墨客","听雨"])
	await pause(2)
	if OS.get_cmdline_user_args().has("--preview"):
		var points := [[7,7],[8,7],[6,6],[8,6],[5,7],[7,6],[6,8],[5,8],[9,6],[7,9],[8,8],[9,8],[6,5],[5,5],[10,7],[8,9],[9,5],[4,6]]
		for i in points.size():
			var p := Vector2i(points[i][0],points[i][1])
			game.rules.put(p,1+i%2)
			game._make_stone(p,1+i%2)
		game.rules.last = Vector2i(4,6)
		game.rules.move_count = points.size()
		game._update_last()
		game._refresh()
		await pause(2)
		await capture("02-board")
		print("RENDER: ",Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)," primitives; ",Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)," calls")
		if not OS.get_cmdline_user_args().has("--hold"):
			get_tree().quit()
		return
	await _full_test()

func _full_test() -> void:
	await click_cell(Vector2i(7,7))
	check(game.rules.at(Vector2i(7,7)) == 1,"mouse placement on board")
	await click_cell(Vector2i(7,7))
	check(game.rules.move_count == 1,"occupied intersection rejected")
	await click_cell(Vector2i(7,8))
	check(game.rules.at(Vector2i(7,8)) == 2,"alternating white placement")
	check(impacts.size()==2 and impacts.all(func(i:Dictionary):return is_equal_approx(i.height,game.HEIGHT)),"real placement recordings start at board contact for both players")
	check(impacts.all(func(i:Dictionary):return i.format==AudioStreamWAV.FORMAT_16_BITS and i.rate==44100),"placement audio uses uncompressed 44.1 kHz recordings")
	check(impacts[0].sample!=impacts[1].sample,"consecutive placements use different real takes")
	await capture("02-board")
	game.ui.show_help()
	await pause(.3)
	await capture("03-help")
	game.ui.close_modal()
	# Inspect the actual effect nodes while each player's piece lands, after both color assignments.
	for index in 2:
		for player in [1,0]:
			var color: int = 1 if player == index else 2
			await fixture(index,[0,0],color)
			move_mouse(Vector2(350,850))
			await pause(.1)
			var before: int = game.fx.get_child_count()
			var pos:Vector2 = game.scenery.camera.unproject_position(game.world(Vector2i(7,7)))
			mouse_button(pos,true);mouse_button(pos,false)
			await pause(.04)
			check(game.ui.turn_label.text.begins_with(game.names[player]),"landing animation labels its actual player, color %d"%color)
			if player == 1:
				check(game.fx.get_child_count()==before,"ordinary player has no falling aura, color %d"%color)
			else:
				check(game.fx.get_children().any(func(n:Node):return n is MeshInstance3D and n.material_override is ShaderMaterial and n.material_override.shader==preload("res://shaders/soul.gdshader")),"advantaged player has falling soul, color %d"%color)
			await pause(.35)
			if player == 1:
				check(not game.fx.get_children().any(func(n:Node):return n is MeshInstance3D and n.visible),"ordinary player has no impact rings or sparks, color %d"%color)
				await capture("plain-player-color-%d"%color)
			else:
				var tint = game.fx.get_children().filter(func(n:Node):return n is MeshInstance3D and n.material_override is ShaderMaterial and n.material_override.shader==preload("res://shaders/soul.gdshader"))
				check(not tint.is_empty() and tint[0].material_override.get_shader_parameter("tint").is_equal_approx(game.fx.JADE if color==1 else game.fx.MOON),"advantaged effects follow current stone color %d"%color)
				await capture("advantaged-player-color-%d"%color)
	await fixture(0,[0,0],2)
	seed_board([[2,3],[3,3],[4,3],[5,3]],2)
	await click_cell(Vector2i(6,3))
	check(game.rules.round_winner==1 and not game.ui.calligraphy.visible and not game.fx.get_children().any(func(n:Node):return n is MeshInstance3D and n.visible),"ordinary player's victory has no spell, victory aura or calligraphy")
	await idle()
	# A complete ordinary five-in-a-row, through real viewport input.
	game.begin_match(["墨客","听雨"])
	await pause(1.6)
	var white := [Vector2i(10,9),Vector2i(11,10),Vector2i(12,9),Vector2i(10,11)]
	for i in 5:
		await click_cell(Vector2i(2+i,3))
		if game.rules.pending_skill == "bow":
			game.skip_bow()
		if i < 4:
			await click_cell(white[i])
	await idle()
	check(game.rules.round_winner == 0 and game.rules.wins == [1,0],"ordinary five scores exactly one round")
	await capture("04-round-result")
	game.next_round()
	await idle()
	check(game.rules.round_index == 1 and game.rules.current_player() == 1,"next round swaps black to player two")
	# Bow: exact T, White's reply, then pulling the side stone along its fixed axis.
	await fixture(0,[0,0],1)
	seed_board([[7,5],[7,6],[6,6]],1)
	seed_board([[8,6],[10,6]],2)
	await click_cell(Vector2i(7,7))
	check(game.rules.pending_skill == "" and game.rules.turn==2 and game.marks.get_child_count()==0,"T formation keeps White's move and shows no ready bow")
	await capture("05a-bow-waiting-white")
	var held_side: Vector2 = game.scenery.camera.unproject_position(game.world(Vector2i(6,6)))
	mouse_button(held_side,true);move_mouse(held_side-Vector2(60,0),Vector2(-60,0),true);mouse_button(held_side-Vector2(60,0),false)
	await pause(.15)
	check(game.rules.turn==2 and game.rules.round_winner==-2 and game.anchor.x<0,"attempt to pull during White turn cannot fire")
	await click_cell(Vector2i(0,0))
	check(game.rules.pending_skill == "bow" and game.rules.turn==1,"White's completed move unlocks next Black turn's bow")
	var aim: Vector2 = game.scenery.camera.unproject_position(game.world(Vector2i(6,6)))
	mouse_button(aim,true)
	var pulled: Vector2 = game.scenery.camera.unproject_position(game.world(Vector2i(6,6))-Vector3(1.0,0,0))
	move_mouse(pulled,pulled-aim,true)
	await pause(.25)
	await capture("05-bow-aim")
	mouse_button(pulled,false)
	await pause(.3)
	await capture("06-bow-flight")
	await wait_inscription("会挽雕弓如满月")
	await capture("07-bow-calligraphy")
	await idle()
	check(game.rules.round_winner == 0 and game.rules.finish_kind == "bow","bow activation directly wins")
	check(game.rules.at(Vector2i(6,6)) == 0 and game.rules.at(Vector2i(10,6)) == 1 and game.rules.at(Vector2i(9,6))==1,"projectile leaves, occupied and empty ray points turn black")
	check(game.stones.has(Vector2i(9,6)) and game.stones.has(Vector2i(14,6)) and game.stones[Vector2i(9,6)].get_meta("color")==1,"flight actually creates visible black models at empty intersections")
	# A short ray must also win: no five exists to hide a conditional-win bug.
	await fixture(0,[0,0],1)
	seed_board([[12,6],[12,7],[11,7]],1)
	await click_cell(Vector2i(12,8));await click_cell(Vector2i(0,0))
	var edge_aim:Vector2 = game.scenery.camera.unproject_position(game.world(Vector2i(11,7)))
	var edge_pull:Vector2 = game.scenery.camera.unproject_position(game.world(Vector2i(11,7))-Vector3(1,0,0))
	mouse_button(edge_aim,true);move_mouse(edge_pull,edge_pull-edge_aim,true);mouse_button(edge_pull,false)
	await idle()
	check(game.rules.round_winner==0 and game.rules.winning_line.is_empty() and game.stones.has(Vector2i(14,7)),"short bow directly wins and fills its two empty points without five")
	# Moon: the same player now holds white; four stones physically orbit.
	await fixture(1,[1,0],2)
	seed_board([[7,7],[8,7],[8,8]],2)
	seed_board([[6,7],[9,8]],1)
	await click_cell(Vector2i(7,8))
	await pause(.65)
	await capture("08-moon-orbit")
	await wait_inscription("遥遥领先")
	await capture("09-moon-calligraphy")
	await idle()
	check(game.rules.round_winner == 0 and game.rules.finish_kind == "moon" and game.rules.winning_line.is_empty(),"white ring directly wins without five after the same player swaps color")
	check(game.rules.at(Vector2i(9,8)) == 2,"moon converts neighboring black stone")
	# Cosmos: stationary holding never charges; actual reversals unlock it.
	await fixture(2,[2,0],1)
	var charge_pos: Vector2 = game.ui.charge.global_position+Vector2(143,54)
	mouse_button(charge_pos,true)
	await pause(1.8)
	check(game.ui.charge.progress == 0 and not game.ui.charge.ready_to_place,"holding without rubbing cannot charge")
	var prior := charge_pos
	for i in 32:
		var current := charge_pos+Vector2(-48 if i%2 == 0 else 48,0)
		move_mouse(current,current-prior,true)
		prior = current
		await pause(.032)
	check(game.ui.charge.ready_to_place,"distance plus repeated reversals creates rainbow stone")
	await capture("10-rainbow-charged")
	var landing: Vector2 = game.scenery.camera.unproject_position(game.world(Vector2i(7,7)))
	move_mouse(landing,landing-prior,true)
	mouse_button(landing,false)
	await pause(.85)
	await capture("11-cosmos-wave")
	await wait_inscription("天地大同")
	await capture("12-cosmos-calligraphy")
	await idle()
	check(game.rules.board.count(1) == 225,"cosmos makes all 225 intersections black")
	check(game.rules.wins == [3,0] and game.rules.match_winner == 0,"third victory ends best-of-five")
	await capture("13-match-result")
	var count: int = game.rules.move_count
	await click_cell(Vector2i(0,0))
	check(game.rules.move_count == count,"finished match blocks further board input")
	print("PLAYBACK: ",checks," checks, ",failures," failures")
	if not OS.get_cmdline_user_args().has("--hold"):
		get_tree().quit(0 if failures == 0 else 1)
