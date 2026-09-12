extends "res://tests/playback_v2.gd"

var storms:Array[Dictionary]=[]

func run(target) -> void:
	game=target
	game.apply_settings(true,true,true)
	var version:=str(ProjectSettings.get_setting("application/config/version")).split(".")
	output=ProjectSettings.globalize_path("res://verification/v%s.%s"%[version[0],version[1]])
	game.fx.thunder_struck.connect(func():
		var p:Vector2i=game.rules.last
		storms.append({"round":game.rules.round_index+1,"color":game.stones[p].get_meta("color"),"height":game.stones[p].position.y,"sample":game.fx.thunder_voice.stream.resource_path if is_instance_valid(game.fx.thunder_voice) else ""})
	)
	if OS.get_cmdline_user_args().has("--storm-showcase"):
		await storm_showcase()
		get_tree().quit()
		return
	for round_index in 5:
		for player in [0,1]:
			var color:int=1 if player==round_index%2 else 2
			await fixture(round_index,color)
			var expected:bool=round_index>=2 and player==0
			var before:=storms.size()
			var spot:=Vector2i(7,7)
			button(pos(spot),true);button(pos(spot),false)
			await pause(.28)
			var strikes:Array=game.fx.get_children().filter(func(n:Node):return n.name.begins_with("LightningStrike"))
			check((storms.size()==before+1)==expected,"storm gate: round %d, player %d"%[round_index+1,player+1])
			check((strikes.size()==1)==expected,"actual lightning visibility: round %d, player %d"%[round_index+1,player+1])
			if expected:
				check(strikes[0].color==color and strikes[0].material.get_shader_parameter("white_stone")==bool(color==2),"lightning palette follows stone color")
				check(is_equal_approx(storms.back().height,game.HEIGHT) and storms.back().sample.contains("/thunder_"),"thunder starts at stone contact")
				await capture("round-%d-lightning-%s"%[round_index+1,"black" if color==1 else "white"])
				button(pos(Vector2i(8,7)),true);button(pos(Vector2i(8,7)),false)
				check(storms.size()==before+1 and game.rules.move_count==1,"rapid second click cannot add a move or repeat thunder")
			await pause(.70)
			check(not game.busy and game.fx.get_children().filter(func(n:Node):return n.name.begins_with("LightningStrike")).is_empty(),"strike ends before next move")
			check(game.rules.move_count==1 and game.rules.at(spot)==color and game.rules.active(),"thunder remains a placement effect without changing the rules")
			if player==1:
				check(game.stones[spot].find_children("*","GPUParticles3D",true,false).is_empty(),"other player's stone stays ordinary")
	# Muted players still see lightning, with no thunder AudioStreamPlayer.
	await fixture(2,1)
	game.apply_settings(false,true,true)
	button(pos(Vector2i(6,7)),true);button(pos(Vector2i(6,7)),false)
	await pause(.3)
	check(storms.back().sample=="" and not is_instance_valid(game.fx.thunder_voice),"mute preference silences thunder")
	await pause(.8)
	var before:=storms.size()
	await click(Vector2i(6,7))
	check(storms.size()==before and game.rules.move_count==1,"occupied point does not trigger thunder")
	# Resume a saved third-round position and retain the phase and ownership.
	var saved:Dictionary=game.rules.serialize()
	check(game.rules.restore(saved) and game.rules.has_storm(1) and not game.rules.has_storm(2),"restored third round keeps storm ownership")
	game.rules._finish(-1,"draw")
	game.rules.next_round()
	check(game.rules.round_index==2 and game.rules.has_storm(1),"third-round draw replay retains thunder")
	# Skill cinematics take precedence over ordinary placement thunder.
	await fixture(2,1)
	game.apply_settings(true,true,true)
	before=storms.size()
	button(pos(Vector2i(7,7)),true)
	await pause(2.1)
	button(pos(Vector2i(7,7)),false)
	await pause(1.4)
	check(storms.size()==before,"third-round cosmos does not add placement lightning")
	await idle()
	check(game.rules.board.count(1)==225 and game.rules.wins==[1,0],"separate ultimate presentation keeps its single-win outcome")
	var file:=FileAccess.open(output+"/storm-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"storms":storms},"  "))
	print("STORM PLAYBACK: ",checks," checks; ",failures.size()," failures")
	get_tree().quit(0 if failures.is_empty() else 1)

func storm_showcase() -> void:
	for index in [2,3]:
		await fixture(index,1 if index%2==0 else 2)
		seed_board([[6,6],[9,8]],1)
		seed_board([[7,6],[8,8]],2)
		for point:Vector2i in [Vector2i(7,7),Vector2i(10,8),Vector2i(8,7)]:
			await click(point)
			await pause(1.4)
		await pause(.7)
