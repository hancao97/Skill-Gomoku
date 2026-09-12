extends "res://tests/playback_v2.gd"

var skill_voice_paths:Array[String]=[]
var overlap_frames:=0

func _process(_delta:float) -> void:
	if game and game.in_cinema:
		if game.fx.get_children().any(func(n:Node):return n is AudioStreamPlayer and n.has_meta("placement_thunder") and n.playing):overlap_frames+=1

func token_pos() -> Vector2:
	return game.scenery.camera.unproject_position(game.HAND_TOKEN_POSITION)

func tap_token() -> void:
	button(token_pos(),true);button(token_pos(),false)
	await pause(.05)

func run(target) -> void:
	game=target
	game.apply_settings(true,true,true)
	output=ProjectSettings.globalize_path("res://verification/v2.7")
	game.fx.child_entered_tree.connect(func(node:Node):
		if node is AudioStreamPlayer:skill_voice_paths.append(node.stream.resource_path)
	)
	if OS.get_cmdline_user_args().has("--hand-showcase"):
		await fixture(1,2)
		seed_board([[5,5],[6,6],[8,7],[10,5],[2,3],[4,11],[10,10]],1)
		seed_board([[6,5],[7,6],[9,7],[3,4]],2)
		await pause(.3)
		await tap_token()
		await idle()
		await pause(.4)
		await game._shutdown_audio()
		get_tree().quit()
		return
	await fixture(0,1)
	check(not game.hand_token.visible,"First round has no spare white stone")
	await fixture(1,1)
	check(game.hand_token.visible and not game.hand_token.has_meta("aura"),"Second round shows a plain white stone beside the black bowl")
	await tap_token()
	check(game.rules.active() and game.rules.move_count==0,"Opponent black cannot use the token")
	await click(Vector2i(7,7))
	check(game.rules.current_player()==0 and game.rules.turn==2,"Advantage White gets the turn after Black's reply")
	await capture("hand-01-token")
	button(token_pos(),true);motion(token_pos()+Vector2(35,0));button(token_pos()+Vector2(35,0),false)
	check(game.rules.active() and not game.hand_token_pressed,"Dragging away cancels the token click")
	button(token_pos(),true);game._pointer_left();button(token_pos(),false)
	check(game.rules.active() and not game.hand_token_pressed,"Window exit cancels the token click")
	button(token_pos(),true);game.ui.show_pause();button(token_pos(),false)
	check(game.rules.active() and not game.hand_token_pressed,"Pause cancels the token click")
	game.ui.close_modal()
	seed_board([[5,5],[6,6],[8,7],[10,5],[2,3],[4,11],[10,10]],1)
	seed_board([[6,5],[7,6],[9,7],[3,4]],2)
	var before:Array=game.rules.board.duplicate()
	await tap_token()
	check(game.busy and game.in_cinema and is_instance_valid(game.hand_effect),"Real mouse click starts the hand cinematic")
	check(not game.hand_token.visible and not game.hover_preview.visible,"Consumed token and hover disappear during the skill")
	await pause(.8);await capture("hand-02-gather")
	await pause(.95);await capture("hand-03-pose")
	check(game.hand_effect.phase=="pose" and game.hand_effect.get_meta("stone_color")==2,"White stone mosaic holds the recognizable pointing pose")
	check(game.hand_effect.pieces.size()>game.rules.divine_hand_cells().size(),"Palm has three-dimensional stone layers")
	check(game.hand_effect.pearl.albedo_color.r>.9 and game.hand_effect.pearl.albedo_color.b>.9,"Hand body remains silver white")
	await pause(1.36);await capture("hand-04-contact")
	await inscription("divine_hand");await capture("hand-05-calligraphy")
	var area:Array[Vector2i]=game.rules.divine_hand_cells()
	check(area.all(func(p:Vector2i):return game.rules.at(p)==2 and game.stones.has(p) and game.stones[p].get_meta("color")==2),"Visible white hand footprint matches all logical cells")
	check(game.rules.at(Vector2i(2,3))==before[3*15+2] and game.rules.at(Vector2i(3,4))==before[4*15+3],"Outside stones keep their original colors")
	check(game.rules.round_winner==0 and game.rules.wins==[1,0] and game.rules.finish_kind=="divine_hand","Hand wins this round exactly once")
	for cue in ["hand_gather","hand_point","hand_impact"]:
		check(skill_voice_paths.any(func(path:String):return path.ends_with(cue+".wav")),"Distinct hand audio stage "+cue)
	await idle()
	check(not is_instance_valid(game.hand_effect) and not game.in_cinema and game.ui.modal_kind=="result","Hand frees models and returns control to the result")
	await fixture(2,1)
	check(not game.hand_token.visible,"Token disappears after round two")
	# Feature switches retain independent behavior.
	await fixture(1,2)
	game.apply_settings(true,true,true,true,false)
	await pause(.04)
	check(not game.hand_token.visible,"Disabling skills hides the token")
	game.apply_settings(true,true,true,false,true)
	await pause(.04)
	check(game.hand_token.visible,"Disabling only VFX preserves the token")
	await tap_token();await idle()
	check(game.rules.finish_kind=="divine_hand" and game.rules.wins==[1,0] and not is_instance_valid(game.hand_effect),"Effects-off applies the identical winning hand without a cinematic")
	check(game.rules.divine_hand_cells().all(func(p:Vector2i):return game.stones[p].get_meta("color")==2),"Effects-off synchronizes every hand stone")
	check(overlap_frames==0,"No ordinary thunder overlaps the hand")
	var report:=FileAccess.open(output+"/hand-playback.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"overlap_frames":overlap_frames,"voices":skill_voice_paths},"  "))
	print("DIVINE HAND PLAYBACK: ",checks," checks; ",failures.size()," failures")
	await game._shutdown_audio()
	get_tree().quit(0 if failures.is_empty() else 1)
