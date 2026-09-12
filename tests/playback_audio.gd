extends "res://tests/playback_v2.gd"

var recorder: AudioEffectRecord
var marks: Array[Dictionary] = []
var recorded_time := 0.0
var recording := false
var recording_clock: AudioStreamPlayer
var thunder_count := 0
var overlap_frames := 0

func _process(_delta: float) -> void:
	if recording:recorded_time=recording_clock.get_playback_position()
	if game and (game.in_cinema or is_instance_valid(game.charge_preview) or is_instance_valid(game.bow_preview)):
		if game.fx.get_children().any(func(n:Node):return n is AudioStreamPlayer and n.has_meta("placement_thunder") and n.playing):overlap_frames+=1

func mark(label: String) -> void:
	marks.append({"label":label,"seconds":recorded_time})
	print("AUDIO SECTION: ",label)

func run(target) -> void:
	game=target
	var version:String=ProjectSettings.get_setting("application/config/version")
	output=ProjectSettings.globalize_path("res://verification/v"+version.get_slice(".",0)+"."+version.get_slice(".",1))
	game.apply_settings(true,true,true)
	game.fx.thunder_struck.connect(func():thunder_count+=1)
	check(AudioServer.get_mix_rate()==48000,"48 kHz engine mix matches sound effects")
	check(AudioServer.get_bus_effect(0,1) is AudioEffectHardLimiter,"all buses pass through the master lookahead limiter")
	check(is_equal_approx(AudioServer.get_bus_effect(0,1).ceiling_db,-2),"master ceiling retains 2 dB reconstruction headroom")
	for cue: String in game.fx.CUES:
		var stream: AudioStreamWAV=game.fx.CUES[cue]
		check(stream.format==AudioStreamWAV.FORMAT_16_BITS and stream.stereo and stream.mix_rate==48000,"lossless preloaded stereo cue: "+cue)
	check(game.scenery.rain_audio.bus==&"Rain" and game.scenery.music.bus==&"Music","ambient layers have independent buses")
	recorder=AudioEffectRecord.new()
	recorder.format=AudioStreamWAV.FORMAT_16_BITS
	AudioServer.add_bus_effect(0,recorder)
	# Tag sections against the audio sample clock, not wall/render time. Dummy drivers
	# may run slower under GPU load; that must not mislabel the captured waveform.
	recording_clock=AudioStreamPlayer.new()
	var silence:=AudioStreamWAV.new()
	silence.format=AudioStreamWAV.FORMAT_16_BITS
	silence.mix_rate=48000
	var zeroes:=PackedByteArray()
	zeroes.resize(48000*2*120)
	silence.data=zeroes
	recording_clock.stream=silence
	add_child(recording_clock)
	recorder.set_recording_active(true)
	recording_clock.play()
	recording=true
	mark("ordinary-stones")
	await fixture(0,1)
	await click(Vector2i(7,7));await click(Vector2i(8,7))
	check(thunder_count==0,"early rounds retain dry stone sounds")
	mark("late-round-thunder")
	await fixture(2,1)
	seed_board([[5,6],[7,8],[10,5]],2)
	await click(Vector2i(6,6));await idle()
	var before:=thunder_count
	await click(Vector2i(8,6))
	check(before==1 and thunder_count==before,"only the original first player receives ordinary thunder")
	mark("charge-cancel")
	var at:=pos(Vector2i(7,7))
	button(at,true);await pause(.90)
	check(is_instance_valid(game.charge_preview),"charge begins directly on the board")
	await pause(2.05)
	check(is_instance_valid(game.charge_audio) and game.charge_audio.playing and game.charge_audio.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,"full charge sustains audibly past the intro without restarting")
	game._cancel_gesture()
	await pause(.14)
	check(not is_instance_valid(game.charge_audio),"cancelled charge releases its voice")
	mark("mute-during-impact-and-duck")
	var voice=game.fx.sound("cosmos_impact",-1)
	await pause(.21)
	game.scenery.duck(1.0)
	game.apply_settings(false,false,true)
	await pause(.36)
	check(not is_instance_valid(voice),"muting releases an already playing impact")
	check(game.scenery.rain_audio.volume_linear==0 and game.scenery.music.volume_linear==0,"both ambient layers fade to exact silence")
	await pause(1.3)
	check(game.scenery.rain_audio.volume_linear==0 and game.scenery.music.volume_linear==0,"duck recovery cannot undo saved mute preferences")
	check(game.fx.sound("stone_01")==null,"muted effects do not start new voices")
	game.apply_settings(true,true,true)
	await pause(.35)
	check(game.scenery.rain_audio.volume_linear>0 and game.scenery.music.volume_linear>0,"unmuting fades the ambience back in")
	mark("bow")
	await fixture(2,1)
	seed_board([[7,5],[7,6],[6,6]],1)
	await click(Vector2i(7,7));await idle();await click(Vector2i(0,0))
	var start:=pos(Vector2i(6,6))
	var pull:Vector2=game.scenery.camera.unproject_position(game.world(Vector2i(6,6))+Vector3(-.95,0,0))
	mark("bow-performance")
	button(start,true)
	motion(start.lerp(pull,.45));await pause(.18)
	var light_tension:float=game.draw_audio.volume_db
	motion(pull);await pause(1.60)
	check(is_instance_valid(game.draw_audio) and game.draw_audio.playing and game.draw_audio.volume_db>light_tension,"bow tension follows the drag and sustains while held")
	motion(start);await pause(.18)
	check(not is_instance_valid(game.draw_audio),"relaxing the bow releases the tension voice")
	motion(pull);await pause(.35);button(pull,false)
	await idle()
	check(game.rules.finish_kind=="bow","arrow mix follows a real winning shot")
	mark("moon")
	await fixture(3,2)
	seed_board([[7,7],[8,7],[7,8]],2)
	seed_board([[9,8],[6,7]],1)
	before=thunder_count
	mark("moon-performance")
	await click(Vector2i(8,8));await idle()
	check(game.rules.board.count(2)==25 and thunder_count==before,"white 5 by 5 skill keeps its own soundtrack")
	mark("cosmos")
	await fixture(2,1)
	seed_board([[6,6],[8,6]],1);seed_board([[7,6],[8,8]],2)
	mark("cosmos-performance")
	at=pos(Vector2i(7,7));button(at,true);await pause(2.22);button(at,false)
	await idle()
	check(game.rules.board.count(1)==225,"charged impact still fills the whole board")
	check(overlap_frames==0,"no thunder voice overlaps a skill or its charging gesture")
	mark("victory-and-next-round")
	await fixture(0,1)
	seed_board([[4,7],[5,7],[6,7],[7,7]],1)
	await click(Vector2i(8,7));await idle();await pause(.8)
	game.next_round();await pause(.25)
	check(not game.fx.get_children().any(func(n:Node):return n is AudioStreamPlayer and n.playing),"next round smoothly releases the victory tail")
	mark("rapid-settings")
	for i in 8:
		game.scenery.duck(.8)
		game.apply_settings(i%2==0,i%3==0,true)
		await pause(.065)
	game.apply_settings(false,false,true);await pause(1.5)
	check(game.scenery.rain_audio.volume_linear==0 and game.scenery.music.volume_linear==0,"rapid toggles settle on the latest preference")
	game.apply_settings(true,true,true);await pause(.4)
	mark("loop-seams")
	# Seek near both wrap points and capture the real streamed decoder crossing each seam.
	game.scenery.rain_audio.play(58.0)
	game.scenery.music.play(22.0)
	await pause(5.0)
	check(game.scenery.rain_audio.playing and game.scenery.music.playing,"rain and music stay live through their loop seams")
	mark("limiter-stress")
	# Intentional overload, outside gameplay: prove that even a bad mix cannot clip output.
	for i in 8:game.fx.sound("cosmos_impact",6)
	for i in 4:game.fx.sound("thunder_01",3)
	await pause(4.6)
	game.fx.clear_transients()
	mark("release-to-silence")
	game.apply_settings(false,false,true);await pause(1.0)
	recorder.set_recording_active(false)
	recording=false
	var wav:=recorder.get_recording()
	check(wav!=null and wav.data.size()>48000*4,"actual master mix was recorded")
	if wav:wav.save_to_wav(output+"/engine-mix.wav")
	AudioServer.remove_bus_effect(0,AudioServer.get_bus_effect_count(0)-1)
	wav=null
	recorder=null
	recording_clock.stop()
	recording_clock.queue_free()
	var result:={"checks":checks,"failures":failures,"overlap_frames":overlap_frames,"mix_rate":AudioServer.get_mix_rate(),"markers":marks,"duration":recorded_time}
	FileAccess.open(output+"/audio-playback.json",FileAccess.WRITE).store_string(JSON.stringify(result,"  "))
	print("AUDIO CHECK: ",checks," checks; ",failures.size()," failures; ",overlap_frames," overlapping frames")
	await game._shutdown_audio()
	get_tree().quit(0 if failures.is_empty() else 1)
