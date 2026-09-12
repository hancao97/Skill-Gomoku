extends Node3D

signal landed
signal finished

var origin := Vector3.ZERO
var targets: Array[Node3D] = []
var bodies: Array[Dictionary] = []
var age := 0.0
var touched_down := false

func _ready() -> void:
	name="OpponentStoneRecoil"
	for stone in targets:
		var offset:=stone.global_position-origin
		var distance:=Vector2(offset.x,offset.z).length()
		bodies.append({"stone":weakref(stone),"rest":stone.transform,
			"delay":minf(distance*.018,.075),"height":clampf(.57-distance*.038,.27,.54),
			"tilt":Vector2(offset.z,-offset.x).normalized()})
	targets.clear()

func _process(delta:float) -> void:
	age+=delta
	for body in bodies:
		var stone=body.stone.get_ref()
		if not is_instance_valid(stone) or stone.is_queued_for_deletion():continue
		var t:=clampf((age-float(body.delay))/.33,0.0,1.0)
		var flight:=4.0*t*(1.0-t)
		var settle:=clampf((age-float(body.delay)-.33)/.09,0.0,1.0)
		stone.transform=body.rest
		stone.position.y+=float(body.height)*flight+sin(settle*PI)*.026
		stone.rotation.x+=body.tilt.x*sin(t*PI)*.17
		stone.rotation.z+=body.tilt.y*sin(t*PI)*.17
	if age>=.37 and not touched_down:
		touched_down=true
		landed.emit()
	if age>=.50:cancel()

func _restore() -> void:
	for body in bodies:
		var stone=body.stone.get_ref()
		if is_instance_valid(stone) and not stone.is_queued_for_deletion():stone.transform=body.rest

func cancel() -> void:
	if is_queued_for_deletion():return
	set_process(false)
	_restore()
	queue_free()
	finished.emit()

func _exit_tree() -> void:
	_restore()
