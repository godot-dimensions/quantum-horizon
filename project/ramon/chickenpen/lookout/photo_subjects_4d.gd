extends Node

## Everything on the farm worth a photograph, and what each one is doing right now.
##
## ADAPTERS, NOT HOOKS. Nothing in the pen's own scripts changes for the camera. Each
## subject is a small dictionary - which node, which journal page, how big it is, how thick
## it is in W, and a function that reads its behaviour - and the behaviour is read by duck
## typing from the state the creature already keeps for itself: Nike's antics state, a
## crow's or a cat's mood, a chicken agent's state. So the pen can be moved, rebuilt or have
## a creature taken out, and the worst that happens is a subject that is never in frame.
##
## A SUBJECT:
##   id        unique ("nike", "chicken_3", ...)
##   page      the journal page it fills (field_journal_4d.gd PAGES)
##   name      what the toast calls it
##   node      the Node4D it follows
##   lift      metres from the node's origin up to the middle of the body
##   radius    roughly half its size, for how big it looks in frame
##   w_radius  half its thickness in W: off the slice by more than this, it is not there
##   behave    Callable(subject) -> [stars 1-4, what it is doing]
##
## The flock is not one of these: thousands of birds are judged as a crowd straight from
## the flock's own buffers (photo_judge_4d.gd). The hawk is (its position is the flock's).

const CHICKEN_STATES := ["idle", "wander", "alert", "evade", "carried", "thrown", "penned", "recovering",
	"to_coop", "nesting", "roosting"]

var lookout: Node
var room: Node
var _list: Array = []


func setup(owner_lookout: Node) -> void:
	lookout = owner_lookout
	room = lookout.get("room")


## Collected once the pen is up (its chickens are made in their manager's _ready).
func refresh() -> void:
	_list.clear()
	var world: Node = room.get_node("World")
	_add_node(world.get_node_or_null("Nike"), "nike", "nike", "Nike", 0.55, 0.62, 0.42, _behave_nike)
	var manager: Node = room.get_node_or_null("Chickens")
	if manager != null and manager.get("agents") is Array:
		var i: int = 0
		for agent in manager.get("agents"):
			if agent is Node4D:
				_add_node(agent, "chicken_%d" % i, "chickens", "A chicken", 0.28, 0.3, 0.3, _behave_chicken)
				i += 1
	var crows: int = 0
	for crow_name in ["Crow", "Crow2", "Crow3"]:
		var crow := world.get_node_or_null(crow_name) as Node4D
		if crow != null:
			_add_node(crow, "crow_%d" % crows, "crows", "A crow", 0.2, 0.3, 0.22, _behave_crow)
			crows += 1
	# The cats and the people are in units of their own since 6 Oct (World/RockPileSpot/Cat,
	# World/TrymCabin/Trym and so on), so they are found by name anywhere under World.
	_add_node(world.find_child("Cat", true, false), "cat", "cats", "The grey cat", 0.25, 0.32, 0.26, _behave_cat)
	_add_node(world.find_child("RedCat", true, false), "red_cat", "cats", "The red cat", 0.25, 0.32, 0.26, _behave_cat)
	for person in [["World/Keeper", "keeper", "The keeper"], ["World/Trym", "trym", "Trym"],
			["World/Professor", "professor", "The professor"], ["World/RangeMaster", "range_master", "The range master"],
			["Mithra", "mithra", "Mithra"]]:
		var who: Node = room.get_node_or_null(String(person[0]))
		if who == null and String(person[0]).begins_with("World/"):
			who = world.find_child(String(person[0]).get_file(), true, false)
		_add_node(who, String(person[1]), "folk", String(person[2]), 0.85, 0.85, 0.24, _behave_person)
	var flock := world.get_node_or_null("Flock") as Node4D
	if flock != null:
		_list.append({"id": "hawk", "page": "hawk", "name": "The hawk", "node": flock, "lift": 0.0,
			"radius": 0.55, "w_radius": 0.5, "behave": _behave_hawk, "point": _hawk_point})


## For the creatures this subgame adds itself - the owl, the heron, Wren.
func add(subject: Dictionary) -> void:
	for s in _list:
		if s["id"] == subject["id"]:
			_list.erase(s)
			break
	_list.append(subject)


func all() -> Array:
	return _list


func _add_node(node: Node, id: String, page: String, label: String, lift: float, radius: float, w_radius: float,
		behave: Callable) -> void:
	if not (node is Node4D):
		return
	_list.append({"id": id, "page": page, "name": label, "node": node, "lift": lift, "radius": radius,
		"w_radius": w_radius, "behave": behave})


## Where a subject's middle is now, or null if it is nowhere (the hawk while it is away).
func point(subject: Dictionary) -> Variant:
	if subject.has("point"):
		return (subject["point"] as Callable).call(subject)
	var node := subject["node"] as Node4D
	if not is_instance_valid(node) or not node.is_visible_in_tree():
		return null
	return node.global_position + Vector4(0.0, float(subject["lift"]), 0.0, 0.0)


## [stars, what it is doing].
func behaviour(subject: Dictionary) -> Array:
	return (subject["behave"] as Callable).call(subject)


# --- Reading what they are doing --------------------------------------------------------------

func _behave_nike(s: Dictionary) -> Array:
	var antics: Node = (s["node"] as Node).get_node_or_null("Antics")
	var state: int = int(antics.get("state")) if antics != null and antics.get("state") != null else 0
	match state:
		1:
			return [2, "Nose in the dirt"]
		2, 3, 4:
			return [3, "Flat out"]
		5:
			return [4, "A pig in the air"]
	return [1, "Out for a walk"]


func _behave_chicken(s: Dictionary) -> Array:
	var node := s["node"] as Node4D
	var state: int = int(node.get("state")) if node.get("state") != null else 0
	if absf(node.global_position.w) >= 1.2 or state == 5:
		return [4, "Out along W" if state != 5 else "A chicken in the air"]
	match state:
		2, 3, 4, 7:
			return [2, "On the run"]
		8, 9, 10:
			return [3, "Home to roost"]
	return [1, "Scratching about"]


func _behave_crow(s: Dictionary) -> Array:
	var mood: int = int((s["node"] as Node).get("_mood")) if (s["node"] as Node).get("_mood") != null else 0
	match mood:
		2:
			return [2, "On the wing"]
		1, 3:
			return [3, "Wings wide"]
	return [1, "On the fence"]


func _behave_cat(s: Dictionary) -> Array:
	var mood: int = int((s["node"] as Node).get("_mood")) if (s["node"] as Node).get("_mood") != null else 0
	match mood:
		3:
			return [2, "Sitting pretty"]
		2, 4, 6:
			return [3, "A cat mid-leap"]
	return [1, "On the prowl"]


func _behave_person(_s: Dictionary) -> Array:
	return [1, "Farm folk"]


func _behave_hawk(_s: Dictionary) -> Array:
	var flock: Node = room.get_node_or_null("World/Flock")
	var state: String = String(flock.call("stats").get("hawk", "away")) if flock != null else "away"
	if state == "diving":
		return [2, "The stoop"]
	return [1, "A hawk over the field"]


func _hawk_point(s: Dictionary) -> Variant:
	var flock := s["node"] as Node4D
	if not is_instance_valid(flock) or not flock.is_visible_in_tree():
		return null
	var p: Variant = flock.call("hawk_position")
	if p == null:
		return null
	return flock.global_basis * (p as Vector4) + flock.global_position


# --- For the viewfinder ------------------------------------------------------------------------

## Every subject in front of [param camera] and inside its frame (W aside), with its W
## offset from [param home] along [param normal] - where the focus ring would find it.
## Each: {subject, w, screen (0-1), depth}.
func in_view(camera: Camera4D, home: Vector4, normal: Vector4, w_reach: float) -> Array:
	var out: Array = []
	if camera == null:
		return out
	var basis: Projection = camera.global_basis
	var eye: Vector4 = camera.global_position
	var t: float = tan(vertical_fov(camera) * 0.5)
	var size := Vector2(camera.get_viewport().get_visible_rect().size)
	var aspect: float = size.x / maxf(size.y, 1.0)
	for s in _list:
		var p: Variant = point(s)
		if p == null:
			continue
		var rel: Vector4 = (p as Vector4) - eye
		var depth: float = -rel.dot(basis.z)
		if depth < 0.5:
			continue
		var sx: float = rel.dot(basis.x) / (depth * t * aspect)
		var sy: float = rel.dot(basis.y) / (depth * t)
		if absf(sx) > 1.05 or absf(sy) > 1.05:
			continue
		var w: float = ((p as Vector4) - home).dot(normal)
		if absf(w) > w_reach + float(s["w_radius"]):
			continue
		out.append({"subject": s, "w": w, "screen": Vector2(sx, sy), "depth": depth})
	return out


## The subject nearest the middle of the frame, for autofocus: {subject, w} or empty.
func nearest_to_centre(camera: Camera4D, home: Vector4, normal: Vector4, w_reach: float) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = 0.45
	for v in in_view(camera, home, normal, w_reach):
		var d: float = (v["screen"] as Vector2).length()
		if d < best_d:
			best_d = d
			best = v
	return best


## The vertical angle the picture is actually drawn at: the 4D field of view under the
## default PERSPECTIVE_4D projection, the 3D one under PERSPECTIVE_3D.
static func vertical_fov(camera: Camera4D) -> float:
	if int(camera.get("projection_type")) == 1:
		return float(camera.get("field_of_view_4d"))
	return float(camera.get("field_of_view_3d"))
