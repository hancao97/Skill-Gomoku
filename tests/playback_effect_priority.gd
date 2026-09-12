extends "res://tests/playback_v2.gd"

const Storm=preload("res://scripts/lightning_strike.gd")

var thunder_count:=0
var overlap_frames:=0

func _process(_delta:float) -> void:
	if game==null:return
	if game.in_cinema or is_instance_valid(game.charge_preview) or is_instance_valid(game.bow_preview):
		if lightning_present() or thunder_playing():overlap_frames+=1

func lightning_present() -> bool:
	return game.fx.get_children().any(func(n:Node):return n is Storm and n.visible and not n.is_queued_for_deletion())

func thunder_playing() -> bool:
	return game.fx.get_children().any(func(n:Node):return n is AudioStreamPlayer and n.has_meta("placement_thunder") and n.playing)

func normal_storm_move(p:Vector2i) -> void:
	var before:=thunder_count
	await click(p)
	await pause(.44)
	check(thunder_count==before+1 and thunder_playing(),"ordinary late-round move keeps lightning and its thunder tail")

func run(target) -> void:
	game=target
	game.apply_settings(true,true,true)
	var version:String=ProjectSettings.get_setting("application/config/version")
	output=ProjectSettings.globalize_path("res://verification/v"+version.get_slice(".",0)+"."+version.get_slice(".",1))
	game.fx.thunder_struck.connect(func():thunder_count+=1)
	# A quick ordinary reply leaves the previous rumble alive when charging starts.
	await fixture(2,1)
	await normal_storm_move(Vector2i(6,6))
	await click(Vector2i(8,6))
	check(thunder_playing(),"cosmos starts while previous normal thunder still has a tail")
	var before:=thunder_count
	var press:=pos(Vector2i(7,7))
	button(press,true)
	await pause(.43)
	check(is_instance_valid(game.charge_preview) and not thunder_playing() and not lightning_present(),"charging clears old thunder and arcs before its own effects")
	await pause(1.75)
	button(press,false)
	await pause(1.35)
	check(thunder_count==before and not thunder_playing() and not lightning_present(),"cosmos impact uses only its own effects")
	await idle()
	check(game.rules.board.count(1)==225 and game.rules.wins==[1,0],"cosmos outcome remains intact")
	# The fourth white that creates the moon must never launch a placement strike.
	await fixture(3,2)
	seed_board([[7,7],[8,7]],2)
	await normal_storm_move(Vector2i(7,8))
	await click(Vector2i(0,0))
	check(thunder_playing(),"moon test includes a real leftover thunder tail")
	before=thunder_count
	button(pos(Vector2i(8,8)),true);button(pos(Vector2i(8,8)),false)
	await pause(.27)
	check(thunder_count==before and not thunder_playing() and not lightning_present(),"moon-triggering placement suppresses lightning and old thunder immediately")
	await idle()
	check(game.rules.board.count(2)==25 and game.rules.finish_kind=="moon", "moon still fills its 5 by 5 square")
	# An armed T retains normal thunder until the user actually pulls the bow.
	await fixture(2,1)
	seed_board([[7,5],[7,6],[6,6]],1)
	await normal_storm_move(Vector2i(7,7))
	await click(Vector2i(0,0))
	check(game.rules.pending_skill=="bow" and thunder_playing(),"hidden ready bow leaves normal move presentation intact")
	before=thunder_count
	var start:=pos(Vector2i(6,6))
	var pull:Vector2=game.scenery.camera.unproject_position(game.world(Vector2i(6,6))+Vector3(-.95,0,0))
	button(start,true);motion(pull)
	await pause(.12)
	check(is_instance_valid(game.bow_preview) and not thunder_playing() and not lightning_present(),"active bow draw clears old thunder")
	button(pull,false)
	await idle()
	check(thunder_count==before and game.rules.finish_kind=="bow", "arrow cinematic does not add placement thunder")
	check(overlap_frames==0,"zero frames with lightning or thunder during any skill or charge")
	# Cancel both an active bolt and the old voice fading beneath the new one.
	await fixture(2,1)
	game.fx.lightning(game.world(Vector2i(7,7)),1)
	game.fx.lightning(game.world(Vector2i(8,7)),1)
	check(thunder_playing() and lightning_present(),"cleanup fixture has live bolts and thunder voices")
	game.fx.clear_lightning()
	check(not thunder_playing() and not lightning_present(),"cleanup stops all active and fading storm layers immediately")
	await pause(.2)
	await normal_storm_move(Vector2i(5,5))
	var file:=FileAccess.open(output+"/effect-priority-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"overlap_frames":overlap_frames,"thunder_count":thunder_count},"  "))
	print("EFFECT PRIORITY: ",checks," checks; ",failures.size()," failures; ",overlap_frames," overlapping frames")
	await game._shutdown_audio()
	get_tree().quit(0 if failures.is_empty() else 1)
