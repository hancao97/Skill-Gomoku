class_name RainfallRules
extends RefCounted

const SIZE := 15
const EMPTY := 0
const BLACK := 1
const WHITE := 2
const AXES := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, -1)]
const NEIGHBORS := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
	Vector2i(1,1), Vector2i(1,-1), Vector2i(-1,1), Vector2i(-1,-1)]

var board: Array[int] = []
var wins: Array[int] = [0, 0]
var round_index := 0
var turn := BLACK
var round_winner := -2
var match_winner := -1
var finish_kind := ""
var last := Vector2i(-1, -1)
var move_count := 0
var history: Array = []
var winning_line: Array[Vector2i] = []
var pending_skill := ""
var bow_anchors: Array[Vector2i] = []
var moon_ring: Array[Vector2i] = []
var moon_center := Vector2.ZERO
var bow_used := false
var moon_used := false
var effects_enabled := true
var skills_enabled := true

func _init() -> void:
	reset_match()

func inside(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < SIZE and p.y < SIZE

func at(p: Vector2i) -> int:
	return board[p.y * SIZE + p.x] if inside(p) else -1

func put(p: Vector2i, color: int) -> void:
	board[p.y * SIZE + p.x] = color

func color_for(player: int) -> int:
	return BLACK if player == round_index % 2 else WHITE

func player_for(color: int) -> int:
	return round_index % 2 if color == BLACK else 1 - round_index % 2

func current_player() -> int:
	return player_for(turn)

func has_effects(color: int) -> bool:
	return effects_enabled and color in [BLACK,WHITE] and player_for(color) == 0

func has_storm(color: int) -> bool:
	return round_index >= 2 and has_effects(color)

func configure_features(effects: bool, skills: bool) -> void:
	var enabling_skills:=skills and not skills_enabled
	effects_enabled=effects
	skills_enabled=skills
	if not skills_enabled:
		var finish_white_move:=pending_skill=="moon" and active()
		pending_skill=""
		bow_anchors.clear()
		moon_ring.clear()
		# A saved pending white skill has already placed its stone. Disabling the
		# skill passes that completed move to Black instead of granting another turn.
		if finish_white_move:_advance_turn()
	elif enabling_skills and active() and turn==BLACK and current_player()==0 and not bow_used:
		bow_anchors=find_bow_anchors()
		pending_skill="bow" if not bow_anchors.is_empty() else ""

func active() -> bool:
	return round_winner == -2 and match_winner == -1

func reset_match() -> void:
	wins = [0, 0]
	round_index = 0
	match_winner = -1
	reset_board()

func reset_board() -> void:
	board.clear()
	board.resize(SIZE * SIZE)
	board.fill(EMPTY)
	turn = BLACK
	round_winner = -2
	finish_kind = ""
	move_count = 0
	history.clear()
	winning_line.clear()
	last = Vector2i(-1, -1)
	pending_skill = ""
	bow_anchors.clear()
	moon_ring.clear()
	bow_used = false
	moon_used = false

func place(p: Vector2i) -> Dictionary:
	if not active() or pending_skill == "moon":
		return {"ok": false, "reason": "此刻请先完成技法"}
	if not inside(p):
		return {"ok": false, "reason": ""}
	if at(p) != EMPTY:
		return {"ok": false, "reason": "此处已有棋子"}
	# Bow is a hidden alternative action; clicking an empty point still places normally.
	if pending_skill == "bow":
		pending_skill = ""
		bow_anchors.clear()
	var owner := current_player()
	var color := turn
	put(p, color)
	last = p
	move_count += 1
	history.append([p.x, p.y, color])
	winning_line = line_through(p, color)
	if not winning_line.is_empty():
		_finish(owner, "normal")
	elif not board.has(EMPTY):
		_finish(-1, "draw")
	elif skills_enabled and owner == 0 and color == WHITE and not moon_used:
		var ring := find_moon(p)
		if not ring.is_empty():
			moon_ring.assign(ring["ring"])
			moon_center = ring["center"]
			pending_skill = "moon"
		else:
			_advance_turn()
	else:
		_advance_turn()
	# A move that launches a skill uses that skill's presentation, not placement thunder.
	return {"ok": true, "color": color, "player": owner, "empowered": has_effects(color), "storm": has_storm(color) and pending_skill != "moon", "skill": pending_skill}

func _advance_turn() -> void:
	turn = 3 - turn
	bow_anchors.clear()
	# A black move only forms the bow. White gets a full move before it can fire.
	if skills_enabled and turn == BLACK and current_player() == 0 and not bow_used:
		bow_anchors = find_bow_anchors()
		if not bow_anchors.is_empty():
			pending_skill = "bow"

func bow_waiting() -> bool:
	return skills_enabled and active() and color_for(0) == BLACK and turn == WHITE and not find_bow_anchors().is_empty()

func line_through(p: Vector2i, color: int) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if at(p) != color:
		return empty
	for d: Vector2i in AXES:
		var start := p
		while at(start - d) == color:
			start -= d
		var line: Array[Vector2i] = []
		var q := start
		while at(q) == color:
			line.append(q)
			q += d
		if line.size() >= 5:
			return line
	return empty

func any_line(color: int) -> Array[Vector2i]:
	for y in SIZE:
		for x in SIZE:
			var line := line_through(Vector2i(x, y), color)
			if not line.is_empty():
				return line
	return []

func bow_shapes() -> Array[Dictionary]:
	var shapes: Array[Dictionary] = []
	for y in SIZE:
		for x in SIZE:
			var center := Vector2i(x,y)
			if at(center) != BLACK:
				continue
			for axis: Vector2i in [Vector2i(1,0),Vector2i(0,1)]:
				if at(center-axis) != BLACK or at(center+axis) != BLACK:
					continue
				var side := Vector2i(-axis.y,axis.x)
				for sign_value: int in [-1,1]:
					var anchor := center+side*sign_value
					if at(anchor) == BLACK:
						shapes.append({"anchor":anchor,"center":center,"direction":center-anchor,
							"ends":[center-axis,center+axis]})
	return shapes

func find_bow_anchors(_last_move: Vector2i = Vector2i(-1,-1)) -> Array[Vector2i]:
	var anchors: Array[Vector2i] = []
	for shape in bow_shapes():
		if not anchors.has(shape.anchor):
			anchors.append(shape.anchor)
	return anchors

func bow_directions(anchor: Vector2i) -> Array[Vector2i]:
	var directions: Array[Vector2i] = []
	for shape in bow_shapes():
		if shape.anchor == anchor and not directions.has(shape.direction):
			directions.append(shape.direction)
	return directions

func bow_frame(anchor: Vector2i, direction: Vector2i) -> Dictionary:
	for shape in bow_shapes():
		if shape.anchor == anchor and shape.direction == direction:
			return shape
	return {}

func find_moon(p: Vector2i) -> Dictionary:
	for dx in range(-1, 1):
		for dy in range(-1, 1):
			var a := p + Vector2i(dx, dy)
			var ring: Array[Vector2i] = [a, a+Vector2i(1,0), a+Vector2i(1,1), a+Vector2i(0,1)]
			if ring.all(func(q: Vector2i) -> bool: return at(q) == WHITE):
				return {"ring": ring, "center": Vector2(a) + Vector2(.5, .5)}
	for d: Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
		var c := p+d
		var ring: Array[Vector2i] = [c+Vector2i(0,-1),c+Vector2i(1,0),c+Vector2i(0,1),c+Vector2i(-1,0)]
		if ring.all(func(q: Vector2i) -> bool: return at(q) == WHITE):
			return {"ring": ring, "center": Vector2(c)}
	return {}

func skip_bow() -> bool:
	if pending_skill != "bow" or not active():
		return false
	pending_skill = ""
	bow_anchors.clear()
	# Declining the skill does not spend Black's move: Black can place normally.
	return true

func bow_path(anchor: Vector2i, direction: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if not NEIGHBORS.has(direction):
		return path
	var q := anchor + direction
	while inside(q):
		path.append(q)
		q += direction
	return path

func shoot_bow(anchor: Vector2i, direction: Vector2i) -> Dictionary:
	if not skills_enabled or not active() or current_player() != 0 or turn != BLACK or pending_skill != "bow" or bow_used or not bow_anchors.has(anchor):
		return {"ok": false}
	if not bow_directions(anchor).has(direction):
		return {"ok": false}
	var path := bow_path(anchor, direction)
	if path.is_empty():
		return {"ok": false}
	put(anchor, EMPTY)
	var changed: Array[Vector2i] = []
	for p: Vector2i in path:
		if at(p) != BLACK:
			put(p, BLACK)
			changed.append(p)
	bow_used = true
	pending_skill = ""
	bow_anchors.clear()
	winning_line = any_line(BLACK)
	_finish(0, "bow")
	return {"ok": true, "path": path, "changed": changed, "anchor": anchor}

func resolve_moon() -> Dictionary:
	if not skills_enabled or not active() or current_player() != 0 or turn != WHITE or pending_skill != "moon" or moon_used:
		return {"ok": false}
	var changed: Array[Vector2i] = []
	var area: Array[Vector2i] = []
	var center_cell := Vector2i(clampi(last.x,2,SIZE-3),clampi(last.y,2,SIZE-3))
	for y in range(center_cell.y-2,center_cell.y+3):
		for x in range(center_cell.x-2,center_cell.x+3):
			var p := Vector2i(x,y)
			area.append(p)
			if at(p) != WHITE:
				put(p, WHITE)
				changed.append(p)
	moon_used = true
	pending_skill = ""
	winning_line = any_line(WHITE)
	_finish(0, "moon")
	return {"ok": true, "changed": changed, "area": area, "center": moon_center, "ring": moon_ring.duplicate()}

func can_charge() -> bool:
	return skills_enabled and active() and pending_skill != "moon" and current_player() == 0 and turn == BLACK

func cosmos(p: Vector2i) -> Dictionary:
	if not can_charge() or not inside(p) or at(p) != EMPTY:
		return {"ok": false}
	board.fill(BLACK)
	last = p
	move_count += 1
	history.append([p.x, p.y, BLACK])
	winning_line = line_through(p, BLACK)
	_finish(0, "cosmos")
	return {"ok": true}

func _finish(player: int, kind: String) -> void:
	if round_winner != -2:
		return
	round_winner = player
	finish_kind = kind
	pending_skill = ""
	if player >= 0:
		wins[player] += 1
		if wins[player] >= 3:
			match_winner = player

func next_round() -> bool:
	if active() or match_winner >= 0:
		return false
	if round_winner >= 0:
		round_index += 1
	reset_board()
	return true

func serialize() -> Dictionary:
	return {"version": 2, "board": board, "wins": wins, "round": round_index,
		"turn": turn, "winner": round_winner, "match_winner": match_winner,
		"finish_kind": finish_kind, "last": [last.x,last.y], "move_count": move_count,
		"history": history, "bow_used": bow_used, "moon_used": moon_used,
		"pending": pending_skill}

func restore(data: Dictionary) -> bool:
	if int(data.get("version",0)) not in [1,2] or not data.get("board", null) is Array:
		return false
	var cells: Array = data["board"]
	var scores = data.get("wins", [])
	if cells.size() != 225 or not scores is Array or scores.size() != 2:
		return false
	for value in cells:
		if not (value is float or value is int) or value != int(value) or int(value) not in [0,1,2]:
			return false
	var index := int(data.get("round", -1))
	var next := int(data.get("turn", -1))
	if index < 0 or index > 4 or next not in [BLACK,WHITE]:
		return false
	for score in scores:
		if int(score) < 0 or int(score) > 3:
			return false
	board.assign(cells)
	wins.assign(scores)
	round_index = index
	turn = next
	round_winner = int(data.get("winner", -2))
	match_winner = int(data.get("match_winner", -1))
	finish_kind = str(data.get("finish_kind", ""))
	var last_data = data.get("last",[-1,-1])
	if not last_data is Array or last_data.size() != 2:
		reset_match()
		return false
	last = Vector2i(int(last_data[0]),int(last_data[1]))
	move_count = int(data.get("move_count",0))
	history = data.get("history",[]).duplicate()
	bow_used = bool(data.get("bow_used",false))
	moon_used = bool(data.get("moon_used",false))
	pending_skill = str(data.get("pending",""))
	bow_anchors.clear()
	moon_ring.clear()
	# Old builds offered the bow immediately after Black placed: resume at White's move.
	if int(data.version) == 1 and pending_skill == "bow":
		pending_skill = ""
		turn = WHITE
	if pending_skill == "bow":
		bow_anchors = find_bow_anchors()
		if bow_anchors.is_empty() or turn != BLACK or current_player() != 0:
			pending_skill = ""
	elif pending_skill == "moon":
		var ring := find_moon(last)
		if not ring.is_empty():
			moon_ring.assign(ring["ring"])
			moon_center = ring["center"]
		else:
			pending_skill = ""
	if int(data.version) == 1 and pending_skill == "" and active() and turn == BLACK and current_player() == 0 and not bow_used:
		bow_anchors = find_bow_anchors()
		if not bow_anchors.is_empty():
			pending_skill = "bow"
	if round_winner >= 0:
		winning_line = any_line(color_for(round_winner))
	configure_features(effects_enabled,skills_enabled)
	return true
