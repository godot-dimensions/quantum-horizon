import sys
sys.path.insert(0, r"C:\Users\ramon\AppData\Local\Temp\claude\D--depot-quantum-horizon\352a2586-5596-472b-9ca4-d4ca16b73b41\scratchpad")
from gen_layouts import *

CAPTION = ("ONE GUIDED EXPERIENCE STRING · CURVES ADD RHYTHM, NOT BRANCHING LOGIC "
           "· CATEGORY ANCHORS SHOW THE TYPE OF PROOF")

# =========================================================================
# 1. OVERVIEW  -  the permanent home screen, unchanged in shape.
# =========================================================================
b = Builder()

gate_act = activity(b, "Act_gate", contributors=6, merged=3, open_briefs=2,
                    members=["RT", "AF", "4D", "TB"], overflow=2,
                    lanes=[("EVIDENCE", 3, 0.65), ("BENCHMARKS", 2, 0.45), ("DOCS", 1, 0.26)],
                    played=42, completed=31, shared=8)
os_act = activity(b, "Act_os", contributors=4, merged=2, open_briefs=3,
                  members=["AF", "4D", "TB"], overflow=1,
                  lanes=[("CODE", 3, 0.65), ("ART / TEST", 2, 0.46), ("DOCS", 1, 0.26)],
                  played=18, completed=11, shared=5,
                  options=[("PLAYER VOXEL TOOLS", "NON-EXPERT CREATION PATH", 24),
                           ("W RADAR + TARGETING", "4D ORIENTATION INTERFACE", 18),
                           ("OUTSIDER BUILD DOCS", "REMOVE EXPERT INTERVENTIONS", 11)])

XS = [110, 296, 481, 667, 852, 1038, 1223, 1409, 1594, 1780]
YS = [430, 430, 402, 338, 400, 336, 370, 322, 420, 360]
protos = [
    ("Slice Vision", "⊙", 0, 0, 1, "Three chambers that teach reading a 4D cross-section before asking anything of you."),
    ("Phase Maze", "▥", 0, 0, 1, "Rotation used as a navigation verb: the route through the maze exists only at the right slice."),
    ("4D Ascent", "◿", 1, 0, 1, "A vertical course where the next foothold is often a rotation away rather than a jump."),
    ("Portal", "◐", 1, 0, 1, "Openings cut anywhere in a wall, and two linked apertures that carry momentum across."),
    ("Quantum Range", "◎", 1, 0, 1, "True 4D raycasting against 4D colliders, independent of what the camera can see."),
    ("Voxel Mining", "◩", 2, 0, 1, "Destructible 4D matter: a persistent voxel field, dual contoured and re-meshed on every hit."),
    ("Shrubbery Lab", "✚", 2, 0, 1, "Procedural growth in four dimensions, rendered with the combined cross-section and projection engine."),
    ("Sky Box Clouds", "☁", 2, 0, 1, "Weather as real 4D solids, so the cloud deck exists at every w rather than only the one you face."),
    ("Nevada Terrain", "▦", 2, 0, 3, "Tests whether varied 4D environments can be generated without bespoke construction."),
    ("Motion Lab", "⌁", 3, 0, 2, "A quadruped whose gait is solved every frame from IK, with limb count and segments changeable live."),
]
ids = []
for i, (title, glyph, cat, kind, state, detail) in enumerate(protos):
    kw = dict(glyph=glyph, category=cat, kind=kind, state=state, detail=detail)
    if title == "Voxel Mining":
        kw.update(gate=True, tags=["GATE ESSENTIAL", "VOXEL CORE"])
    if title == "Nevada Terrain":
        kw.update(gate=True, flag_caption="OCTOBER GATE",
                  sub="VOXEL CORE PROOF", after="Sky Box Clouds",
                  tags=["GATE ESSENTIAL", "VOXEL CORE", "KILL-CONDITION PROOF"])
    ids.append(node(b, "P%d" % i, title, (XS[i], YS[i]), **kw))

# The three planning gateways are now NODES, so selection, focus, badges and the
# information panel work on them exactly as they do on a prototype.
ids.append(node(b, "G_oct", "October Gate", (1110, 760), display="OCTOBER GATE",
                glyph="△", kind=1, state=1, category=2, radius=1.08, halo=True,
                sub="ESSENTIALS SUB-MAP", head="WHAT MUST BE PROVEN BY OCTOBER",
                detail="Gate-critical artifact work, S1-S3 evidence, and the decision-pack inputs behind the October call.",
                detail2="The dependency graph inside is team-owned and estimated until Aaron and Andrew validate it.",
                opens="res://ramon/Menu/entries/map_october_gate.tres",
                activity=gate_act, activity_count=3))
ids.append(node(b, "G_os", "Open-Source Path", (1380, 760), display="OPEN-SOURCE\nPATH",
                glyph="◇", kind=1, state=1, category=2, radius=1.05,
                sub="READINESS SUB-MAP", head="HOW A PUBLIC BUILD BECOMES PROOF",
                detail="License, maintainer, outsider build docs and the canary test that make a hosted jam credible.",
                detail2="Contribution counts open the activity drawer; individual entries live in the jam gallery.",
                opens="res://ramon/Menu/entries/map_open_source.tres",
                activity=os_act, activity_count=4))
ids.append(node(b, "G_2027", "2027 Frontier", (1650, 760), display="2027\nFRONTIER",
                glyph="○", kind=1, state=4, category=2, radius=1.08,
                sub="READ-ONLY / LATER", head="MACRO PREPRODUCTION PLAN",
                detail="Q1-Q4 work across engine, interface, external proof and the partner track, ending at Gate 1.",
                detail2="Productization and the UGC ecosystem stay fogged beyond the gate.",
                opens="res://ramon/Menu/entries/map_2027_frontier.tres"))

cats = [
    lane(b, "C_or", "ORIENTATION", (124, 170), BLUE, BLUE, cat=0, drop=(84, 208, 342)),
    lane(b, "C_sp", "SPATIAL INTERACTION", (450, 170), BLUE, GREY_EDGE, cat=1, sep=389.0, drop=(410, 208, 258)),
    lane(b, "C_wo", "WORLD SYSTEMS", (1006, 170), TEAL, TEAL, cat=2, sep=945.0, drop=(966, 208, 260)),
    lane(b, "C_li", "LIVING SYSTEMS", (1740, 170), VIOLET, VIOLET, cat=3, sep=1688.0, drop=(1709, 208, 286)),
]

write("frontier_layout.tres", b, [
    ("placements", array("1_entry", ids)),
    ("categories", array("2_category", cats)),
    ("route_from_catalogue", "true"),
    ("fog_teaser_position", "Vector2(1810, 760)"),
    ("panel_rect", "Rect2(70, 670, 890, 300)"),
    ("field_span", "Vector2(220, 566)"),
    ("caption_position", "Vector2(70, 566)"),
    ("eyebrow", '"QUANTUM HORIZON"'), ("title", '"FRONTIER MAP"'),
    ("start_tour_label", '"START THE TOUR · {count} PROTOTYPES"'),
    ("route_caption", '"%s"' % CAPTION),
    ("gateways_heading", '"PLANNING GATEWAYS"'),
    ("gateways_note", '"SEPARATE SUB-MAPS · NOT PART OF THE TOUR ORDER"'),
    ("launch_label", '"LAUNCH"'),
    ("legend_labels", psa(["PLAYED", "ACTIVE", "AVAILABLE", "RESEARCH", "FOG / LATER"])),
    ("gate_legend_label", '"GATE ESSENTIAL"'),
])

# =========================================================================
# 2. OCTOBER GATE
# =========================================================================
b = Builder()
ev_act = activity(b, "Act_ev", contributors=5, merged=4, open_briefs=3,
                  members=["AF", "4D", "RT"], overflow=2,
                  lanes=[("S1 PERFORMANCE", 2, 0.6), ("S2 SCALE", 1, 0.35), ("S3 REGEN", 1, 0.28)],
                  played=42, completed=31, shared=8)
gate_q = activity(b, "Act_gq", contributors=4, merged=2, open_briefs=3,
                  members=["AF", "4D", "RT", "TB"], overflow=0,
                  lanes=[("EVIDENCE", 3, 0.7), ("DECISION PACK", 2, 0.5), ("PROCESS", 1, 0.3)],
                  played=0, completed=0, shared=0)

n = []
n.append(node(b, "N_core", "Voxel Core", (120, 420), display="VOXEL CORE", glyph="▦",
              state=1, kind=2, category=2, radius=1.12, sub="ACTIVE", head="LIVE ARTIFACT",
              detail="The dual-contoured 4D voxel field everything else on this map is built on.",
              action="INSPECT"))
n.append(node(b, "N_surf", "Surfacing Modes", (340, 315), display="SURFACING\nMODES", glyph="◩",
              state=1, kind=2, category=2, sub="GATE-CRITICAL", head="LIVE ARTIFACT",
              detail="Marching 24-cells and mesh simplification: how a voxel field becomes a surface you can see.",
              action="INSPECT"))
n.append(node(b, "N_mat", "Materials + Scatter", (340, 535), display="MATERIALS +\nSCATTER", glyph="✣",
              state=1, kind=2, category=2, sub="SUPPORTING", head="LIVE ARTIFACT",
              detail="Surface dressing. Supporting work rather than a gate prerequisite.",
              action="INSPECT"))
n.append(node(b, "N_nev", "Nevada Terrain", (570, 420), display="NEVADA TERRAIN", glyph="▦",
              state=3, kind=2, category=2, radius=1.15, halo=True, gate=True,
              sub="PROCEDURAL PROOF", head="GATE-ESSENTIAL PROCEDURAL PROOF",
              detail="Demonstrates usable 4D terrain generated from seeds and parameters rather than bespoke construction.",
              detail2="Its output feeds the S1-S3 evidence package; the exact dependencies still need Aaron and Andrew to validate.",
              tags=["GATE ESSENTIAL", "VOXEL CORE", "KILL-CONDITION PROOF"],
              action="NOT BUILT YET"))
n.append(node(b, "N_regen", "In-Place Regen", (795, 315), display="IN-PLACE\nREGEN", glyph="↻",
              state=1, kind=2, category=2, sub="S3", head="GATE EVIDENCE",
              detail="Regenerating a world in place from a new seed, without a reload. The S3 criterion.",
              action="INSPECT"))
n.append(node(b, "N_perf", "Perf + World Scale", (795, 525), display="PERF +\nWORLD SCALE", glyph="▥",
              state=1, kind=2, category=2, sub="S1 / S2", head="GATE EVIDENCE",
              detail="Frame time and world size under load. The S1 and S2 criteria.",
              action="INSPECT"))
n.append(node(b, "N_ev", "Gate Evidence", (1045, 420), display="GATE\nEVIDENCE", glyph="✓",
              state=1, kind=2, category=2, radius=1.18, halo=True,
              sub="S1-S3 + INDEPENDENCE", head="THE EVIDENCE PACKAGE",
              detail="What the October decision is actually read from: the S1-S3 measurements plus the independence ladder.",
              tags=["S1", "S2", "S3"], activity=ev_act, activity_count=3, action="VIEW EVIDENCE"))
n.append(node(b, "N_road", "2027 Roadmap", (1360, 285), display="2027\nROADMAP", glyph="▤",
              state=1, kind=2, category=2, sub="COSTED", head="DECISION PACK",
              detail="A costed twelve-month plan. Required for the decision, but not a prerequisite in the codebase."))
n.append(node(b, "N_osp", "Open-Source Plan", (1360, 430), display="OPEN-SOURCE\nPLAN", glyph="◇",
              state=1, kind=2, category=2, sub="LICENSE + MAINTAINER", head="DECISION PACK",
              detail="License choice, dependency audit, contribution model and a named maintainer."))
n.append(node(b, "N_rfp", "RFP Draft", (1360, 600), display="RFP DRAFT", glyph="R",
              state=2, kind=2, category=3, sub="PROCESS MILESTONE", head="DECISION PACK",
              detail="The academic-partner request for proposals. A process milestone on its own clock."))
n.append(node(b, "N_gate", "October Gate", (1640, 420), display="OCTOBER GATE", glyph="△",
              state=1, kind=2, category=2, radius=1.32, halo=True,
              sub="CONTINUE / PIVOT / STOP", head="THE DECISION",
              detail="Continue, pivot or stop. Read from the evidence package and the decision pack together.",
              detail2="Nothing on this map votes on the outcome; the map only shows what the call will be made from.",
              tags=["CONTINUE", "PIVOT", "STOP"],
              activity=gate_q, activity_glyph="?", action="VIEW CRITERIA"))

e = []
e.append(edge(b, "E1", "Voxel Core", "Surfacing Modes", tone=2))
e.append(edge(b, "E2", "Voxel Core", "Materials + Scatter", tone=1, estimated=True))
e.append(edge(b, "E3", "Surfacing Modes", "Nevada Terrain", tone=2))
e.append(edge(b, "E4", "Materials + Scatter", "Nevada Terrain", tone=1, estimated=True))
e.append(edge(b, "E5", "Nevada Terrain", "In-Place Regen", tone=2))
e.append(edge(b, "E6", "Nevada Terrain", "Perf + World Scale", tone=2))
e.append(edge(b, "E7", "In-Place Regen", "Gate Evidence", tone=2))
e.append(edge(b, "E8", "Perf + World Scale", "Gate Evidence", tone=2))
e.append(edge(b, "E9", "Gate Evidence", "October Gate", tone=0, curvature=0.3))
e.append(edge(b, "E10", "2027 Roadmap", "October Gate", tone=1, estimated=True))
e.append(edge(b, "E11", "Open-Source Plan", "October Gate", tone=1, estimated=True))
e.append(edge(b, "E12", "RFP Draft", "October Gate", tone=3))

cats = [
    lane(b, "L_live", "LIVE ARTIFACT", (70, 178), BLUE, BLUE, cat=0, mark=False),
    lane(b, "L_ev", "GATE EVIDENCE", (900, 178), TEAL, TEAL, cat=2, sep=850.0, mark=False),
    lane(b, "L_pack", "DECISION PACK", (1325, 178), NEUTRAL, GREY_EDGE, cat=1, sep=1265.0, mark=False),
]

write("map_october_gate.tres", b, [
    ("placements", array("1_entry", n)),
    ("categories", array("2_category", cats)),
    ("edges", array("3_edge", e)),
    ("breadcrumb", '"FRONTIER MAP  /  OCTOBER GATE"'),
    ("caveat", '"ESTIMATED · ENGINEER VALIDATION REQUIRED"'),
    ("panel_rect", "Rect2(70, 760, 1780, 200)"),
    ("field_span", "Vector2(230, 700)"),
    ("caption_position", "Vector2(70, 712)"),
    ("title", '"FRONTIER MAP"'), ("eyebrow", '"QUANTUM HORIZON"'),
    ("route_caption", '"TECHNICAL EDGES SHOW ESTIMATED PREREQUISITES · DECISION-PACK EDGES SHOW REQUIRED INPUTS, NOT ENGINE DEPENDENCIES"'),
    ("launch_label", '"INSPECT"'),
    ("legend_labels", psa(["PLAYED", "ACTIVE", "AVAILABLE", "RESEARCH", "LATER / FOG"])),
    ("gate_legend_label", '"GATE ESSENTIAL"'),
])

# =========================================================================
# 3. OPEN-SOURCE + GAME-JAM PATH
# =========================================================================
b = Builder()
brief_act = activity(b, "Act_brief", contributors=6, merged=3, open_briefs=2,
                     members=["RT", "AF", "4D", "TB"], overflow=2,
                     lanes=[("CODE", 3, 0.65), ("ART / TEST", 2, 0.46), ("DOCS", 1, 0.26)],
                     played=42, completed=31, shared=8,
                     options=[("PLAYER VOXEL TOOLS", "NON-EXPERT CREATION PATH", 24),
                              ("W RADAR + TARGETING", "4D ORIENTATION INTERFACE", 18),
                              ("OUTSIDER BUILD DOCS", "REMOVE EXPERT INTERVENTIONS", 11)])
jam_act = activity(b, "Act_jam", contributors=3, merged=0, open_briefs=1,
                   members=["EX", "EX", "EX"],
                   lanes=[("ENTRIES", 3, 0.4), ("MENTORS", 2, 0.3)],
                   played=0, completed=0, shared=0)

n = []
n.append(node(b, "S_build", "Stable Public Build", (130, 420), display="STABLE PUBLIC\nBUILD",
              glyph="✓", state=0, kind=2, category=0, radius=1.12, sub="READY", head="PUBLIC READY",
              detail="A build an outsider can actually obtain and run.", action="INSPECT"))
n.append(node(b, "S_lic", "License + Maintainer", (340, 315), display="LICENSE +\nMAINTAINER",
              glyph="▤", state=0, kind=2, category=0, sub="READY", head="PUBLIC READY",
              detail="License choice, third-party audit, contribution model and a named owner.", action="INSPECT"))
n.append(node(b, "S_docs", "Outsider Build Docs", (340, 525), display="OUTSIDER\nBUILD DOCS",
              glyph="▥", state=1, kind=2, category=2, sub="RUNG-3 PREREQUISITE", head="PUBLIC READY",
              detail="Build instructions written for someone with no access to the team.", action="INSPECT"))
n.append(node(b, "S_pack", "Example + Context Pack", (600, 420), display="EXAMPLE +\nCONTEXT PACK",
              glyph="◇", state=1, kind=2, category=2, radius=1.05, sub="PARTIAL", head="OUTSIDER PROOF",
              detail="Worked examples and a Start Here pack, so a newcomer has somewhere to begin.", action="INSPECT"))
n.append(node(b, "S_tools", "Player Voxel Tools", (600, 590), display="PLAYER VOXEL\nTOOLS",
              glyph="✣", state=1, kind=2, category=2, sub="OPEN BRIEF", head="OPEN CONTRIBUTION BRIEF",
              detail="A non-expert creation path. Currently an open brief rather than committed work.",
              detail2="Contribution is aggregated here; individual people and PRs live one level deeper.",
              activity=brief_act, activity_count=3, action="VIEW CONTRIBUTION BRIEF"))
n.append(node(b, "S_canary", "Outsider Canary", (830, 420), display="OUTSIDER\nCANARY",
              glyph="◈", state=1, kind=2, category=2, radius=1.15, halo=True,
              sub="NO EXPERT ACCESS", head="THE OPEN-SOURCE READINESS TEST",
              detail="Give one external developer the package without project-expert access and record every intervention required.",
              detail2="Passing this makes the hosted jam credible; it does not require exposing every contributor as a map node.",
              tags=["RUNG 3", "NO EXPERT ACCESS", "INTERVENTIONS LOGGED"], action="VIEW ACTIVITY"))
n.append(node(b, "S_jam", "Hosted Jam", (1100, 420), display="HOSTED\nJAM", glyph="◆",
              state=4, kind=2, category=3, radius=1.15,
              sub="GROUPED EVENT NODE", head="JAM PATH",
              detail="One node for the whole event. Entries live in its gallery, never as map nodes.",
              activity=jam_act, activity_count=3))
n.append(node(b, "S_hire", "Gameplay Hire", (1300, 315), display="GAMEPLAY\nHIRE", glyph="+",
              state=4, kind=2, category=3, sub="RECRUITING PATH", head="JAM PATH",
              detail="The jam doubles as a recruiting funnel for the gameplay developer the team lacks."))
n.append(node(b, "S_gal", "Jam Gallery", (1300, 525), display="JAM\nGALLERY", glyph="▦",
              state=4, kind=2, category=3, sub="SUBMISSIONS LIVE HERE", head="JAM PATH",
              detail="Where individual submissions live, so the roadmap never grows one node per entry."))
n.append(node(b, "S_ext", "External Jam", (1510, 420), display="EXTERNAL\nJAM", glyph="◆",
              state=4, kind=2, category=3, radius=1.05,
              sub="NO HOME-FIELD ADVANTAGE", head="JAM PATH",
              detail="An established third-party jam, entered openly against other engines and teams."))
n.append(node(b, "S_gate", "Gate 1", (1740, 420), display="GATE 1", glyph="△",
              state=4, kind=2, category=2, radius=1.15, halo=True,
              sub="STUDIO / PIVOT / STOP", head="THE DECISION THIS FEEDS",
              detail="External reception is evidence feeding Gate 1. It is not a vote that rewrites the roadmap."))

e = []
e.append(edge(b, "F1", "Stable Public Build", "License + Maintainer", tone=0))
e.append(edge(b, "F2", "Stable Public Build", "Outsider Build Docs", tone=0))
e.append(edge(b, "F3", "License + Maintainer", "Example + Context Pack", tone=2))
e.append(edge(b, "F4", "Outsider Build Docs", "Example + Context Pack", tone=2))
e.append(edge(b, "F5", "Example + Context Pack", "Outsider Canary", tone=2))
e.append(edge(b, "F6", "Example + Context Pack", "Player Voxel Tools", tone=1, estimated=True))
e.append(edge(b, "F7", "Outsider Canary", "Hosted Jam", tone=3))
e.append(edge(b, "F8", "Hosted Jam", "Gameplay Hire", tone=3))
e.append(edge(b, "F9", "Hosted Jam", "Jam Gallery", tone=3))
e.append(edge(b, "F10", "Gameplay Hire", "External Jam", tone=3))
e.append(edge(b, "F11", "Jam Gallery", "External Jam", tone=3))
e.append(edge(b, "F12", "External Jam", "Gate 1", tone=4, estimated=True))

cats = [
    lane(b, "K_pub", "PUBLIC READY", (70, 178), BLUE, BLUE, cat=0, mark=False),
    lane(b, "K_out", "OUTSIDER PROOF", (585, 178), TEAL, TEAL, cat=2, sep=540.0, mark=False),
    lane(b, "K_jam", "JAM PATH", (1030, 178), VIOLET, VIOLET, cat=3, sep=990.0, mark=False),
    lane(b, "K_g1", "GATE 1", (1580, 178), NEUTRAL, GREY_EDGE, cat=1, sep=1540.0, mark=False),
]

write("map_open_source.tres", b, [
    ("placements", array("1_entry", n)),
    ("categories", array("2_category", cats)),
    ("edges", array("3_edge", e)),
    ("breadcrumb", '"FRONTIER MAP  /  OPEN-SOURCE + GAME-JAM PATH"'),
    ("signal_pill", '"NEXT-CYCLE SIGNAL OPEN · 3 CURATED OPTIONS"'),
    ("signal_node", '"Player Voxel Tools"'),
    ("panel_rect", "Rect2(70, 760, 1780, 200)"),
    ("field_span", "Vector2(230, 700)"),
    ("caption_position", "Vector2(70, 730)"),
    ("title", '"FRONTIER MAP"'), ("eyebrow", '"QUANTUM HORIZON"'),
    ("route_caption", '"SCALING RULE · A JAM IS ONE MAP NODE; INDIVIDUAL ENTRIES LIVE IN ITS GALLERY · CONTRIBUTOR COUNTS OPEN A TEMPORARY ACTIVITY DRAWER"'),
    ("launch_label", '"INSPECT"'),
    ("legend_labels", psa(["PLAYED", "ACTIVE", "AVAILABLE", "RESEARCH", "LATER / FOG"])),
    ("gate_legend_label", '"GATE ESSENTIAL"'),
])

# =========================================================================
# 4. 2027 FRONTIER
# =========================================================================
b = Builder()
g1_act = activity(b, "Act_g1", contributors=0, merged=0, open_briefs=4,
                  lanes=[("ENGINE", 2, 0.5), ("EXTERNAL PROOF", 1, 0.3), ("PARTNER", 1, 0.25)],
                  played=0, completed=0, shared=0)

n = []
row_engine = [("Core Prototypes", "CORE\nPROTOTYPES", "▦", 1, "FORTNIGHTLY REVIEW"),
              ("Perf + Interface", "PERF + INTERFACE\nITERATION", "◎", 1, "NO FALSE FEATURE DEADLINE"),
              ("Production Use", "PRODUCTION\nUSE", "◩", 1, "ENGINE UNDER LOAD"),
              ("Engine Holds Up", "ENGINE HOLDS\nUP?", "✓", 1, "LEADING INDICATOR")]
row_ext = [("Jam Prep", "JAM PREP", "▤", 1, "RULES + OUTREACH"),
           ("Hosted Jam 2027", "HOSTED JAM", "◆", 1, "≥3 ENTRANTS"),
           ("External Jam 2027", "EXTERNAL JAM", "◆", 4, "NO HOME-FIELD ADVANTAGE"),
           ("External Reception", "EXTERNAL\nRECEPTION", "↗", 4, "PLATFORM SIGNAL")]
row_partner = [("RFP Issued", "RFP ISSUED", "R", 2, "PARTNER TRACK"),
               ("Grants + Expressions", "GRANTS +\nEXPRESSIONS", "◇", 2, "PARTNER TRACK"),
               ("LOI / MOU", "LOI / MOU\nCONVERSION", "◇", 2, "PARTNER TRACK"),
               ("Partner Status", "PARTNER\nSTATUS", "R", 2, "PARTNER TRACK")]
XQ = [300, 610, 950, 1290]
for i, (title, disp, glyph, state, sub) in enumerate(row_engine):
    n.append(node(b, "Y_e%d" % i, title, (XQ[i], 306), display=disp, glyph=glyph,
                  state=state, kind=2, category=0, radius=1.1, sub=sub,
                  head="ENGINE + INTERFACE",
                  detail="Quarterly engine and interface workstream for %s." % disp.replace("\n", " ").lower()))
for i, (title, disp, glyph, state, sub) in enumerate(row_ext):
    kw = dict(display=disp, glyph=glyph, state=state, kind=2, category=2,
              radius=1.05, sub=sub, head="EXTERNAL PROOF",
              detail="External-proof workstream: %s." % disp.replace("\n", " ").lower())
    if title == "Hosted Jam 2027":
        kw.update(activity=g1_act, activity_count=3, halo=True)
    n.append(node(b, "Y_x%d" % i, title, (XQ[i], 478), **kw))
for i, (title, disp, glyph, state, sub) in enumerate(row_partner):
    n.append(node(b, "Y_p%d" % i, title, (XQ[i], 636), display=disp, glyph=glyph,
                  state=state, kind=2, category=3, radius=0.9, sub=sub,
                  head="PARTNER TRACK · LONGER CLOCK",
                  detail="Partner activity runs on its own clock rather than as an engine dependency."))
n.append(node(b, "Y_gate", "Gate 1", (1600, 452), display="GATE 1", glyph="△",
              state=1, kind=2, category=2, radius=1.36, halo=True,
              sub="ESTABLISH STUDIO OR WIND DOWN", head="PREPRODUCTION → PRODUCTION DECISION",
              detail="The platform advances only if the engine held up in production use and the external proof found genuine reception.",
              detail2="Partner engagement is reviewed here, but on its own longer clock rather than disguised as an engine dependency.",
              tags=["ESTABLISH STUDIO", "PIVOT", "WIND DOWN"],
              activity=g1_act, activity_glyph="?", action="VIEW CRITERIA"))

e = []
for row, tone in [("Y_e", 0), ("Y_x", 2), ("Y_p", 3)]:
    names = {"Y_e": [r[0] for r in row_engine], "Y_x": [r[0] for r in row_ext],
             "Y_p": [r[0] for r in row_partner]}[row]
    for i in range(3):
        e.append(edge(b, "%s_%d" % (row, i), names[i], names[i + 1],
                      tone=tone, estimated=(row == "Y_p" and i == 2)))
e.append(edge(b, "Z1", "Engine Holds Up", "Gate 1", tone=0))
e.append(edge(b, "Z2", "External Reception", "Gate 1", tone=0))
e.append(edge(b, "Z3", "Partner Status", "Gate 1", tone=1, estimated=True))

cats = [
    lane(b, "Q1", "Q1", (270, 190), NEUTRAL, GREY_EDGE, cat=0, style=1, mark=False),
    lane(b, "Q2", "Q2", (610, 190), NEUTRAL, GREY_EDGE, cat=1, sep=445.0, style=1, mark=False),
    lane(b, "Q3", "Q3", (950, 190), NEUTRAL, GREY_EDGE, cat=2, sep=785.0, style=1, mark=False),
    lane(b, "Q4", "Q4", (1290, 190), NEUTRAL, GREY_EDGE, cat=3, sep=1125.0, style=1, mark=False),
]

write("map_2027_frontier.tres", b, [
    ("placements", array("1_entry", n)),
    ("categories", array("2_category", cats)),
    ("edges", array("3_edge", e)),
    ("breadcrumb", '"FRONTIER MAP  /  2027 PREPRODUCTION"'),
    ("fog_teaser_position", "Vector2(1815, 452)"),
    ("panel_rect", "Rect2(70, 760, 1780, 200)"),
    ("field_span", "Vector2(230, 700)"),
    ("caption_position", "Vector2(70, 742)"),
    ("title", '"FRONTIER MAP"'), ("eyebrow", '"QUANTUM HORIZON"'),
    ("route_caption", '"QUARTERLY MACRO WORKSTREAMS ONLY · PRODUCTIZATION AND THE UGC TAIL STAY FOGGED BEYOND GATE 1"'),
    ("launch_label", '"INSPECT"'),
    ("legend_labels", psa(["PLAYED", "ACTIVE", "AVAILABLE", "RESEARCH", "LATER / FOG"])),
    ("gate_legend_label", '"GATE ESSENTIAL"'),
])
print("done")
