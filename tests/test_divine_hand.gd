extends SceneTree

const Rules=preload("res://scripts/rules.gd")
var checks:=0
var failures:Array[String]=[]

func check(value:bool, message:String) -> void:
	checks+=1
	if not value:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	var r:=Rules.new()
	for index in 5:
		for color in [1,2]:
			for effects in [false,true]:
				for skills in [false,true]:
					r.reset_match();r.round_index=index;r.turn=color
					r.configure_features(effects,skills)
					var eligible:bool=index==1 and color==2 and skills
					check(r.can_divine_hand()==eligible,"Ownership/round/turn/settings gate %s"%str([index,color,effects,skills]))
					check(r.divine_hand().ok==eligible,"Resolver independently enforces eligibility %s"%str([index,color,effects,skills]))
	r.reset_match();r.round_index=1;r.turn=2
	for y in 15:
		for x in 15:
			r.put(Vector2i(x,y),(x+2*y)%3)
	var before:=r.board.duplicate()
	var result:=r.divine_hand()
	var area:=Rules.divine_hand_cells()
	check(result.ok and area.size()>60 and area.has(Rules.HAND_TIP),"A large hand with a distinct pointing fingertip")
	var unique:Dictionary={}
	for p:Vector2i in area:unique[p]=true
	check(area.size()==unique.size(),"Hand footprint has no duplicate intersections")
	var all_inside:=true
	for p:Vector2i in area:all_inside=all_inside and r.inside(p) and r.at(p)==Rules.WHITE
	check(all_inside,"All hand intersections, including empty and black, become white")
	var outside_unchanged:=true
	for y in 15:
		for x in 15:
			var p:=Vector2i(x,y)
			if not area.has(p):outside_unchanged=outside_unchanged and r.at(p)==before[y*15+x]
	check(outside_unchanged,"All intersections outside the hand are preserved")
	check(r.round_winner==0 and r.wins==[1,0] and r.finish_kind=="divine_hand","Hand directly awards the permanent advantage player one win")
	check(not r.divine_hand().ok and r.wins==[1,0],"Repeated activation cannot score twice")
	var saved:=r.serialize()
	var restored:=Rules.new()
	check(restored.restore(saved) and restored.board==r.board and restored.divine_hand_used and not restored.can_divine_hand(),"Completed hand restores without replay or duplicate score")
	check(restored.next_round() and restored.round_index==2 and not restored.divine_hand_available(),"Third round has no spare white stone")
	r.reset_match();r.round_index=1;r.turn=2
	saved=r.serialize();saved.erase("divine_hand_used")
	check(restored.restore(saved) and restored.can_divine_hand(),"Existing version 2 saves gain the second-round hand without migration")
	r.pending_skill="moon"
	check(not r.divine_hand().ok,"An already committed moon cannot overlap the hand")
	r.pending_skill="";r.configure_features(true,false)
	check(not r.divine_hand_available(),"Skill toggle removes the hidden token")
	r.configure_features(false,true)
	check(r.divine_hand_available() and r.divine_hand().ok,"Effects-off still allows the same hand result")
	print("DIVINE HAND RULES: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
