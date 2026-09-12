extends SceneTree

const Rules = preload("res://scripts/rules.gd")
var checks := 0
var failures: Array[String] = []

func check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures.append(detail)
		push_error(detail)

func _initialize() -> void:
	var r := Rules.new()
	check(r.board.size()==225 and r.current_player()==0, "Initial black belongs to player one")
	check(not r.place(Vector2i(-1,0)).ok, "Out of bounds rejected")
	check(r.place(Vector2i(7,7)).ok, "Legal placement accepted")
	check(r.current_player()==1, "Turns alternate")
	var snapshot := r.board.duplicate()
	check(not r.place(Vector2i(7,7)).ok and r.board==snapshot, "Occupied point is immutable")
	for d: Vector2i in Rules.AXES:
		r.reset_match()
		var start := Vector2i(0,8) if d.y < 0 else Vector2i(0,0)
		for i in 5: r.put(start+d*i,Rules.BLACK)
		check(r.line_through(start+d*2,Rules.BLACK).size()==5, "Five direction %s"%d)
	r.reset_match()
	for x in range(9,15): r.put(Vector2i(x,14),Rules.WHITE)
	check(r.line_through(Vector2i(14,14),Rules.WHITE).size()==6, "Long line at boundary wins")
	r.reset_match()
	r.put(Vector2i(14,0),1);r.put(Vector2i(0,1),1)
	check(r.line_through(Vector2i(14,0),1).is_empty(), "Rows do not wrap")
	# The screenshot's T shape waits through White's move, then fills the entire ray.
	r.reset_match()
	for p: Vector2i in [Vector2i(7,5),Vector2i(7,6),Vector2i(6,6)]: r.put(p,1)
	r.put(Vector2i(8,6),2);r.put(Vector2i(10,6),2)
	var result := r.place(Vector2i(7,7))
	check(result.empowered and result.skill=="" and r.turn==2 and r.bow_waiting(), "T shape gives White a full move first")
	check(not r.shoot_bow(Vector2i(6,6),Vector2i(1,0)).ok, "Cannot shoot immediately when T is formed")
	var waiting := Rules.new()
	check(waiting.restore(r.serialize()) and waiting.turn==2 and waiting.pending_skill=="", "Waiting bow save preserves White's move")
	var white_move := r.place(Vector2i(0,0))
	check(white_move.ok and not white_move.empowered and r.turn==1 and r.pending_skill=="bow", "White can place; next Black turn offers bow")
	check(r.bow_anchors==[Vector2i(6,6)], "Only the side stone beside the middle is the arrow")
	check(not r.place(Vector2i(0,0)).ok, "Occupied point remains blocked while a bow is ready")
	check(not r.shoot_bow(Vector2i(0,0),Vector2i(1,0)).ok, "Only nominated stone can launch")
	check(not r.shoot_bow(Vector2i(6,6),Vector2i(0,1)).ok, "T orientation fixes shot through the center")
	var armed := Rules.new()
	check(armed.restore(r.serialize()) and armed.pending_skill=="bow" and armed.bow_anchors==r.bow_anchors, "Ready bow save restores after White has moved")
	var shot := r.shoot_bow(Vector2i(6,6),Vector2i(1,0))
	check(shot.ok and shot.path[-1]==Vector2i(14,6), "Arrow reaches board edge")
	check(r.at(Vector2i(6,6))==0 and r.at(Vector2i(8,6))==1, "Projectile leaves and flips opponents")
	check(shot.path.all(func(p:Vector2i):return r.at(p)==1) and r.at(Vector2i(9,6))==1, "All ray intersections including empty points become black")
	check(r.at(Vector2i(9,7))==0, "Arrow does not change points outside its ray")
	check(r.bow_used and r.round_winner==0 and r.wins==[1,0] and r.finish_kind=="bow", "Bow directly wins this round")
	check(not r.shoot_bow(Vector2i(6,6),Vector2i(1,0)).ok and r.wins==[1,0], "Repeated release cannot score twice")
	# Short ray wins even though neither the original shape nor result has five.
	r.reset_match()
	for p: Vector2i in [Vector2i(12,6),Vector2i(12,7),Vector2i(11,7)]: r.put(p,1)
	r.place(Vector2i(12,8));r.place(Vector2i(0,0))
	var short_shot := r.shoot_bow(Vector2i(11,7),Vector2i(1,0))
	check(short_shot.ok and short_shot.path.size()==3 and r.winning_line.is_empty() and r.round_winner==0, "Three-point edge shot wins without a five")
	check(r.at(Vector2i(13,7))==1 and r.at(Vector2i(14,7))==1, "Short edge shot fills both empty intersections")
	# Exact shape, four rotations, and completing the side stone last.
	for direction: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		r.reset_match()
		var c := Vector2i(7,7)
		var perpendicular := Vector2i(-direction.y,direction.x)
		for p: Vector2i in [c-perpendicular,c,c+perpendicular]:r.put(p,1)
		r.place(c-direction)
		check(r.turn==2 and r.pending_skill=="", "Rotated T waits for White: %s"%direction)
		r.place(Vector2i(0,0))
		check(r.bow_anchors.has(c-direction) and r.bow_directions(c-direction)==[direction], "Rotated T side/flight direction: %s"%direction)
	for extra: Vector2i in [Vector2i(6,5),Vector2i(6,7),Vector2i(6,4),Vector2i(7,8)]:
		r.reset_match()
		for p: Vector2i in [Vector2i(7,5),Vector2i(7,6),Vector2i(7,7),extra]:r.put(p,1)
		check(r.find_bow_anchors().is_empty(), "Endpoint neighbor, corner or four-line is not a T: %s"%extra)
	# Declining the bow still permits a normal black placement this turn.
	check(armed.turn==1 and armed.can_charge() and armed.place(Vector2i(4,4)).ok and armed.turn==2, "Hidden bow allows a normal move without a skip button")
	armed.place(Vector2i(1,0))
	check(armed.pending_skill=="bow", "Unfired T is available again on the following Black turn")
	# White can win during the mandatory reply: a waiting T does not steal that win.
	r.reset_match()
	for p: Vector2i in [Vector2i(7,5),Vector2i(7,6),Vector2i(6,6)]:r.put(p,1)
	for x in 4:r.put(Vector2i(x,0),2)
	r.place(Vector2i(7,7));r.place(Vector2i(4,0))
	check(r.round_winner==1 and r.pending_skill=="" and not r.shoot_bow(Vector2i(6,6),Vector2i(1,0)).ok, "White's winning reply takes precedence over waiting bow")
	# Old immediate-bow saves migrate to White's reply, without changing stones/scores.
	var legacy := waiting.serialize()
	legacy.version=1;legacy.pending="bow";legacy.turn=1
	var migrated := Rules.new()
	check(migrated.restore(legacy) and migrated.turn==2 and migrated.pending_skill=="" and migrated.board==waiting.board, "Legacy bow save gives White its missing move")
	var legacy_ready := armed.serialize()
	legacy_ready.version=1;legacy_ready.pending=""
	check(migrated.restore(legacy_ready) and migrated.turn==1 and migrated.pending_skill=="bow", "Legacy Black-turn save recognizes a T after White already replied")
	# First player's privileges follow their white stones next round.
	r.reset_match()
	r._finish(0,"normal")
	check(r.next_round() and r.color_for(0)==2 and r.current_player()==1, "Colors swap, black still opens")
	r.turn=2
	for p: Vector2i in [Vector2i(7,7),Vector2i(8,7),Vector2i(7,8)]: r.put(p,2)
	r.put(Vector2i(6,7),1)
	check(r.place(Vector2i(8,8)).skill=="moon", "White square automatically readies disk")
	var moon := r.resolve_moon()
	check(moon.ok and r.at(Vector2i(6,7))==2, "Moon converts adjacent opponent")
	check(r.moon_used and r.round_winner==0 and r.finish_kind=="moon" and moon.area.size()==25 and r.board.count(2)==25, "Moon fills all 25 points, including empty ones, and directly wins")
	check(r.at(Vector2i(5,8))==0 and r.at(Vector2i(11,8))==0, "Moon leaves points beyond its five by five untouched")
	check(r.wins==[2,0] and not r.resolve_moon().ok and r.wins==[2,0], "Moon scores exactly once")
	r.reset_board()
	for p: Vector2i in [Vector2i(7,6),Vector2i(8,7),Vector2i(7,8),Vector2i(6,7)]: r.put(p,2)
	check(not r.find_moon(Vector2i(6,7)).is_empty(), "Diamond ring recognized")
	# Edge and corner skills keep a full 5 by 5 square within the board.
	for corner:Vector2i in [Vector2i(0,0),Vector2i(13,0),Vector2i(0,13),Vector2i(13,13)]:
		r.reset_match();r.round_index=1;r.turn=2
		for offset:Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1)]:r.put(corner+offset,2)
		r.place(corner+Vector2i.ONE)
		var edge_moon:=r.resolve_moon()
		check(edge_moon.ok and edge_moon.area.size()==25 and r.board.count(2)==25, "Corner moon keeps all 25 points in bounds: %s"%corner)
	# Ownership follows the first-round black player through all color swaps.
	r.reset_match();r.round_index=3;r.turn=2
	for p:Vector2i in [Vector2i(7,7),Vector2i(8,7),Vector2i(7,8)]:r.put(p,2)
	var late_moon:=r.place(Vector2i(8,8))
	check(late_moon.skill=="moon" and not late_moon.storm,"Fourth-round moon takes precedence over placement thunder")
	r.reset_match();r.round_index=3;r.turn=2
	check(r.place(Vector2i(7,7)).storm,"Ordinary fourth-round white placement retains thunder")
	for index in 5:
		r.reset_match();r.round_index=index
		check(r.has_effects(r.color_for(0)) and not r.has_effects(r.color_for(1)), "Only original Black player has effects in round %d"%(index+1))
		check(r.has_storm(r.color_for(0))==(index>=2) and not r.has_storm(r.color_for(1)), "Thunder starts in round three and belongs only to original Black player: %d"%(index+1))
	r.reset_match();r.round_index=1
	for p:Vector2i in [Vector2i(7,5),Vector2i(7,6),Vector2i(6,6)]:r.put(p,1)
	var ordinary_black := r.place(Vector2i(7,7))
	check(not ordinary_black.empowered and ordinary_black.skill=="", "Player two's black T has no effects or bow")
	r.place(Vector2i(0,0))
	check(r.pending_skill=="" and not r.can_charge(), "Player two cannot inherit black skills after color swap")
	r.reset_match();r.turn=2
	for p:Vector2i in [Vector2i(7,7),Vector2i(8,7),Vector2i(8,8)]:r.put(p,2)
	var ordinary_white := r.place(Vector2i(7,8))
	check(not ordinary_white.empowered and ordinary_white.skill=="" and r.round_winner==-2, "Player two's white ring has no effects or automatic win")
	r.pending_skill="moon";r.turn=2
	check(not r.resolve_moon().ok, "Moon resolver independently rejects the other player")
	r.reset_match()
	r.turn=2
	check(not r.can_charge() and not r.cosmos(Vector2i(1,1)).ok, "Second player has no ultimate")
	r.turn=1
	check(r.can_charge() and r.cosmos(Vector2i(7,7)).ok, "First black player can cast cosmos")
	check(r.board.count(1)==225 and r.round_winner==0 and r.wins[0]==1, "Cosmos fills board and wins once")
	check(not r.cosmos(Vector2i(0,0)).ok and not r.place(Vector2i(0,0)).ok and r.wins[0]==1, "Finished round is locked")
	# A five-round match with alternating winners, then a player-one final.
	r.reset_match()
	for victor in [0,1,0,1,0]:
		r._finish(victor,"normal")
		if r.match_winner<0: check(r.next_round(),"Next decisive round")
	check(r.wins==[3,2] and r.round_index==4 and r.match_winner==0, "Best of five ends at 3–2")
	check(not r.next_round(), "Cannot start a sixth round")
	r.reset_match()
	for n in 3:
		r._finish(1,"normal")
		if n<2: r.next_round()
	check(r.match_winner==1 and r.round_index==2, "Three straight wins end match early")
	r.reset_match()
	for y in 15:
		for x in 15: r.put(Vector2i(x,y), 1 if (x+2*y)%4<2 else 2)
	check(r.any_line(1).is_empty() and r.any_line(2).is_empty(),"Full board draw fixture has no five")
	var end := Vector2i(14,14)
	r.turn=r.at(end);r.put(end,0)
	check(r.place(end).ok and r.round_winner==-1, "Full board without five draws")
	check(r.next_round() and r.round_index==0 and r.wins==[0,0], "Draw repeats same colors and round")
	r.place(Vector2i(4,6))
	var restored := Rules.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(r.serialize()))) and restored.board==r.board and restored.turn==r.turn,"Save roundtrip")
	check(not restored.restore({"version":1,"board":[99],"wins":[0,0]}),"Invalid save rejected")
	feature_switches()
	print("RULE_TESTS: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)

func feature_switches() -> void:
	for effects in [false,true]:
		for skills in [false,true]:
			var r:=Rules.new()
			r.configure_features(effects,skills)
			r.round_index=2
			var move:=r.place(Vector2i(7,7))
			check(move.empowered==effects and move.storm==effects,"Visual switch controls late-round placement independently")
			check(not r.place(Vector2i(8,7)).empowered,"Visual switch never gives the other player powers")
			check(r.can_charge()==skills,"Skill switch controls charged gameplay independently")
			r.reset_match()
			check(r.effects_enabled==effects and r.skills_enabled==skills,"New matches retain global feature preferences")
			for p:Vector2i in [Vector2i(7,5),Vector2i(7,6),Vector2i(6,6)]:r.put(p,1)
			r.place(Vector2i(7,7))
			check(not r.shoot_bow(Vector2i(6,6),Vector2i.RIGHT).ok,"T still waits for White under both switches")
			r.place(Vector2i(0,0))
			check((r.pending_skill=="bow")==skills,"Disabled skills do not arm bows")
			check(r.shoot_bow(Vector2i(6,6),Vector2i.RIGHT).ok==skills,"Bow execution respects the skill switch")
			r.reset_match();r.round_index=1;r.turn=2
			for p:Vector2i in [Vector2i(7,7),Vector2i(8,7),Vector2i(7,8)]:r.put(p,2)
			r.place(Vector2i(8,8))
			check((r.pending_skill=="moon")==skills,"Disabled skills leave a white ring as ordinary stones")
			check(r.resolve_moon().ok==skills,"White conversion respects skills rather than visual settings")
			r.reset_match()
			check(r.cosmos(Vector2i(7,7)).ok==skills,"Board-filling skill has an independent execution guard")
	var r:=Rules.new()
	for p:Vector2i in [Vector2i(7,5),Vector2i(7,6),Vector2i(6,6)]:r.put(p,1)
	r.place(Vector2i(7,7));r.place(Vector2i(0,0))
	var before:=r.board.duplicate()
	r.configure_features(true,false)
	check(r.pending_skill=="" and r.turn==1 and r.board==before,"Disabling a ready bow preserves the board and current turn")
	r.configure_features(true,true)
	check(r.pending_skill=="bow" and r.shoot_bow(Vector2i(6,6),Vector2i.RIGHT).ok,"Re-enabling skills restores a valid bow after White's reply")
	r.reset_match();r.round_index=1;r.turn=2
	for p:Vector2i in [Vector2i(7,7),Vector2i(8,7),Vector2i(7,8)]:r.put(p,2)
	r.place(Vector2i(8,8))
	var save:=r.serialize()
	var loaded:=Rules.new()
	loaded.configure_features(false,false)
	check(loaded.restore(save) and loaded.pending_skill=="" and loaded.turn==1,"Loading a pending moon with skills off advances the already placed White move")
	check(loaded.board.count(2)==4 and loaded.active() and loaded.wins==[0,0],"Disabling a saved skill does not convert the board or award points")
	loaded.configure_features(false,true)
	check(loaded.pending_skill=="" and loaded.turn==1,"Re-enabling skills does not retroactively trigger an old white ring")
