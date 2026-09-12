extends "res://tests/playback_v2.gd"

const Recoil=preload("res://scripts/stone_recoil.gd")
const Storm=preload("res://scripts/lightning_strike.gd")
var overlap_frames:=0
var thunder_count:=0
var charge_levels:Array[Dictionary]=[]

func _process(_delta:float) -> void:
	if game==null:return
	if game.in_cinema or is_instance_valid(game.charge_preview) or is_instance_valid(game.bow_preview):
		if game.fx.get_children().any(func(n:Node):return (n is Recoil or n is Storm) and not n.is_queued_for_deletion()):overlap_frames+=1

func point(screen:Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.position=screen;event.global_position=screen
	get_viewport().push_input(event,true)
	await pause(.06)

func hovering(p:Vector2i,color:int) -> bool:
	return game.hover_preview.visible and game.hover_cell==p and game.hover_preview.get_meta("color")==color and game.hover_models[color].visible

func no_charge() -> bool:
	return not is_instance_valid(game.charge_preview) and not is_instance_valid(game.charge_radiance) and not game.charge_ready

func light_sample(name:String) -> void:
	await capture(name)
	var frame:=get_viewport().get_texture().get_image()
	var center:=pos(Vector2i(7,7))*Vector2(frame.get_size())/get_viewport().get_visible_rect().size
	var total:=0.0
	var count:=0
	var ray_pixels:=0
	for y in range(int(center.y)-175,int(center.y)+90,5):
		for x in range(int(center.x)-210,int(center.x)+210,5):
			if x>=0 and x<frame.get_width() and y>=0 and y<frame.get_height():
				total+=frame.get_pixel(x,y).get_luminance();count+=1
				if y<center.y-75 and frame.get_pixel(x,y).get_luminance()>.90:ray_pixels+=1
	charge_levels.append({"frame":name,"progress":game.charge_radiance.progress,"light_energy":game.charge_radiance.light.light_energy,"image_luma":total/maxi(count,1),"ray_pixels":ray_pixels})

func run(target) -> void:
	game=target
	output=ProjectSettings.globalize_path("res://verification/v2.4")
	game.apply_settings(true,true,true,true,true)
	game.fx.thunder_struck.connect(func():thunder_count+=1)
	if OS.get_cmdline_user_args().has("--charge-showcase"):
		await fixture(2,1)
		seed_board([[6,6]],1);seed_board([[8,6]],2)
		button(pos(Vector2i(7,7)),true);await pause(.68)
		await light_sample("charge-early")
		await pause(.56);await light_sample("charge-middle")
		await pause(.82);await light_sample("charge-full")
		await pause(.5);game._cancel_gesture()
		await game._shutdown_audio()
		get_tree().quit()
		return
	await fixture(0,1)
	seed_board([[3,3],[5,5]],1);seed_board([[3,4],[6,5]],2)
	await point(pos(Vector2i(7,7)))
	check(hovering(Vector2i(7,7),1) and game.hover_preview.position.y>game.HEIGHT,"empty point shows a floating black cursor")
	check(game.rules.move_count==0 and game.stones.size()==4,"hovering never places a stone or changes the turn")
	check(game.hover_preview.find_children("*","GPUParticles3D",true,false).is_empty(),"both players' cursor stays free of skill hints and auras")
	await capture("hover-black")
	await point(pos(Vector2i(8,7))+Vector2(3,2))
	check(hovering(Vector2i(8,7),1),"hover snaps to the nearest legal intersection")
	await point(pos(Vector2i(3,3)))
	check(not game.hover_preview.visible,"occupied intersections hide the cursor")
	await point(Vector2(20,500))
	check(not game.hover_preview.visible,"sidebar and outside-board movement hide the cursor")
	await point(pos(Vector2i(7,7)))
	game.ui.show_pause();await pause(.08)
	check(not game.hover_preview.visible,"pause menu hides the board cursor")
	game.ui.close_modal();await pause(.08)
	check(hovering(Vector2i(7,7),1),"closing a menu restores the cursor without needing another mouse movement")
	button(pos(Vector2i(7,7)),true);await pause(.06)
	check(not game.hover_preview.visible,"pressed input hides the separate hover model")
	button(pos(Vector2i(7,7)),false);await pause(.08)
	check(game.busy and not game.hover_preview.visible,"placement animation does not show a second stone")
	await idle()
	await point(pos(Vector2i(8,7)))
	check(hovering(Vector2i(8,7),2),"turn change gives the ordinary player a white cursor")
	await capture("hover-white")
	game.apply_settings(true,true,true,false,false);await pause(.08)
	check(hovering(Vector2i(8,7),2),"cursor remains usable with both special features switched off")
	get_window().mouse_exited.emit();await pause(.06)
	check(not game.hover_preview.visible,"leaving the game window clears the cursor")
	await point(pos(Vector2i(9,7)))
	check(hovering(Vector2i(9,7),2),"returning to the window restores the correct cursor")
	game.return_to_menu();await pause(.08)
	check(not game.hover_preview.visible,"returning to the title clears the cursor")

	game.apply_settings(true,true,true,true,true)
	for scenario in [[0,1],[1,2],[2,1],[2,2],[3,2],[3,1],[4,1]]:
		var round_index:int=scenario[0]
		var color:int=scenario[1]
		await fixture(round_index,color)
		var expected:bool=round_index>=2 and game.rules.current_player()==0
		var enemy_cells:Array[Vector2i]=[Vector2i(6,7),Vector2i(9,8),Vector2i(2,11),Vector2i(12,3)]
		seed_board([[6,7],[9,8],[2,11],[12,3]],3-color)
		seed_board([[5,5],[9,5]],color)
		var rest:Dictionary={}
		for p:Vector2i in game.stones:rest[p]=game.stones[p].transform
		var board:Array[int]=game.rules.board.duplicate()
		button(pos(Vector2i(7,7)),true);button(pos(Vector2i(7,7)),false)
		await pause(.36)
		check(enemy_cells.all(func(p:Vector2i):return (game.stones[p].position.y>game.HEIGHT+.10)==expected),"opponent recoil gate: round %d, color %d"%[round_index+1,color])
		check(game.stones[Vector2i(5,5)].transform.is_equal_approx(rest[Vector2i(5,5)]) and game.stones[Vector2i(9,5)].transform.is_equal_approx(rest[Vector2i(9,5)]),"friendly stones remain on their original intersections")
		if expected and round_index in [2,3]:await capture("recoil-"+str(color))
		await idle()
		check(rest.keys().all(func(p:Vector2i):return game.stones[p].transform.is_equal_approx(rest[p])),"every lifted stone returns to its exact transform")
		board[7*15+7]=color
		check(game.rules.board==board and game.rules.move_count==1,"recoil changes neither board ownership nor move count")

	await fixture(2,1)
	seed_board([[6,7],[9,8]],2)
	button(pos(Vector2i(7,7)),true);button(pos(Vector2i(7,7)),false);await pause(.34)
	game.apply_settings(true,true,true,false,true);await pause(.06)
	check(game.stones[Vector2i(6,7)].position.is_equal_approx(game.world(Vector2i(6,7))) and not game.fx.get_children().any(func(n:Node):return n is Recoil and not n.is_queued_for_deletion()),"switching effects off mid-recoil restores all stones immediately")
	await idle()
	await fixture(2,1)
	seed_board([[6,7],[9,8]],2)
	await click(Vector2i(7,7));await idle()
	check(game.stones[Vector2i(6,7)].position.is_equal_approx(game.world(Vector2i(6,7))),"disabled effects keep opponents stationary")
	game.apply_settings(true,true,true,true,false)
	await fixture(2,1);seed_board([[6,7],[9,8]],2)
	button(pos(Vector2i(7,7)),true);button(pos(Vector2i(7,7)),false);await pause(.36)
	check(game.stones[Vector2i(6,7)].position.y>game.HEIGHT+.1,"ordinary recoil remains available with hidden skills off")
	await idle()

	game.apply_settings(true,true,true,true,true)
	await fixture(2,1)
	await click(Vector2i(6,6));await idle();await click(Vector2i(8,6))
	var before:=thunder_count
	var held:=pos(Vector2i(7,7))
	button(held,true);await pause(.68)
	check(is_instance_valid(game.charge_radiance) and not game.hover_preview.visible,"holding replaces the cursor with the charged stone and light rays")
	await light_sample("charge-early")
	await pause(.56);await light_sample("charge-middle")
	await pause(.82);await light_sample("charge-full")
	check(charge_levels[0].progress<charge_levels[1].progress and charge_levels[1].progress<charge_levels[2].progress and charge_levels[2].progress==1.0,"ray reach and brightness grow all the way to full charge")
	check(charge_levels[0].image_luma<charge_levels[1].image_luma and charge_levels[1].image_luma<charge_levels[2].image_luma,"rendered charge region visibly brightens across all three stages")
	check(charge_levels[2].ray_pixels>charge_levels[0].ray_pixels+30,"light rays visibly extend beyond the reflection directly under the stone")
	check(game.charge_ready and game.rules.at(Vector2i(7,7))==0,"full charge stays uncommitted until release")
	await pause(1.1)
	check(game.charge_ready and game.charge_radiance.progress==1.0 and game.rules.at(Vector2i(7,7))==0,"holding past the sound's duration keeps a stable charge without auto-firing")
	motion(held+Vector2(115,0));button(held+Vector2(115,0),false);await pause(.18)
	check(no_charge() and not is_instance_valid(game.charge_audio) and game.rules.at(Vector2i(7,7))==0,"drag cancellation clears every light and voice without placing")
	button(held,true);await pause(.72)
	game.ui.show_help();await pause(.14)
	check(no_charge(),"opening settings cancels the growing light")
	button(held,false);game.ui.close_modal()
	button(held,true);await pause(.72)
	get_window().focus_exited.emit();await pause(.14)
	check(no_charge() and not is_instance_valid(game.charge_audio),"losing window focus cancels the entire charged gesture")
	button(held,false)
	button(held,true);await pause(2.17);button(held,false)
	await pause(.10)
	check(no_charge() and not game.hover_preview.visible,"release clears charging rays before the impact cinematic")
	await idle()
	check(game.rules.board.count(1)==225 and game.rules.wins==[1,0] and thunder_count==before,"charged cosmos resolves once with no added thunder or recoil")
	check(overlap_frames==0,"no recoil or lightning overlaps charging and skill cinematics")
	check(not game.hover_preview.visible,"finished round never shows an actionable hover cursor")
	FileAccess.open(output+"/feedback-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"overlap_frames":overlap_frames,"charge_levels":charge_levels},"  "))
	print("FEEDBACK CHECK: ",checks," checks; ",failures.size()," failures")
	await game._shutdown_audio()
	get_tree().quit(0 if failures.is_empty() else 1)
