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
					var eligible:bool=index in [1,3] and color==2 and skills
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
	# A use in round two must not consume the hand in the next White round.
	r.reset_match();r.round_index=1;r.wins=[1,0];r.turn=Rules.WHITE
	check(r.divine_hand().ok and r.wins==[2,0],"Second-round hand can follow a first-round victory")
	check(r.next_round() and not r.divine_hand_available() and not r.divine_hand_used,"Black round clears the per-round use without showing a White token")
	for i in 5:
		r.place(Vector2i(i*2,14))
		r.place(Vector2i(i,0))
	check(r.round_winner==1 and r.wins==[2,1],"Opponent's ordinary third-round win keeps the match alive")
	check(r.next_round() and r.round_index==3 and r.divine_hand_available(),"Fourth round restores the spare white stone")
	check(not r.can_divine_hand() and not r.divine_hand().ok,"Fourth-round Black cannot use the advantage player's hand")
	r.place(Vector2i(14,14))
	check(r.can_divine_hand(),"Fourth-round White can activate after Black's move")
	saved=r.serialize()
	check(restored.restore(saved) and restored.can_divine_hand(),"Existing fourth-round saves immediately expose the White hand")
	saved.erase("divine_hand_used")
	check(restored.restore(saved) and restored.can_divine_hand(),"Older fourth-round saves without the optional use flag remain compatible")
	check(restored.divine_hand().ok and restored.wins==[3,1] and restored.match_winner==0,"Fourth-round hand can win the match after already being used in round two")
	check(area.all(func(p:Vector2i):return restored.at(p)==Rules.WHITE) and restored.at(Vector2i(14,14))==Rules.BLACK,"Fourth-round hand fills its footprint and preserves an outside opponent stone")
	check(not restored.divine_hand().ok and restored.wins==[3,1],"Fourth-round result cannot score twice")
	print("DIVINE HAND RULES: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
