extends "res://tests/playback_v2.gd"

const Recoil=preload("res://scripts/stone_recoil.gd")
const Storm=preload("res://scripts/lightning_strike.gd")
var overlap_frames:=0
var thunder_count:=0
var charge_levels:Array[Dictionary]=[]
var hover_measurements:Array[Dictionary]=[]

func _process(_delta:float) -> void:
	if game==null:return
	if game.in_cinema or is_instance_valid(game.charge_preview) or is_instance_valid(game.bow_preview):
		if game.fx.get_children().any(func(n:Node):return (n is Recoil or n is Storm) and not n.is_queued_for_deletion()):overlap_frames+=1

func move_pointer(screen:Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.set_meta("replay_input",true)
	event.position=screen;event.global_position=screen
	get_viewport().push_input(event,true)

func point(screen:Vector2) -> void:
	move_pointer(screen)
	await pause(.06)

func hovering(p:Vector2i,color:int) -> bool:
	return game.hover_preview.visible and game.hover_cell==p and game.hover_preview.get_meta("color")==color and game.hover_models[color].visible

func no_charge() -> bool:
	return not is_instance_valid(game.charge_preview) and not is_instance_valid(game.charge_radiance) and not game.charge_ready

func projected_preview_center(color:int) -> Vector2:
	var low:=Vector2(INF,INF)
	var high:=-low
	for mesh:MeshInstance3D in game.hover_models[color].find_children("*","MeshInstance3D"):
		for corner in 8:
			var vertex:=mesh.global_transform*mesh.get_aabb().get_endpoint(corner)
			var pixel:Vector2=game.scenery.camera.unproject_position(vertex)
			low=low.min(pixel);high=high.max(pixel)
	return (low+high)*.5

func check_hover_alignment() -> void:
	var old_size:=get_window().size
	for size in [Vector2i(1280,800),Vector2i(1920,1200)]:
		get_window().size=size
		await pause(.25)
		for color in [1,2]:
			game.rules.turn=color
			for cell:Vector2i in [Vector2i(0,0),Vector2i(14,0),Vector2i(7,7),Vector2i(0,14),Vector2i(14,14)]:
				var target:=pos(cell)
				move_pointer(target)
				check(hovering(cell,color),"pointer updates immediately: %s, color %d, cell %s"%[size,color,cell])
				var pixels_per_unit:=float(size.x)/get_viewport().get_visible_rect().size.x
				var error:=projected_preview_center(color).distance_to(target)*pixels_per_unit
				hover_measurements.append({"size":str(size),"color":color,"cell":str(cell),"error_pixels":error})
				check(error<1.0,"visible stone stays within one pixel of its target: %.3f px"%error)
				await pause(.015)
	game.rules.turn=1
	get_window().size=old_size
	await pause(.25)
	await point(pos(Vector2i(7,7)))
	var before:=projected_preview_center(1)
	await pause(.70)
	check(projected_preview_center(1).distance_to(before)<.01,"stationary cursor has no floating or vertical bob")
	var selected:Vector2i=game.hover_cell
	button(pos(selected),true);button(pos(selected),false)
	await idle()
	check(game.rules.at(selected)==1 and game.rules.last==selected,"click places on the exact previewed intersection")
	await fixture(0,1)

func light_sample(name:String) -> void:
	await capture(name)
	var frame:=get_viewport().get_texture().get_image()
	var center:Vector2=game.scenery.camera.unproject_position(game.charge_radiance.global_position)*Vector2(frame.get_size())/get_viewport().get_visible_rect().size
	# Compare the rendered pigment with the same scene without its billboard.
	# The annulus excludes the stone and its small physical specular reflection.
	game.charge_radiance.rays.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var background:=get_viewport().get_texture().get_image()
	game.charge_radiance.rays.show()
	var total:=0.0
	var count:=0
	var ink_pixels:=0
	var bright_pixels:=0
	var outer_ink:=0
	for y in range(int(center.y)-220,int(center.y)+220,2):
		for x in range(int(center.x)-220,int(center.x)+220,2):
			var radius:=Vector2(x,y).distance_to(center)
			if radius<50 or radius>220:continue
			if x>=0 and x<frame.get_width() and y>=0 and y<frame.get_height():
				var luma:=frame.get_pixel(x,y).get_luminance()
				var difference:=luma-background.get_pixel(x,y).get_luminance()
				total+=luma;count+=1
				if difference<-.12:
					ink_pixels+=1
					if radius>120:outer_ink+=1
				if difference>.12:bright_pixels+=1
	charge_levels.append({"frame":name,"progress":game.charge_radiance.progress,"light_energy":game.charge_radiance.light.light_energy,"image_luma":total/maxi(count,1),"ink_pixels":ink_pixels,"outer_ink_pixels":outer_ink,"bright_pixels":bright_pixels})

func run(target) -> void:
	game=target
	var version:=str(ProjectSettings.get_setting("application/config/version")).split(".")
	output=ProjectSettings.globalize_path("res://verification/v%s.%s"%[version[0],version[1]])
	var hover_only:=OS.get_cmdline_user_args().has("--hover-check")
	if hover_only:output=ProjectSettings.globalize_path("res://verification/v"+str(ProjectSettings.get_setting("application/config/version")))
	game.apply_settings(true,true,true,true,true)
	game.fx.thunder_struck.connect(func():thunder_count+=1)
	if OS.get_cmdline_user_args().has("--charge-showcase"):
		await fixture(2,1)
		seed_board([[6,6]],1);seed_board([[8,6]],2)
		button(pos(Vector2i(7,7)),true);await pause(.68)
		await light_sample("charge-early")
		await pause(.56);await light_sample("charge-middle")
		await pause(.82);await light_sample("charge-full")
		FileAccess.open(output+"/charge-preview.json",FileAccess.WRITE).store_string(JSON.stringify(charge_levels,"  "))
		await pause(.5);game._cancel_gesture()
		await game._shutdown_audio()
		get_tree().quit()
		return
	await fixture(0,1)
	if hover_only:await check_hover_alignment()
	seed_board([[3,3],[5,5]],1);seed_board([[3,4],[6,5]],2)
	await point(pos(Vector2i(7,7)))
	check(hovering(Vector2i(7,7),1) and is_equal_approx(game.hover_preview.position.y,game.HEIGHT),"empty point shows an aligned black cursor without artificial lift")
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
	if OS.get_cmdline_user_args().has("--isolated-replay"):game._pointer_left()
	else:get_window().mouse_exited.emit()
	await pause(.06)
	check(not game.hover_preview.visible,"leaving the game window clears the cursor")
	await point(pos(Vector2i(9,7)))
	check(hovering(Vector2i(9,7),2),"returning to the window restores the correct cursor")
	game.return_to_menu();await pause(.08)
	check(not game.hover_preview.visible,"returning to the title clears the cursor")
	if hover_only:
		FileAccess.open(output+"/hover-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"measurements":hover_measurements},"  "))
		print("HOVER CHECK: ",checks," checks; ",failures.size()," failures")
		await game._shutdown_audio()
		get_tree().quit(0 if failures.is_empty() else 1)
		return

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
	await click(Vector2i(6,6));await idle();await click(Vector2i(8,6));await idle()
	var before:=thunder_count
	var held:=pos(Vector2i(7,7))
	button(held,true);await pause(.68)
	check(is_instance_valid(game.charge_radiance) and not game.hover_preview.visible,"holding replaces the cursor with the charged stone and light rays")
	if not is_instance_valid(game.charge_radiance):
		FileAccess.open(output+"/feedback-result.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures,"press_cell":str(game.press_cell),"hold_time":game.hold_time,"turn":game.rules.turn,"busy":game.busy,"window_size":str(get_window().size)},"  "))
		await game._shutdown_audio()
		get_tree().quit(1)
		return
	await light_sample("charge-early")
	await pause(.56);await light_sample("charge-middle")
	await pause(.82);await light_sample("charge-full")
	check(charge_levels[0].progress<charge_levels[1].progress and charge_levels[1].progress<charge_levels[2].progress and charge_levels[2].progress==1.0,"ink reach and density grow all the way to full charge")
	check(charge_levels[0].ink_pixels<charge_levels[1].ink_pixels and charge_levels[1].ink_pixels<charge_levels[2].ink_pixels,"rendered black energy grows across all three stages")
	check(charge_levels[2].outer_ink_pixels>charge_levels[0].outer_ink_pixels+60,"black rays visibly extend beyond the held stone")
	check(charge_levels[2].ink_pixels>charge_levels[2].bright_pixels*8 and charge_levels[2].light_energy<.5,"black charging is pigment with a small reflection, never a white spotlight")
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
	if OS.get_cmdline_user_args().has("--isolated-replay"):game._pointer_left()
	else:get_window().focus_exited.emit()
	await pause(.14)
	check(no_charge() and not is_instance_valid(game.charge_audio),"losing window focus cancels the entire charged gesture")
	button(held,false)
	button(held,true);await pause(2.17)
	check(game.charge_ready,"focus cancellation allows a fresh full charge at the same board point")
	if not game.charge_ready:print("CHARGE STATE: ",game.hold_time," press=",game.press_cell," paused=",game.paused," turn=",game.rules.turn," ready=",game.charge_ready)
	button(held,false)
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
