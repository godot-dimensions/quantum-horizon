"""Voxel Lab: writes voxel_lab.tscn (the rooms, stations, lights, spots, floating panels, signs) and the
two floor routes (paths/hall.tres, paths/gallery.tres) from the one layout below, so the rings, the
spots you act at and the lights never drift apart. Edit here and run it, rather than editing the scene:

    python project/ramon/VoxelLab/tools/make_scene.py

Godot must be closed, or the scene not open in it.

THE LAYOUT (Ramon's walkthroughs, 8 and 9 Oct; VoxelLab/PLAN_ROUND2.md and PLAN_ROUND3.md). The hall:
front wall z 12, back wall z -15 with the gallery door, side walls x -12 and 12, corner walls from
(+-12, -7) to (+-4.8, -15) carrying the two wall panels. The gallery behind it, 1 m further back since
round 3 (GZ): x -13 to 13, z -32.5 to -16.5, the field door in its far wall, a short passage between
the two doors (voxel_lab_4d.gd). Routes are straight, with right angles and the odd 45 degrees; big
rings (destinations) only where you act or look at a wall; small markers (bends, chords) at the shelf
and the ladder; quiet junctions where routes branch. From the pivot the arrows run both ways round the
hall to the back junction and the gallery door (round 3).
"""
from pathlib import Path
import math

ROOT = Path(__file__).resolve().parent.parent
out = []
ext = [
    ("1_root", "Script", "res://ramon/VoxelLab/voxel_lab_4d.gd"),
    ("2_room", "Script", "res://ramon/VoxelLab/carried/LabKit/lab_room_4d.gd"),
    ("3_kitroom", "Script", "res://ramon/VoxelLab/carried/kit/kit_room_4d.gd"),
    ("4_text", "Script", "res://ramon/VoxelLab/carried/kit/kit_wall_text_4d.gd"),
    ("5_showcase", "Script", "res://ramon/VoxelLab/carried/kit/kit_showcase_4d.gd"),
    ("6_block", "Script", "res://ramon/VoxelLab/stations/vl_block_exhibit_4d.gd"),
    ("7_bench", "Script", "res://ramon/VoxelLab/room/vl_bench_4d.gd"),
    ("9_shelf", "Script", "res://ramon/VoxelLab/stations/vl_shelf_exhibit_4d.gd"),
    ("10_light", "Script", "res://ramon/VoxelLab/carried/kit/kit_light_4d.gd"),
    ("11_sun", "Script", "res://ramon/VoxelLab/carried/kit/kit_sun_4d.gd"),
    ("12_build", "Script", "res://ramon/VoxelLab/stations/vl_build_exhibit_4d.gd"),
    ("13_panel", "Script", "res://ramon/VoxelLab/carried/kit/panels/kit_wall_panel_4d.gd"),
    ("14_pair", "Script", "res://ramon/VoxelLab/carried/kit/panels/kit_wall_panels_4d.gd"),
    ("15_source", "Script", "res://ramon/VoxelLab/room/vl_panel_source.gd"),
    ("16_info", "Resource", "res://ramon/VoxelLab/voxel_lab_info.tres"),
    ("17_case", "Script", "res://ramon/VoxelLab/stations/vl_case_exhibit_4d.gd"),
    ("18_net", "Script", "res://ramon/VoxelLab/carried/PathCreator/graph/path_network_4d.gd"),
    ("19_hall", "Resource", "res://ramon/VoxelLab/paths/hall.tres"),
    ("20_gallery", "Resource", "res://ramon/VoxelLab/paths/gallery.tres"),
    ("21_target", "Script", "res://ramon/VoxelLab/room/vl_target_4d.gd"),
    ("22_float", "Script", "res://ramon/VoxelLab/room/vl_float_panel_4d.gd"),
]
out.append('[gd_scene load_steps=%d format=3]\n' % (len(ext) + 1))
for id_, ty, path in ext:
    out.append('[ext_resource type="%s" path="%s" id="%s"]' % (ty, path, id_))
out.append('')


def node(name, parent=None, type_="Node4D", props=None):
    out.append('[node name="%s" type="%s"%s]' % (name, type_, '' if parent is None else ' parent="%s"' % parent))
    for k, v in (props or []):
        out.append('%s = %s' % (k, v))
    out.append('')


def V(x, y, z, w=0):
    return 'Vector4(%s, %s, %s, %s)' % (x, y, z, w)


def q(s):
    return '"%s"' % s


def arr(items):
    return '[%s]' % ', '.join(q(i) for i in items)


# -- the rooms ---------------------------------------------------------------------------------------

node("VoxelLab", None, "Node4D", [("script", 'ExtResource("1_root")'), ("room_half_width", "12.0"), ("room_back", "15.0"),
                                  ("corner_length", "10.8"), ("start_at", "Vector2(0, 21)")])
node("Room", ".", "Node4D", [("script", 'ExtResource("2_room")'), ("start_mood", q("bright"))])
node("Entrance", ".", "Node4D", [("position", V(0, 0, 19.5)), ("script", 'ExtResource("3_kitroom")'), ("size", "Vector3(8, 6.8, 14)"),
                                 ("open_sides", '["n"]'), ("cove", "false")])
node("Hall", ".", "Node4D", [("script", 'ExtResource("3_kitroom")'), ("size", "Vector3(24, 9, 27)"), ("cove", "false")])
node("Sign", "Hall", "Node", [("script", 'ExtResource("4_text")'), ("side", q("s")), ("edge", "5"), ("along", "Vector2(7.6, 16.4)"),
                              ("up", "Vector2(4.4, 5.9)"), ("outside", "true"), ("kind", q("sign")), ("title", q("VOXEL LAB")),
                              ("subtitle", q("QUANTUM HORIZON  ·  CUTTING 4D MATTER")), ("glow", "0.3")])
# The gallery, everything in it 1 m further back than round 2 (Ramon, 9 Oct: the rooms clipped).
GZ = -1.0
# Over the gallery door, on the hall's back wall (edge 2, from its left end: the door is centred 4.77 m
# along it), the open world door's sign (round 4: "an appropriate black text label at the entrance to
# the next room").
node("GallerySign", "Hall", "Node", [("script", 'ExtResource("4_text")'), ("edge", "2"), ("along", "Vector2(0.6, 8.94)"),
                                    ("up", "Vector2(4.5, 6.3)"), ("kind", q("sign")), ("title", q("HOW A WORLD IS MADE")),
                                    ("subtitle", q("OUR GENERATORS ONE AT A TIME, THEN THE WHOLE WORLD")), ("glow", "0.3")])
node("GalleryRoom", ".", "Node4D", [("position", V(0, 0, -23.5 + GZ)), ("script", 'ExtResource("3_kitroom")'), ("size", "Vector3(26, 8, 16)"),
                                    ("cove", "false")])
node("AboutWall", "GalleryRoom", "Node", [("script", 'ExtResource("4_text")'), ("side", q("w")), ("along", "Vector2(-6.6, 6.6)"),
                                          ("up", "Vector2(1.6, 6.6)"), ("kind", q("lesson")), ("number", "2"), ("title", q("The whole world")),
                                          ("subtitle", q("All three layers, and a sea, at full size")),
                                          ("body", q("Our generator stacks the land, the caves carved through it, and a sea filling everything below a plane, "
                                                     "cut out of a world with no edges. The noise is four-dimensional, so every slice through W is a new coastline. "
                                                     "Change its look, or cut it: the engine remeshes it as you go.")),
                                          ("code", q("blue")), ("glow", "0.2")])
node("FieldSign", "GalleryRoom", "Node", [("script", 'ExtResource("4_text")'), ("side", q("n")), ("along", "Vector2(-4.4, 4.4)"),
                                          ("up", "Vector2(4.6, 6.4)"), ("kind", q("sign")), ("title", q("THE OPEN WORLD")),
                                          ("subtitle", q("AN ISLAND OF OUR LANDSCAPE, IN THE OPEN SEA")), ("glow", "0.3")])
node("LayersWall", "GalleryRoom", "Node", [("script", 'ExtResource("4_text")'), ("side", q("e")), ("along", "Vector2(-6.6, 6.6)"),
                                           ("up", "Vector2(2.4, 6.6)"), ("kind", q("lesson")), ("number", "1"), ("title", q("How a world is made")),
                                           ("subtitle", q("One generator at a time")),
                                           ("body", q("The engine builds land from generators, each a rule for what fills a voxel. "
                                                      "First the land: fractal noise in bands of grass, dirt and stone. Then the caves: tunnels wherever three noise fields meet zero. "
                                                      "Clip one by the other and the land is hollowed. Stack a sea under it and you have the world behind you.")),
                                           ("code", q("blue")), ("glow", "0.2")])


# -- what stands in them ------------------------------------------------------------------------------

def station(name, x, z, script, radius, height=0.9, shape="round", band=90.0, meta=None, holo=True, band_print=True, stripes=True, holo_h=None, holo_base=None):
    props = [("position", V(x, 0, z)), ("script", 'ExtResource("5_showcase")'), ("exhibit_script", 'ExtResource("%s")' % script),
             ("radius", str(radius)), ("height", str(height)), ("pedestal_shape", q(shape)), ("bounds", "Rect2(-13, -32.5, 26, 45)"),
             ("band_angle", str(band))]
    if not holo:
        props.append(("hologram", "false"))
    if holo_h:
        props.append(("holo_height", str(holo_h)))
    if holo_base is not None:
        props.append(("holo_base", str(holo_base)))
    if not band_print:
        props.append(("band_print", "false"))
    if not stripes:
        props.append(("band_stripes", "false"))
    for k, v in (meta or []):
        props.append(("metadata/%s" % k, v))
    node(name, ".", "Node4D", props)


def bench(name, x, z, st, dist=4.6, pitch=-16.0, tools=None, bounds=None):
    props = [("position", V(x, 0, z)), ("script", 'ExtResource("7_bench")'), ("station", 'NodePath("../%s")' % st),
             ("pad", "false"), ("camera_distance", str(dist)), ("camera_pitch", str(pitch))]
    if tools:
        props.append(("tools", 'PackedStringArray(%s)' % ', '.join(q(t) for t in tools)))
    if bounds:
        props.append(("camera_bounds", "Rect2(%s, %s, %s, %s)" % bounds))
    node(name, ".", "Node4D", props)


def panel(name, x, z, st, number, title, kicker, face, width=1.3):
    node(name, ".", "Node4D", [("position", V(x, 0, z)), ("script", 'ExtResource("22_float")'), ("station", 'NodePath("../%s")' % st),
                               ("number", str(number)), ("title", q(title)), ("kicker", q(kicker)), ("face_point", "Vector2(%s, %s)" % face),
                               ("width", str(width)), ("depth", str(round(width * 0.38, 2)))])


# A, B and C near the wall behind them (round 3; 2.5 m out from it before), their markers on short
# branches off the shelf's run, which stays at x 6.2.
SHELF_X = 10.5
SHELF_RUN_X = 6.2
SHELF_SPOT_X = 8.5
SHELF_Z = [9.0, 5.4, 1.8]
for i, (kind, z) in enumerate(zip(["voxels", "inside", "hidden"], SHELF_Z)):
    station("Shelf%d" % (i + 1), SHELF_X, z, "9_shelf", 0.95, 1.0, "box", -90.0, [("shelf_kind", q(kind)), ("face_yaw", "-90.0")], False)
# A label on the right wall over each (round 3): edge 4 of the hall's outline runs up the right wall
# from where the corner wall meets it (z -15 + 10.8 cos 42) toward the entrance.
RIGHT_EDGE_Z0 = -15.0 + 10.8 * math.cos(math.radians(42.0))
LABELS = [("A", "Voxels", "What the world is made of: every voxel a tiny 4D cube.", "voxels"),
          ("B", "Inside", "Cut into ground and its layers show, all the way round.", "inside"),
          ("C", "Hidden in W", "Whole in your slice. Slide ana: a room appears.", "hidden")]
for (letter, title, line, diag), z in zip(LABELS, SHELF_Z):
    a0 = z - RIGHT_EDGE_Z0
    node("Label" + letter, "Hall", "Node", [("script", 'ExtResource("4_text")'), ("edge", "4"), ("along", "Vector2(%.2f, %.2f)" % (a0 - 0.85, a0 + 0.85)),
                                          ("up", "Vector2(2.05, 3.15)"), ("kind", q("label")), ("letter", q(letter)), ("title", q(title)),
                                          ("subtitle", q(line)), ("diagram", q(diag)), ("live", "true"), ("live_ppm", "400.0"), ("glow", "0.3")])
HERO = (0.0, -1.4)
HERO_RING = (0.0, 3.0)
station("Hero", HERO[0], HERO[1], "6_block", 2.8)
bench("HeroBench", HERO_RING[0], HERO_RING[1], "Hero", 5.2)
# Right beside its ring (round 5, #42: "position it directly beside the path circle"), on the left as you
# come down the spine to it.
panel("HeroPanel", -2.25, 3.3, "Hero", 1, "The block", "THE ENGINE'S VOXELS, CUT LIVE", HERO_RING)
# The second specimen in the front-left corner, the first thing on your left as you come in (round 3:
# "make better use of the currently unused space"), its ring on the left run. Round 4: Build it, in place
# of the column ("scrap the entire Watch It Fall concept"; "putting blocks in place to build something and
# then rotate the slice"): 4D bricks on a square plate, on a square pedestal a little bigger than the
# column's ("if the building part needs better a square pedestal go for it").
# Round 5 (#39: "noticeably larger ... closer to the wall, potentially all the way into the corner"): a
# 4.6 m square pedestal in the front-left corner (the hall runs to x -12 and z 12), a 3.5 m grid of 0.5 m
# bricks on it, its ring on the line from the pivot, the camera kept inside the walls. A metre off both
# walls, not 0.35 (Ramon, 9 Oct: "its crammed a bit too much in the corner").
COLUMN = (-8.7, 8.7)
COLUMN_RING = (-4.1, 8.8)
station("Build", COLUMN[0], COLUMN[1], "12_build", 2.3, 0.5, shape="box", holo=False)
bench("BuildBench", COLUMN_RING[0], COLUMN_RING[1], "Build", 6.0, -26.0, ["brick", "through", "take"], (-11.5, -12.0, 23.0, 23.5))
panel("BuildPanel", -3.0, 6.9, "Build", 2, "Build it", "BUILDING IN 4D", COLUMN_RING, 1.0)
# The world's square pedestal a little longer and wider (round 3: "more breathing room").
TERRAIN = (-6.2, -23.5 + GZ)
TERRAIN_RING = (0.0, -23.5 + GZ)
# Round 5: turned half round, its slope toward you as you come in (#43: "the sloped side of the terrain faces
# the wall rather than the approaching player"), and the hologram's gradient over it as the specimens have (#44).
station("Terrain", TERRAIN[0], TERRAIN[1], "17_case", 3.8, 0.45, "box", 90.0, [("case", q("terrain")), ("own_height", "true"), ("face_yaw", "180.0")],
        True, band_print=False, holo_h=1.5, holo_base=0.4)
bench("TerrainBench", TERRAIN_RING[0], TERRAIN_RING[1], "Terrain", 9.0, -24.0)
panel("TerrainPanel", -1.6, -19.2 + GZ, "Terrain", 3, "The world", "ADAPTED FROM ANDREW (4DENTHUSIAST)", TERRAIN_RING)
# His layers, one per small pedestal, in the order they combine (Ramon, 9 Oct: "rethink what you show").
RUNG_X = 9.6
RUNG_Z = [-20.0 + GZ, -23.5 + GZ, -27.0 + GZ]
LAYERS = ["land", "caves", "clipped"]
for i, z in enumerate(RUNG_Z):
    station("Layer%d" % (i + 1), RUNG_X, z, "17_case", 0.95, 1.0, "box", -90.0, [("case", q("layer")), ("layer", q(LAYERS[i])), ("face_yaw", "-90.0")], False,
            stripes=False)


# -- the lights: one soft spot on each item (vl_lights.gd sets them from the light file) ---------------------

node("Lights", ".", "Node4D")


def light(name, room, item, x, z, aim_y, group="", cone=None, strength_k=None):
    props = [("position", V(x, 8.0, z)), ("script", 'ExtResource("10_light")'), ("aim", "Vector3(%s, %s, %s)" % (x, aim_y, z)),
             ("angle", "34.0"), ("softness", "2.6"), ("reach", "14.0"), ("attenuation", "0.3"),
             ("energy", '{\n"bright": 2.4,\n"dark": 3.1\n}'), ("metadata/room", q(room)), ("metadata/item", q(item))]
    if group:
        props.append(("metadata/group", q(group)))
    if cone:
        props.append(("metadata/cone", str(cone)))
    if strength_k:
        props.append(("metadata/strength_k", str(strength_k)))
    node(name, "Lights", "Node4D", props)


light("Block", "hall", "the block", HERO[0], HERO[1], 2.1, cone=40.0)
for g, z in zip("ABC", SHELF_Z):
    light("Shelf" + g, "hall", "specimen " + g, SHELF_X, z, 1.4, g, cone=21.0)
light("Build", "hall", "the grid you build on", COLUMN[0], COLUMN[1], 1.6, cone=50.0)
light("Terrain", "gallery", "the world", TERRAIN[0], TERRAIN[1], 0.6, cone=70.0, strength_k=0.55)
for i, z in enumerate(RUNG_Z):
    light("Layer%d" % (i + 1), "gallery", "the %s" % ["land", "caves", "land and caves"][i], RUNG_X, z, 1.4, cone=21.0, strength_k=0.6)
node("Sun", ".", "Node4D", [("position", V(2, 9, 4)), ("script", 'ExtResource("11_sun")'), ("target", "Vector3(0, 0, -2)")])


# -- the wall panels -----------------------------------------------------------------------------------

node("PanelSource", ".", "Node", [("script", 'ExtResource("15_source")'), ("room", 'NodePath("..")'), ("hero", 'NodePath("../Hero")')])
node("IntroPanel", ".", "Node4D", [("script", 'ExtResource("13_panel")'), ("info", 'ExtResource("16_info")'),
                                   ("source", 'NodePath("../PanelSource")'), ("room_path", 'NodePath("../Hall")'), ("wall_name", q("left_corner"))])
node("ResearchBoard", ".", "Node4D", [("script", 'ExtResource("13_panel")'), ("kind", q("research")), ("info", 'ExtResource("16_info")'),
                                      ("source", 'NodePath("../PanelSource")'), ("room_path", 'NodePath("../Hall")'),
                                      ("wall_name", q("right_corner"))])
node("WallPanels", ".", "Node4D", [("script", 'ExtResource("14_pair")'), ("intro", 'NodePath("../IntroPanel")'),
                                   ("research", 'NodePath("../ResearchBoard")'), ("info", 'ExtResource("16_info")'),
                                   ("source", 'NodePath("../PanelSource")')])
node("FieldDoor", ".", "Node4D", [("position", V(0, 2.4, -31.7 + GZ))])


# -- where you act: the spots (the room reads their metadata) ---------------------------------------------
# kind: "choice" (options at a ring), "popup" (a click for a small frame), "view" (a wall to read).

RIGHT_WALL = (5.1, -8.0)
LEFT_WALL = (-5.1, -8.0)
node("Spots", ".", "Node4D")


def spot(name, at, kind, radius=1.3, station_=None, bench_=None, options=None, target=None):
    props = [("position", V(at[0], 0, at[1])), ("metadata/kind", q(kind)), ("metadata/radius", str(radius))]
    if station_:
        props.append(("metadata/station", 'NodePath("../../%s")' % station_))
    if bench_:
        props.append(("metadata/bench", 'NodePath("../../%s")' % bench_))
    if options:
        props.append(("metadata/options", arr(options)))
    if target:
        props.append(("metadata/target", q(target)))
    node(name, "Spots", "Node4D", props)


spot("Block", HERO_RING, "choice", 1.5, "Hero", "HeroBench", ["watch", "cut"], "Hero")
spot("Build", COLUMN_RING, "choice", 1.4, "Build", "BuildBench", ["build"], "Build")
for i, z in enumerate(SHELF_Z):
    spot("Shelf%s" % "ABC"[i], (SHELF_SPOT_X, z), "popup", 1.1, "Shelf%d" % (i + 1))
spot("RightWall", RIGHT_WALL, "view", 1.6, target="RightWallTarget")
spot("LeftWall", LEFT_WALL, "view", 1.6, target="LeftWallTarget")
spot("Terrain", TERRAIN_RING, "choice", 1.5, "Terrain", "TerrainBench", ["cut", "biome"], "Terrain")
for i, z in enumerate(RUNG_Z):
    spot("Layer%d" % (i + 1), (7.2, z), "popup", 1.1, "Layer%d" % (i + 1))


# -- the routes: targets in the scene, graphs written beside it ------------------------------------------

node("Paths", ".", "Node4D")
node("Targets", "Paths", "Node4D")
for nm, x, z, size, label in [("Hero", HERO[0], HERO[1], "Vector3(5.6, 1, 5.6)", "The block"),
                              ("Build", COLUMN[0], COLUMN[1], "Vector3(4.8, 1, 4.8)", "Build it"),
                              ("RightWallTarget", 8.4, -11.0, "Vector3(1, 1, 1)", "The block's wall"),
                              ("LeftWallTarget", -8.4, -11.0, "Vector3(1, 1, 1)", "Voxel Lab wall"),
                              ("GalleryDoor", 0, -15.0, "Vector3(3, 4.2, 0.6)", "Gallery door"),
                              ("Terrain", TERRAIN[0], TERRAIN[1], "Vector3(7.6, 1, 7.6)", "The world"),
                              ("FieldDoorTarget", 0, -31.7 + GZ, "Vector3(3.2, 4.2, 0.6)", "Field door")]:
    node(nm, "Paths/Targets", "Node4D", [("position", V(x, 0, z)), ("script", 'ExtResource("21_target")'), ("label", q(label)), ("size", size)])
# The rings' outlines in the routes' blue (round 3: "change the UI lines surrounding the large central
# pedestal to blue"), every one of them, so no ring reads as the odd one out.
FRAME_TINT = "Color(0.09, 0.38, 0.843, 1)"
node("Hall", "Paths", "Node4D", [("script", 'ExtResource("18_net")'), ("graph", 'ExtResource("19_hall")'), ("targets", 'NodePath("../Targets")'),
                                ("under_color", "Color(0.64, 0.65, 0.66, 1)"), ("frame_tint", FRAME_TINT)])
node("Gallery", "Paths", "Node4D", [("script", 'ExtResource("18_net")'), ("graph", 'ExtResource("20_gallery")'), ("targets", 'NodePath("../Targets")'),
                                   ("under_color", "Color(0.64, 0.65, 0.66, 1)"), ("frame_tint", FRAME_TINT)])
txt = '\n'.join(out).rstrip() + '\n'
(ROOT / 'voxel_lab.tscn').open('w', encoding='utf8', newline='\n').write(txt)
print('scene nodes:', txt.count('[node '))


# -- the route graphs (path_graph.gd's data, written as the resource Godot reads) -------------------------

class Graph:
    def __init__(self):
        self.nodes = []
        self.edges = []

    def add(self, kind, at, target="", frame="none", approach=(0.0, 1.0), state="arrival"):
        nid = len(self.nodes) + 1
        self.nodes.append({"approach": approach, "band": 8.0, "frame": frame, "id": nid, "kind": kind,
                           "pos": (at[0], at[1]), "state": state, "target": target})
        return nid

    def link(self, *ids):
        for a, b in zip(ids, ids[1:]):
            self.edges.append({"band": 8.0, "from": a, "priority": "primary", "to": b, "w_mode": "static"})

    def write(self, path):
        def f(x):
            return ('%.4f' % x).rstrip('0').rstrip('.') if '.' in ('%.4f' % x) else '%d' % x
        ns = []
        for n in self.nodes:
            ns.append('{\n"approach": Vector2(%s, %s),\n"band": 8.0,\n"frame": "%s",\n"id": %d,\n"kind": "%s",\n"pos": Vector4(%s, 0, %s, 0),\n"state": "%s",\n"target": "%s"\n}'
                      % (f(n["approach"][0]), f(n["approach"][1]), n["frame"], n["id"], n["kind"], f(n["pos"][0]), f(n["pos"][1]), n["state"], n["target"]))
        es = []
        for e in self.edges:
            es.append('{\n"band": 8.0,\n"from": %d,\n"priority": "primary",\n"to": %d,\n"w_mode": "static"\n}' % (e["from"], e["to"]))
        text = ('[gd_resource type="Resource" load_steps=2 format=3]\n\n'
                '[ext_resource type="Script" path="res://ramon/VoxelLab/carried/PathCreator/graph/path_graph.gd" id="1_graph"]\n\n'
                '[resource]\nscript = ExtResource("1_graph")\nnodes = [%s]\nedges = [%s]\nnext_id = %d\n'
                % (', '.join(ns), ', '.join(es), len(self.nodes) + 1))
        path.open('w', encoding='utf8', newline='\n').write(text)
        print('graph', path.name, len(self.nodes), 'nodes', len(self.edges), 'edges')


def unit(dx, dz):
    d = math.hypot(dx, dz)
    return (round(dx / d, 4), round(dz / d, 4))


# The hall. Destinations go in the order of the visit (the room lights the next one).
h = Graph()
start = h.add("start", (0.0, 21.0))
pivot = h.add("junction", (0.0, SHELF_Z[0]))
block = h.add("destination", HERO_RING, "Hero", "round", (0.0, 1.0), "available")
a = h.add("bend", (SHELF_RUN_X, SHELF_Z[0]))
b = h.add("chord", (SHELF_RUN_X, SHELF_Z[1]))
c = h.add("chord", (SHELF_RUN_X, SHELF_Z[2]))
turn45 = h.add("bend", (SHELF_RUN_X, RIGHT_WALL[1] + 1.1))
right = h.add("destination", RIGHT_WALL, "RightWallTarget", "none", unit(RIGHT_WALL[0] - 8.4, RIGHT_WALL[1] + 11.0))
back = h.add("junction", (0.0, RIGHT_WALL[1]))
door = h.add("destination", (0.0, -13.6), "GalleryDoor", "rect", (0.0, 1.0))
left = h.add("destination", LEFT_WALL, "LeftWallTarget", "none", unit(LEFT_WALL[0] + 8.4, LEFT_WALL[1] + 11.0))
column = h.add("destination", COLUMN_RING, "Build", "round", (1.0, 0.0))
# Down from the builder's ring to the Voxel Lab wall's, clear of Build it's panel.
down_left = h.add("bend", (LEFT_WALL[0], 5.0))
# A short branch at right angles to each of A, B and C, ending at its marker.
shelf_ends = [h.add("bend", (SHELF_SPOT_X, z)) for z in SHELF_Z]
h.link(start, pivot, block)
h.link(pivot, a, b, c, turn45, right, back, door)
# The left loop runs out of the pivot too (round 3: "arrows also originate from the same central pivot
# and travel toward the left"), down past the column and the Voxel Lab wall to the back junction.
h.link(pivot, column, down_left, left, back)
for run, end in zip([a, b, c], shelf_ends):
    h.link(run, end)
h.write(ROOT / 'paths' / 'hall.tres')

# The gallery, on the same logic: a spine down the middle, a T to the ladder, the terrain's ring on the spine.
g = Graph()
gstart = g.add("start", (0.0, -16.4 + GZ))
j1 = g.add("junction", (0.0, RUNG_Z[0]))
terrain = g.add("destination", TERRAIN_RING, "Terrain", "rect", (1.0, 0.0), "available")
r1 = g.add("bend", (7.2, RUNG_Z[0]))
r2 = g.add("chord", (7.2, RUNG_Z[1]))
r3 = g.add("chord", (7.2, RUNG_Z[2]))
r_out = g.add("bend", (7.2, -28.8 + GZ))
j3 = g.add("junction", (0.0, -28.8 + GZ))
field = g.add("destination", (0.0, -30.3 + GZ), "FieldDoorTarget", "rect", (0.0, 1.0))
g.link(gstart, j1, terrain, j3, field)
g.link(j1, r1, r2, r3, r_out, j3)
g.write(ROOT / 'paths' / 'gallery.tres')
