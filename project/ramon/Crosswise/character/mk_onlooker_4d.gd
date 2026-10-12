extends Node4D
## Crosswise: the onlooker on the first island, who lives in lane 0 and sees only lane 0.
##
## Miegakure's "miracles" are things a 3D onlooker would notice: you vanish through a wall and appear
## on the other side, and its characters react (RESEARCH.md, lesson 6). This is that, small: a second
## little figure by the gate wall who turns to watch you while you share his world. Step out of it
## (turn into W and walk ana) and you have vanished: "?". Come back into his world on the far side
## of the wall and he sees you where you cannot have got to: "!". The bubble only shows while he is
## in your slice (the HUD asks `bubble()`).
##
## He is the pen's block avatar (this folder's copy) without the cap, in teal, standing.
##
## NO class_name (engine_gotchas.md).

const Avatar := preload("res://ramon/Crosswise/character/mk_avatar_4d.gd")

## The one he watches.
var watched: Node4D
## His world: how far along W something can be and still be in it.
var world_half_w: float = 0.6
## The wall's Z: past it is "the other side".
var wall_z: float = -0.6

var _avatar: Node4D
var _state: String = "watching"
var _wow_t: float = 0.0
var _facing: float = 0.0
var _seen_before: bool = false
var _t: float = 0.0


func _ready() -> void:
	_avatar = Node4D.new()
	_avatar.name = "Avatar"
	_avatar.set_script(Avatar)
	_avatar.set("wear_cap", false)
	_avatar.set("hair", Color(0.16, 0.12, 0.10))
	_avatar.set("skin", Color(0.30, 0.62, 0.64))
	_avatar.set("accent", Color(0.86, 0.70, 0.56))
	_avatar.set("shorts_length", 0.22)
	add_child(_avatar)
	# Someone you bump into, not walk through (his box is the walker's).
	var body := StaticBody4D.new()
	body.name = "Body"
	var shape := CollisionShape4D.new()
	var box := BoxShape4D.new()
	box.size = Vector4(0.5, 1.3, 0.5, 0.5)
	shape.shape = box
	shape.position = Vector4(0, 0.65, 0, 0)
	body.add_child(shape)
	add_child(body)


func _in_his_world(p: Vector4) -> bool:
	return absf(p.w - global_position.w) < world_half_w


func _process(delta: float) -> void:
	_t += delta
	if watched == null:
		return
	var p: Vector4 = watched.global_position
	var sees: bool = _in_his_world(p)
	match _state:
		"watching":
			if not sees and _seen_before:
				_state = "lost"
			if sees:
				_seen_before = true
		"lost":
			if sees:
				if p.z < wall_z:
					_state = "wow"
					_wow_t = 0.0
				else:
					_state = "watching"
		"wow":
			_wow_t += delta
			if _wow_t > 3.2:
				_state = "watching"
	# Turn to him while he can see him; look about when he is lost.
	var want: float = _facing
	if sees:
		var d: Vector4 = p - global_position
		want = atan2(d.x, d.z)
	elif _state == "lost":
		want = sin(_t * 0.9) * 1.2 + PI * 0.75
	_facing = rotate_toward(_facing, want, delta * 3.0)
	if _avatar != null:
		_avatar.basis = Basis4D.from_zx(_facing)
		var bob: float = sin(_t * 2.2) * 0.008
		if _state == "wow":
			bob += maxf(0.0, sin(minf(_wow_t, 0.5) * TAU)) * 0.12
		_avatar.position = Vector4(0, bob, 0, 0)


## The mark over his head for the HUD, or {} (only while he shares the viewer's slice: `normal` is
## the slice's normal, `at` the viewer's position).
func bubble(normal: Vector4, at: Vector4) -> Dictionary:
	if absf((global_position - at).dot(normal)) > 0.3:
		return {}
	var top: Vector4 = global_position + Vector4(0, 1.75, 0, 0)
	if _state == "lost":
		return {"at": top, "text": "?"}
	if _state == "wow":
		return {"at": top, "text": "!"}
	return {}
