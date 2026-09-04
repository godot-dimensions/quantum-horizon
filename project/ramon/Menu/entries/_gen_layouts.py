"""Generates the four Frontier Map layout resources from a compact spec.

Authoring 40-odd nodes and 30-odd edges by hand as .tres sub_resources is a lot
of near-identical text and a lot of places to fat-finger a coordinate. This
emits them from the reference SVGs' own numbers instead.
"""
import os

OUT = r"D:\depot\quantum-horizon\project\ramon\Menu\entries"

SCRIPTS = {
    "entry": "res://ramon/Menu/scripts/frontier_entry.gd",
    "category": "res://ramon/Menu/scripts/frontier_category.gd",
    "edge": "res://ramon/Menu/scripts/frontier_edge.gd",
    "activity": "res://ramon/Menu/scripts/frontier_activity.gd",
    "layout": "res://ramon/Menu/scripts/frontier_layout.gd",
}

# Neutral greys + the four meaning hues, matching frontier_style.tres.
BLUE = "Color(0.294, 0.663, 1, 1)"
GREY_EDGE = "Color(0.251, 0.325, 0.416, 1)"
TEAL = "Color(0.333, 0.784, 0.741, 1)"
VIOLET = "Color(0.655, 0.478, 0.957, 1)"
NEUTRAL = "Color(0.51, 0.51, 0.51, 1)"
GOLD = "Color(0.835, 0.71, 0.42, 1)"


def esc(text):
    return text.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def psa(values):
    return "PackedStringArray(%s)" % ", ".join('"%s"' % esc(v) for v in values)


def pia(values):
    return "PackedInt32Array(%s)" % ", ".join(str(v) for v in values)


def pfa(values):
    return "PackedFloat32Array(%s)" % ", ".join(str(v) for v in values)


class Builder:
    def __init__(self):
        self.subs = []
        self.ids = set()

    def add(self, sub_id, script_key, fields):
        assert sub_id not in self.ids, sub_id
        self.ids.add(sub_id)
        lines = ['[sub_resource type="Resource" id="%s"]' % sub_id,
                 'script = ExtResource("%s")' % script_key]
        for key, value in fields:
            lines.append("%s = %s" % (key, value))
        self.subs.append("\n".join(lines))
        return sub_id


def node(b, sub_id, title, pos, *, display="", glyph="", state=1, kind=0,
         category=2, radius=1.0, sub="", detail="", detail2="", head="",
         tags=None, gate=False, halo=False, opens="", activity=None,
         activity_count=0, activity_glyph="", action="", after="",
         flag="", flag_caption=""):
    fields = [("entry_title", '"%s"' % esc(title)),
              ("reference_position", "Vector2(%d, %d)" % pos)]
    if after:
        fields.append(("route_after", '"%s"' % esc(after)))
    if display:
        fields.append(("display_title", '"%s"' % esc(display)))
    if glyph:
        fields.append(("glyph", '"%s"' % esc(glyph)))
    fields += [("state", str(state)), ("kind", str(kind)),
               ("category", str(category))]
    if radius != 1.0:
        fields.append(("radius_scale", str(radius)))
    if halo:
        fields.append(("haloed", "true"))
    if gate:
        fields.append(("gate_essential", "true"))
    if flag:
        fields.append(("flag_letter", '"%s"' % esc(flag)))
    if flag_caption:
        fields.append(("flag_caption", '"%s"' % esc(flag_caption)))
    if sub:
        fields.append(("standalone_subtitle", '"%s"' % esc(sub)))
    if head:
        fields.append(("detail_head", '"%s"' % esc(head)))
    if detail:
        fields.append(("map_detail", '"%s"' % esc(detail)))
    if detail2:
        fields.append(("map_detail_2", '"%s"' % esc(detail2)))
    if tags:
        fields.append(("tags", psa(tags)))
    if opens:
        fields.append(("opens_map", '"%s"' % opens))
    if action:
        fields.append(("action_label", '"%s"' % esc(action)))
    if activity_count:
        fields.append(("activity_count", str(activity_count)))
    if activity_glyph:
        fields.append(("activity_glyph", '"%s"' % esc(activity_glyph)))
    if activity:
        fields.append(("activity", 'SubResource("%s")' % activity))
    return b.add(sub_id, "1_entry", fields)


def lane(b, sub_id, label, pos, colour, edge_colour, *, sep=-1.0, drop=None,
         cat=0, style=0, mark=True):
    fields = [("label", '"%s"' % esc(label)), ("category", str(cat)),
              ("color", colour), ("edge_color", edge_colour),
              ("label_position", "Vector2(%d, %d)" % pos),
              ("separator_x", str(sep)), ("text_style", str(style)),
              ("show_mark", "true" if mark else "false")]
    if drop:
        fields.append(("drop_line", "Vector3(%d, %d, %d)" % drop))
    return b.add(sub_id, "2_category", fields)


def edge(b, sub_id, a, z, *, tone=0, estimated=False, curvature=-1.0):
    fields = [("from_id", '"%s"' % esc(a)), ("to_id", '"%s"' % esc(z)),
              ("tone", str(tone))]
    if estimated:
        fields.append(("estimated", "true"))
    if curvature >= 0.0:
        fields.append(("curvature", str(curvature)))
    return b.add(sub_id, "3_edge", fields)


def activity(b, sub_id, **kw):
    fields = []
    for key in ("contributors", "merged", "open_briefs", "played", "completed", "shared"):
        if kw.get(key):
            fields.append((key, str(kw[key])))
    if kw.get("members"):
        fields.append(("member_initials", psa(kw["members"])))
    if kw.get("overflow"):
        fields.append(("member_overflow", str(kw["overflow"])))
    if kw.get("lanes"):
        names, counts, fills = zip(*kw["lanes"])
        fields += [("lane_names", psa(names)), ("lane_counts", pia(counts)),
                   ("lane_fills", pfa(fills))]
    if kw.get("options"):
        titles, subs, counts = zip(*kw["options"])
        fields += [("signal_open", "true"), ("option_titles", psa(titles)),
                   ("option_subtitles", psa(subs)), ("option_counts", pia(counts))]
    return b.add(sub_id, "4_activity", fields)


def write(name, b, resource_fields):
    header = ['[gd_resource type="Resource" script_class="FrontierLayout" load_steps=%d format=3]'
              % (len(b.subs) + 6), ""]
    header += ['[ext_resource type="Script" path="%s" id="1_entry"]' % SCRIPTS["entry"],
               '[ext_resource type="Script" path="%s" id="2_category"]' % SCRIPTS["category"],
               '[ext_resource type="Script" path="%s" id="3_edge"]' % SCRIPTS["edge"],
               '[ext_resource type="Script" path="%s" id="4_activity"]' % SCRIPTS["activity"],
               '[ext_resource type="Script" path="%s" id="5_layout"]' % SCRIPTS["layout"], ""]
    body = "\n\n".join(b.subs)
    tail = ["", "[resource]", 'script = ExtResource("5_layout")']
    tail += ["%s = %s" % (k, v) for k, v in resource_fields]
    text = "\n".join(header) + body + "\n" + "\n".join(tail) + "\n"
    path = os.path.join(OUT, name)
    open(path, "w", encoding="utf-8", newline="\n").write(text)
    print("wrote %s  (%d sub-resources)" % (name, len(b.subs)))


def array(kind, ids):
    return "Array[ExtResource(\"%s\")]([%s])" % (
        kind, ", ".join('SubResource("%s")' % i for i in ids))
