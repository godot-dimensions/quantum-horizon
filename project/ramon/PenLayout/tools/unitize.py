"""Splits units out of the pen scene into scenes of their own, instanced back in place.

Text-level and exact: each unit's node blocks, and every resource they use, go into
chickenpen/units/<folder>/<file>.tscn under one root at the unit's anchor; the pen keeps one
instance line in their place. Positions become local to the unit's root (the roots are not turned,
so bases stay as they are), and every NodePath stored in either file is recomputed so it still
points at the same node in the assembled tree. Nothing else in the files changes, so the diff is
the move and nothing more (Godot's own headless save rewrote 3,000 lines of the pen for a
10-line change).

    python unitize.py [--dry-run] <unit key> [<unit key> ...]

Units are defined in UNITS below. Run the check runner (_verify_units_runner.gd) after.
"""
import os
import re
import sys

PROJECT = "D:/depot/quantum-horizon/project/"
SCENE = PROJECT + "ramon/chickenpen/playable_world.tscn"

# key: (root name, unit file (res://), anchor node (its position becomes the root's), World children)
UNITS = {
	"cabin": ("TrymCabin", "res://ramon/chickenpen/units/trym_cabin/trym_cabin.tscn", "Shed",
		["Shed", "Trym", "TrymHead", "TrymStand", "TrymLaptopUse", "TrymDoor", "RedCat"]),
	"keeper": ("KeeperPost", "res://ramon/chickenpen/units/keeper/keeper.tscn", "Keeper",
		# Not TalkCam: it is every conversation's camera (pen_npc_talk_4d.gd), "not parented to anything that moves".
		["Keeper", "KeeperHead", "KeeperFacing"]),
	"range": ("Range", "res://ramon/chickenpen/units/range/range.tscn", "RangeBooth",
		["RangeBooth", "RangeMaster", "RangeMasterHead", "RangeMasterFacing"]),
	"professor": ("ProfessorPost", "res://ramon/chickenpen/units/professor/professor.tscn", "Professor",
		["Professor", "ProfessorHead", "ProfessorFacing"]),
	# The Lookout's site already is the unit's root: it becomes the scene, keeping its name.
	"lookout": ("LookoutSite", "res://ramon/chickenpen/units/lookout/lookout.tscn", None, ["LookoutSite"]),
	"rockpile": ("RockPileSpot", "res://ramon/chickenpen/units/rock_pile/rock_pile.tscn", "RockPile",
		["RockPile", "Cat"]),
	# The cave hill's mesh is baked in world space at the origin: the unit's root stands at the hill
	# (HILL in pen_cave_hill_4d.gd), and the mesh node sits at minus that inside it.
	"cave": ("Cave", "res://ramon/chickenpen/units/cave/cave.tscn", (17.0, 0.0, -40.0, 0.0), ["CaveHill"]),
}

# Resources a unit shares with what stays in the pen go into files of their own that both use, so
# they stay one resource (the cave's tint texture is also the hills'). Shared root id -> file.
SHARED = {
	"ImageTexture3D_umeec": "res://ramon/chickenpen/terrain/terrain_tint_3d.tres",
}


def res_to_path(res):
	return PROJECT + res[len("res://"):]


class Scene:
	def __init__(self, text):
		self.text = text
		first, _, rest = text.partition("\n")
		self.header = first
		# Split into top-level blocks, each starting with "[".
		blocks = re.split(r"\n(?=\[(?:ext_resource|sub_resource|node|connection|editable|resource) )", rest)
		self.ext, self.sub, self.nodes, self.other = [], [], [], []
		for b in blocks:
			if not b.strip():
				continue
			if b.startswith("[ext_resource"):
				self.ext.append(b)
			elif b.startswith("[sub_resource"):
				self.sub.append(b)
			elif b.startswith("[node"):
				self.nodes.append(b)
			else:
				self.other.append(b)

	@staticmethod
	def node_head(b):
		return b.split("\n", 1)[0]

	@staticmethod
	def attr(head, key):
		m = re.search(r'\b%s="([^"]*)"' % key, head)
		return m.group(1) if m else None

	def node_path(self, b):
		head = self.node_head(b)
		name = self.attr(head, "name")
		parent = self.attr(head, "parent")
		if parent is None:
			return ""
		return name if parent == "." else parent + "/" + name


def norm(parts):
	out = []
	for p in parts:
		if p in ("", "."):
			continue
		if p == "..":
			if out:
				out.pop()
			else:
				return None
		else:
			out.append(p)
	return "/".join(out)


def relpath(target, holder):
	t = target.split("/") if target else []
	h = holder.split("/") if holder else []
	i = 0
	while i < len(t) and i < len(h) and t[i] == h[i]:
		i += 1
	up = [".."] * (len(h) - i)
	return "/".join(up + t[i:]) or "."


def resolve(holder, p):
	"""The absolute (scene-root-relative) path a NodePath in `holder` points at."""
	path, sep, sub = p.partition(":")
	if path == "" or path == ".":
		base = holder
	else:
		base = norm((holder.split("/") if holder else []) + path.split("/"))
	return base, (sep + sub)


def vec4(s):
	return [float(x) for x in s.split(",")]


def fmt(v):
	out = []
	for x in v:
		x = round(x, 6)
		out.append(str(int(x)) if x == int(x) else repr(x))
	return ", ".join(out)


def refs(block):
	return set(re.findall(r'SubResource\("([^"]+)"\)', block)), set(re.findall(r'ExtResource\("([^"]+)"\)', block))


def sub_id(b):
	return Scene.attr(b.split("\n", 1)[0], "id")


def unitize(scene_text, key, dry):
	root_name, unit_res, anchor, members = UNITS[key]
	sc = Scene(scene_text)
	paths = [sc.node_path(b) for b in sc.nodes]
	# Which nodes move: the members (World children) and everything under them.
	moving = set()
	for m in members:
		top = "World/" + m
		assert top in paths, "no node %s" % top
		for p in paths:
			if p == top or p.startswith(top + "/"):
				moving.add(p)
	keep_root = (members == [root_name])   # the member is the root itself (the Lookout's site)
	# Where the root stands.
	if keep_root:
		root_pos = None
	elif isinstance(anchor, tuple):
		root_pos = list(anchor)
	else:
		b = sc.nodes[paths.index("World/" + anchor)]
		m = re.search(r'^position = Vector4\(([^)]*)\)', b, re.M)
		root_pos = vec4(m.group(1)) if m else [0.0, 0.0, 0.0, 0.0]
	unit_top = "World/" + root_name

	def new_path(p):
		"""Where a node of the pen ends up in the assembled tree."""
		if keep_root:
			return p
		for m in members:
			top = "World/" + m
			if p == top or p.startswith(top + "/"):
				return unit_top + "/" + p[len("World/"):]
		return p

	def fix_paths(block, holder_old):
		holder_new = new_path(holder_old)

		def rep(mm):
			val = mm.group(1)
			if val == "":
				return mm.group(0)    # an empty path is unset, not "self"
			target, sub = resolve(holder_old, val)
			if target is None:
				return mm.group(0)
			if new_path(target) == target and holder_new == holder_old:
				return mm.group(0)    # nothing moved: leave the text exactly as it was
			nv = relpath(new_path(target), holder_new) + sub
			return 'NodePath("%s")' % (nv if nv != "." else ".")
		head, _, body = block.partition("\n")
		return head + "\n" + re.sub(r'NodePath\("([^"]*)"\)', rep, body) if body else block

	changes = []
	# The pen: every node that stays gets its paths recomputed; the moving ones leave.
	kept_nodes, moved_nodes = [], []
	first_moved_at = None
	for i, b in enumerate(sc.nodes):
		p = paths[i]
		if p in moving:
			moved_nodes.append((p, b))
			if first_moved_at is None:
				first_moved_at = len(kept_nodes)
			continue
		nb = fix_paths(b, p)
		if nb != b:
			changes.append(p)
		kept_nodes.append(nb)
	# The unit's own blocks: parents re-rooted, positions made local, paths recomputed.
	unit_nodes = []
	if not keep_root:
		unit_nodes.append('[node name="%s" type="Node4D"]\n' % root_name)
	for p, b in moved_nodes:
		b = fix_paths(b, p)
		head, _, body = b.partition("\n")
		name = Scene.attr(head, "name")
		parent = Scene.attr(head, "parent")
		if keep_root:
			if p == unit_top:
				head = re.sub(r' parent="[^"]*"', "", head)
				body = re.sub(r'^position = Vector4\([^)]*\)\n?', "", body, flags=re.M)
			else:
				np_ = parent[len(unit_top) + 1:] if parent != unit_top else "."
				head = head.replace('parent="%s"' % parent, 'parent="%s"' % np_)
		else:
			new_parent = new_path(parent) if parent != "World" else unit_top
			rel_parent = "." if new_parent == unit_top else new_parent[len(unit_top) + 1:]
			head = head.replace('parent="%s"' % parent, 'parent="%s"' % rel_parent)
			if parent == "World":
				m = re.search(r'^position = Vector4\(([^)]*)\)', body, re.M)
				pos = vec4(m.group(1)) if m else [0.0, 0.0, 0.0, 0.0]
				local = [pos[k] - root_pos[k] for k in range(4)]
				line = "position = Vector4(%s)" % fmt(local)
				if m:
					body = body.replace(m.group(0), line, 1)
				elif any(abs(x) > 1e-9 for x in local):
					# No position line: it stood at the origin. Godot writes position first.
					body = line + "\n" + body
		unit_nodes.append(head + "\n" + body)
	# Resources: what the unit's blocks use, followed through sub-resources.
	sub_by_id = {sub_id(b): b for b in sc.sub}
	ext_by_id = {Scene.attr(b.split("\n", 1)[0], "id"): b for b in sc.ext}

	def closure(blocks):
		subs, exts = set(), set()
		todo = list(blocks)
		while todo:
			s, e = refs(todo.pop())
			exts |= e
			for x in s - subs:
				subs.add(x)
				todo.append(sub_by_id[x])
		return subs, exts
	u_subs, u_exts = closure(unit_nodes)
	k_subs, k_exts = closure(kept_nodes + sc.other)
	# Shared with what stays: each shared root goes to its own file, used by both.
	shared = u_subs & k_subs
	shared_roots = [x for x in shared if not any(x in refs(sub_by_id[y])[0] for y in shared if y != x)]
	shared_ext = []
	for r in shared_roots:
		assert r in SHARED, "%s is shared with the pen: give it a file in SHARED" % r
		deps, _ = closure([sub_by_id[r]])
		deps.discard(r)
		rb = sub_by_id[r]
		rtype = Scene.attr(rb.split("\n", 1)[0], "type")
		tres = "[gd_resource type=\"%s\" load_steps=%d format=4]\n\n" % (rtype, len(deps) + 1)
		for b in sc.sub:
			if sub_id(b) in deps:
				tres += b.rstrip("\n") + "\n\n"
		tres += "[resource]\n" + rb.split("\n", 1)[1].rstrip("\n") + "\n"
		if not dry:
			out = res_to_path(SHARED[r])
			if os.path.exists(out):
				assert open(out, encoding="utf-8").read() == tres, "%s exists and differs" % out
			else:
				os.makedirs(os.path.dirname(out), exist_ok=True)
				open(out, "w", encoding="utf-8", newline="\n").write(tres)
		eid = "shared_" + r
		shared_ext.append('[ext_resource type="%s" path="%s" id="%s"]' % (rtype, SHARED[r], eid))
		swap = lambda t, r=r, eid=eid: t.replace('SubResource("%s")' % r, 'ExtResource("%s")' % eid)
		unit_nodes = [swap(b) for b in unit_nodes]
		kept_nodes = [swap(b) for b in kept_nodes]
		sc.sub = [swap(b) for b in sc.sub if sub_id(b) != r and sub_id(b) not in deps]
		sub_by_id = {sub_id(b): b for b in sc.sub}
		print("   shared with the pen: %s (%d parts) -> %s" % (r, len(deps) + 1, SHARED[r]))
	if shared_roots:
		u_subs, u_exts = closure(unit_nodes)
	# The unit's file.
	unit_sub_blocks = [b for b in sc.sub if sub_id(b) in u_subs]
	unit_ext_blocks = [b for b in sc.ext if Scene.attr(b.split("\n", 1)[0], "id") in u_exts]
	unit_ext_blocks += [l for l in shared_ext if Scene.attr(l, "id") in u_exts]
	steps = len(unit_sub_blocks) + len(unit_ext_blocks) + 1
	unit_text = "[gd_scene load_steps=%d format=4]\n\n" % steps
	if unit_ext_blocks:
		unit_text += "\n".join(b.rstrip("\n") for b in unit_ext_blocks) + "\n\n"
	for b in unit_sub_blocks:
		unit_text += b.rstrip("\n") + "\n\n"
	unit_text += "\n\n".join(b.rstrip("\n") for b in unit_nodes) + "\n"
	# The pen: the instance in the first moved node's place, resources it no longer uses dropped.
	ext_id = "unit_" + key
	inst = '[node name="%s" parent="World" instance=ExtResource("%s")]\n' % (root_name, ext_id)
	if keep_root:
		m = re.search(r'^position = Vector4\(([^)]*)\)', moved_nodes[0][1], re.M)
		inst += "position = Vector4(%s)\n" % m.group(1) if m else ""
	elif any(abs(x) > 1e-9 for x in root_pos):
		inst += "position = Vector4(%s)\n" % fmt(root_pos)
	kept_nodes.insert(first_moved_at, inst)
	k_subs, k_exts = closure(kept_nodes + sc.other)
	pen_sub = [b for b in sc.sub if sub_id(b) in k_subs]
	pen_ext = [b for b in sc.ext if Scene.attr(b.split("\n", 1)[0], "id") in k_exts and Scene.attr(b.split("\n", 1)[0], "id") != ext_id]
	pen_ext += [l for l in shared_ext if Scene.attr(l, "id") in k_exts]
	pen_ext.append('[ext_resource type="PackedScene" path="%s" id="%s"]' % (unit_res, ext_id))
	header = re.sub(r"load_steps=\d+", "load_steps=%d" % (len(pen_sub) + len(pen_ext) + 1), sc.header)
	pen_text = header + "\n\n" + "\n".join(b.rstrip("\n") for b in pen_ext) + "\n\n"
	for b in pen_sub:
		pen_text += b.rstrip("\n") + "\n\n"
	pen_text += "\n\n".join(b.rstrip("\n") for b in kept_nodes)
	for b in sc.other:
		pen_text += "\n\n" + b.rstrip("\n")
	pen_text += "\n"
	print("%s: %d nodes into %s (root at %s), %d sub-resources and %d external files with it" % (
		key, len(moved_nodes), unit_res, "its own place" if keep_root else fmt(root_pos), len(unit_sub_blocks), len(unit_ext_blocks)))
	print("   paths recomputed on %d nodes that stay: %s" % (len(changes), ", ".join(changes[:12]) + (" ..." if len(changes) > 12 else "")))
	print("   the pen drops %d sub-resources and %d external files it no longer uses" % (len(sc.sub) - len(pen_sub), len(sc.ext) + 1 - len(pen_ext)))
	if not dry:
		out = res_to_path(unit_res)
		os.makedirs(os.path.dirname(out), exist_ok=True)
		assert not os.path.exists(out), "%s exists" % out
		open(out, "w", encoding="utf-8", newline="\n").write(unit_text)
	return pen_text


def main():
	args = sys.argv[1:]
	dry = "--dry-run" in args
	keys = [a for a in args if not a.startswith("--")]
	text = open(SCENE, encoding="utf-8").read()
	for k in keys:
		text = unitize(text, k, dry)
	if not dry:
		open(SCENE, "w", encoding="utf-8", newline="\n").write(text)
		print("written")


if __name__ == "__main__":
	main()
