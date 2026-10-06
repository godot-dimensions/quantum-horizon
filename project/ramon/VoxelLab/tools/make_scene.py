"""Voxel Lab: writes voxel_lab.tscn, the room, from the lists below (stations, benches, consoles,
lights, signs, route targets). Edit here and run it, rather than editing the scene by hand:

    python project/ramon/VoxelLab/tools/make_scene.py

Godot must be closed or the scene not open in it. The route graphs (paths/*.tres) are made by
scripts/_make_paths_runner.gd.
"""
from pathlib import Path
import re
out = []
ext = [
    ("1_root", "Script", "res://ramon/VoxelLab/voxel_lab_4d.gd"),
    ("2_room", "Script", "res://ramon/VoxelLab/carried/LabKit/lab_room_4d.gd"),
    ("3_kitroom", "Script", "res://ramon/VoxelLab/carried/kit/kit_room_4d.gd"),
    ("4_text", "Script", "res://ramon/VoxelLab/carried/kit/kit_wall_text_4d.gd"),
    ("5_showcase", "Script", "res://ramon/VoxelLab/carried/kit/kit_showcase_4d.gd"),
    ("6_block", "Script", "res://ramon/VoxelLab/stations/vl_block_exhibit_4d.gd"),
    ("7_bench", "Script", "res://ramon/VoxelLab/room/vl_bench_4d.gd"),
    ("8_console", "Script", "res://ramon/VoxelLab/room/vl_console_4d.gd"),
    ("9_shelf", "Script", "res://ramon/VoxelLab/stations/vl_shelf_exhibit_4d.gd"),
    ("10_light", "Script", "res://ramon/VoxelLab/carried/kit/kit_light_4d.gd"),
    ("11_sun", "Script", "res://ramon/VoxelLab/carried/kit/kit_sun_4d.gd"),
    ("12_column", "Script", "res://ramon/VoxelLab/stations/vl_column_exhibit_4d.gd"),
    ("13_panel", "Script", "res://ramon/VoxelLab/carried/kit/panels/kit_wall_panel_4d.gd"),
    ("14_pair", "Script", "res://ramon/VoxelLab/carried/kit/panels/kit_wall_panels_4d.gd"),
    ("15_source", "Script", "res://ramon/VoxelLab/room/vl_panel_source.gd"),
    ("16_info", "Resource", "res://ramon/VoxelLab/voxel_lab_info.tres"),
    ("17_case", "Script", "res://ramon/VoxelLab/stations/vl_case_exhibit_4d.gd"),
    ("18_net", "Script", "res://ramon/VoxelLab/carried/PathCreator/graph/path_network_4d.gd"),
    ("19_hall", "Resource", "res://ramon/VoxelLab/paths/hall.tres"),
    ("20_gallery", "Resource", "res://ramon/VoxelLab/paths/gallery.tres"),
    ("21_target", "Script", "res://ramon/VoxelLab/room/vl_target_4d.gd"),
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


node("VoxelLab", None, "Node4D", [("script", 'ExtResource("1_root")'), ("room_half_width", "12.0"), ("room_back", "15.0"),
                                  ("corner_length", "10.8"), ("start_at", "Vector2(0, 22)")])
node("Room", ".", "Node4D", [("script", 'ExtResource("2_room")'), ("start_mood", q("bright"))])
node("Entrance", ".", "Node4D", [("position", V(0, 0, 19.5)), ("script", 'ExtResource("3_kitroom")'), ("size", "Vector3(8, 6, 14)"),
                                 ("open_sides", '["n"]'), ("cove", "false")])
node("Hall", ".", "Node4D", [("script", 'ExtResource("3_kitroom")'), ("size", "Vector3(24, 9, 27)"), ("cove", "false")])
node("Sign", "Hall", "Node", [("script", 'ExtResource("4_text")'), ("side", q("s")), ("edge", "5"), ("along", "Vector2(7.6, 16.4)"),
                              ("up", "Vector2(4.4, 5.9)"), ("outside", "true"), ("kind", q("sign")), ("title", q("VOXEL LAB")),
                              ("subtitle", q("QUANTUM HORIZON  ·  CUTTING 4D MATTER")), ("glow", "0.3")])
node("GalleryRoom", ".", "Node4D", [("position", V(0, 0, -24)), ("script", 'ExtResource("3_kitroom")'), ("size", "Vector3(26, 8, 16)"),
                                    ("cove", "false")])
node("GallerySign", "GalleryRoom", "Node", [("script", 'ExtResource("4_text")'), ("side", q("s")), ("along", "Vector2(7.5, 18.5)"),
                                           ("up", "Vector2(4.8, 6.4)"), ("kind", q("sign")), ("title", q("THE ENGINE'S TEST CASES")),
                                           ("subtitle", q("ANDREW'S (4DENTHUSIAST'S) TEST SCENES, CUT LIVE")), ("glow", "0.3")])


node("AboutWall", "GalleryRoom", "Node", [("script", 'ExtResource("4_text")'), ("side", q("w")), ("along", "Vector2(-6.6, 6.6)"),
                                          ("up", "Vector2(1.3, 6.6)"), ("kind", q("lesson")), ("number", "1"), ("title", q("The engine's test cases")),
                                          ("subtitle", q("Andrew's own test scenes, as specimens")),
                                          ("body", q("Andrew (4Denthusiast) wrote the engine's voxel world: its generators, its edits, its dual contouring. "
                                                     "These are his test scenes, cut out as specimens: his landscape with its ocean and caves, his caves on their own, "
                                                     "his 24-cell. Sit at their benches and cut them.")),
                                          ("code", q("blue")), ("glow", "0.2")])
node("FieldSign", "GalleryRoom", "Node", [("script", 'ExtResource("4_text")'), ("side", q("n")), ("along", "Vector2(-4.4, 4.4)"),
                                          ("up", "Vector2(4.6, 6.4)"), ("kind", q("sign")), ("title", q("THE FIELD")),
                                          ("subtitle", q("ANDREW'S LANDSCAPE, GENERATED ROUND YOU")), ("glow", "0.3")])
node("LimitsWall", "GalleryRoom", "Node", [("script", 'ExtResource("4_text")'), ("side", q("e")), ("along", "Vector2(-6.6, 6.6)"),
                                           ("up", "Vector2(1.3, 6.6)"), ("kind", q("lesson")), ("number", "2"), ("title", q("What still fails")),
                                           ("subtitle", q("Where the voxels need work, measured in this room")),
                                           ("body", q("A cut thinner than a voxel vanishes, so the saw's blade is a voxel and a third. "
                                                      "A surface through grid points frays: the warm 24-cell. "
                                                      "A cut's new chunks are built in the frame they first show; this lab builds them on a worker thread (T at any bench shows both). "
                                                      "Detail costs the fourth power: the ladder. And GDScript cannot read a voxel back, so the lab keeps its own copy.")),
                                           ("code", q("blue")), ("glow", "0.2")])


def light(name, x, z, y=8.6, angle=45.0, reach=11.0, b=2.6, d=3.4, fixture=8.94):
    props = [("position", V(x, y, z)), ("script", 'ExtResource("10_light")'), ("aim", "Vector3(%s, 0, %s)" % (x, z)),
             ("angle", str(angle)), ("softness", "0.5"), ("reach", str(reach)), ("attenuation", "0.3"),
             ("energy", '{\n"bright": %s,\n"dark": %s\n}' % (b, d))]
    if fixture:
        props.append(("fixture_at", str(fixture)))
    node(name, ".", "Node4D", props)


def station(name, x, z, script, radius, height=0.9, shape="round", band=90.0, meta=None, holo=True):
    props = [("position", V(x, 0, z)), ("script", 'ExtResource("5_showcase")'), ("exhibit_script", 'ExtResource("%s")' % script),
             ("radius", str(radius)), ("height", str(height)), ("pedestal_shape", q(shape)), ("bounds", "Rect2(-13, -31.5, 26, 44)"),
             ("band_angle", str(band))]
    if not holo:
        props.append(("hologram", "false"))
    for k, v in (meta or []):
        props.append(("metadata/%s" % k, v))
    node(name, ".", "Node4D", props)


def bench(name, x, z, st, dist=4.6, title="THE BENCH", sub="CUT IT YOURSELF"):
    node(name, ".", "Node4D", [("position", V(x, 0, z)), ("script", 'ExtResource("7_bench")'), ("station", 'NodePath("../%s")' % st),
                               ("title", q(title)), ("subtitle", q(sub)), ("camera_distance", str(dist))])


def console(name, x, z, st, title, code, kicker, facing, number):
    node(name, ".", "Node4D", [("position", V(x, 0, z)), ("script", 'ExtResource("8_console")'), ("station", 'NodePath("../%s")' % st),
                               ("number", str(number)), ("title", q(title)), ("code", q(code)), ("kicker", q(kicker)),
                               ("facing", str(facing))])


# The shelf, on the right as you come in.
for i, (kind, z) in enumerate([("section", 8.0), ("tunnels", 4.4), ("cavity", 0.8)]):
    station("Shelf%d" % (i + 1), 8.6, z, "9_shelf", 0.95, 1.0, "box", -90.0, [("shelf_kind", q(kind)), ("face_yaw", "-90.0")], False)
light("ShelfLight", 7.6, 4.4, 8.6, 44.0, 11.0, 1.7, 2.3)
# The block.
station("Hero", 0, -1.4, "6_block", 2.8)
bench("HeroBench", 0, 4.0, "Hero", 5.2)
console("HeroConsole", -4.6, 3.2, "Hero", "The block", "VX-01", "THE ENGINE'S VOXELS, CUT LIVE", 30.0, 1)
light("HeroLight", 0, -1.4, 8.6, 50.0)
# The column, on the left, further on.
station("Column", -8.2, -5.0, "12_column", 1.5, 0.6)
bench("ColumnBench", -8.2, -1.2, "Column", 4.4, "THE COLUMN", "CUT ITS BASE")
console("ColumnConsole", -4.4, -7.4, "Column", "The column", "CL-02", "SUPPORT IN 4D", -30.0, 2)
light("ColumnLight", -7.8, -5.0, 8.6, 32.0, 11.0, 2.4, 3.2)
# The gallery: the engine's test cases.
station("Terrain", -7.5, -22.5, "17_case", 2.2, 0.9, "round", 90.0, [("case", q("terrain"))])
bench("TerrainBench", -7.5, -18.8, "Terrain", 3.8, "THE TERRAIN SAMPLE", "CUT ANDREW'S WORLD")
station("Caves", 7.5, -22.5, "17_case", 2.0, 0.9, "round", -90.0, [("case", q("caves"))])
bench("CavesBench", 7.5, -18.8, "Caves", 3.8, "THE CAVES", "CUT INTO THEM")
station("Cell24", -7.5, -28.6, "17_case", 2.1, 0.9, "round", 90.0, [("case", q("24cell"))])
station("Ladder", 7.5, -28.6, "17_case", 2.0, 0.9, "box", -90.0, [("case", q("ladder"))], False)
console("TerrainConsole", -11.0, -18.6, "Terrain", "Terrain sample", "AN-01", "FROM THE ENGINE'S TEST SCENES", 40.0, 3)
console("CavesConsole", 11.0, -18.6, "Caves", "Caves", "AN-02", "FROM THE ENGINE'S TEST SCENES", -40.0, 4)
console("Cell24Console", -3.4, -28.0, "Cell24", "24-cell", "AN-03", "A KNOWN LIMIT", -20.0, 5)
console("LadderConsole", 3.4, -28.0, "Ladder", "Resolution ladder", "LD-04", "THE COST OF DETAIL", 20.0, 6)
for nm, x, z in [("TerrainLight", -7.5, -22.5), ("CavesLight", 7.5, -22.5), ("Cell24Light", -7.5, -28.6), ("LadderLight", 7.5, -28.6)]:
    light(nm, x, z, 7.6, 42.0, 10.0, 2.4, 3.2, 7.94)
light("EntranceLight", 0, 15.5, 5.4, 48.0, 9.0, 1.2, 1.6, 0)
node("Sun", ".", "Node4D", [("position", V(2, 9, 4)), ("script", 'ExtResource("11_sun")'), ("target", "Vector3(0, 0, -2)")])
node("PanelSource", ".", "Node", [("script", 'ExtResource("15_source")'), ("room", 'NodePath("..")'), ("hero", 'NodePath("../Hero")')])
node("IntroPanel", ".", "Node4D", [("script", 'ExtResource("13_panel")'), ("info", 'ExtResource("16_info")'),
                                   ("source", 'NodePath("../PanelSource")'), ("room_path", 'NodePath("../Hall")'), ("wall_name", q("left_corner"))])
node("ResearchBoard", ".", "Node4D", [("script", 'ExtResource("13_panel")'), ("kind", q("research")), ("info", 'ExtResource("16_info")'),
                                      ("source", 'NodePath("../PanelSource")'), ("room_path", 'NodePath("../Hall")'),
                                      ("wall_name", q("right_corner"))])
node("WallPanels", ".", "Node4D", [("script", 'ExtResource("14_pair")'), ("intro", 'NodePath("../IntroPanel")'),
                                   ("research", 'NodePath("../ResearchBoard")'), ("info", 'ExtResource("16_info")'),
                                   ("source", 'NodePath("../PanelSource")')])
node("FieldDoor", ".", "Node4D", [("position", V(0, 2.4, -32.2))])
node("Paths", ".", "Node4D")
node("Targets", "Paths", "Node4D")
for nm, x, z, size, label in [("Shelf", 8.6, 4.4, "Vector3(2.2, 1, 9.2)", "Shelf"), ("HeroBench", 0, 4.0, "Vector3(3, 0.05, 1.3)", "The block's bench"),
                              ("ColumnBench", -8.2, -1.2, "Vector3(3, 0.05, 1.3)", "The column's bench"),
                              ("GalleryDoor", 0, -15.0, "Vector3(3, 4.2, 0.6)", "Gallery door"),
                              ("TerrainBench", -7.5, -18.8, "Vector3(3, 0.05, 1.3)", "Terrain bench"),
                              ("CavesBench", 7.5, -18.8, "Vector3(3, 0.05, 1.3)", "Caves bench"),
                              ("Cell24", -7.5, -28.6, "Vector3(3.6, 1, 3.6)", "24-cell"),
                              ("Ladder", 7.5, -28.6, "Vector3(4, 1, 4)", "Ladder"),
                              ("FieldDoorTarget", 0, -32.2, "Vector3(3.2, 4.2, 0.6)", "Field door")]:
    node(nm, "Paths/Targets", "Node4D", [("position", V(x, 0, z)), ("script", 'ExtResource("21_target")'), ("label", q(label)), ("size", size)])
node("Hall", "Paths", "Node4D", [("script", 'ExtResource("18_net")'), ("graph", 'ExtResource("19_hall")'), ("targets", 'NodePath("../Targets")'),
                                ("under_color", "Color(0.64, 0.65, 0.66, 1)")])
node("Gallery", "Paths", "Node4D", [("script", 'ExtResource("18_net")'), ("graph", 'ExtResource("20_gallery")'), ("targets", 'NodePath("../Targets")'),
                                   ("under_color", "Color(0.64, 0.65, 0.66, 1)")])
txt = '\n'.join(out).rstrip() + '\n'
(Path(__file__).resolve().parent.parent / 'voxel_lab.tscn').open('w', encoding='utf8', newline='\n').write(txt)
print('nodes:', txt.count('[node '))
