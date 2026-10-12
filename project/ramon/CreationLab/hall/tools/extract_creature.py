"""Lifts one creature out of a bigger scene into a scene of its own (Creation Lab v2, 9 Oct 2026).

The brachiosaurus lives in Model/rigged_creature_ramon.tscn beside Trym's creature, the owl and two chickens;
the horse in Model/animation_test.tscn with its sun and ground. The creature hall wants just the animal, so
this copies a node and everything under it, with only the resources they use (followed through sub-resources),
under a new root Node4D: the creature keeps its own transform (its scale, its height off the ground) except
its place on the floor, so the hall puts the root wherever a pedestal is.

    python extract_creature.py SOURCE.tscn NODE/PATH OUT.tscn ROOT_NAME

Reads only; writes OUT (refuses to overwrite it).
"""
import os
import re
import sys


def sections(text):
    """The file's [..] sections in order, each its header line and its body."""
    parts = re.split(r"(?m)^(?=\[)", text)
    return [p for p in parts if p.strip()]


def node_path(head):
    m = re.match(r'\[node name="([^"]+)"(?: type="[^"]+")?(?: parent="([^"]*)")?', head)
    if not m:
        return None, None
    name, parent = m.group(1), m.group(2)
    if parent is None:
        return name, None
    return (name if parent == "." else parent + "/" + name), parent


def main():
    src, want, out, root_name = sys.argv[1:5]
    if os.path.exists(out):
        sys.exit("refusing to overwrite " + out)
    secs = sections(open(src, encoding="utf-8").read())
    ext = {}
    sub = {}
    nodes = []
    for s in secs:
        head = s.split("\n", 1)[0]
        if head.startswith("[ext_resource"):
            ext[re.search(r'id="([^"]+)"', head).group(1)] = s
        elif head.startswith("[sub_resource"):
            sub[re.search(r'id="([^"]+)"', head).group(1)] = s
        elif head.startswith("[node"):
            full, parent = node_path(head)
            if full == want or (full and full.startswith(want + "/")):
                nodes.append((full, parent, s))
    if not nodes:
        sys.exit("no node " + want)
    # Resources the nodes use, followed through sub-resources.
    need_ext, need_sub = set(), set()
    todo = [n[2] for n in nodes]
    while todo:
        body = todo.pop()
        for i in re.findall(r'ExtResource\("([^"]+)"\)', body):
            need_ext.add(i)
        for i in re.findall(r'SubResource\("([^"]+)"\)', body):
            if i not in need_sub and i in sub:
                need_sub.add(i)
                todo.append(sub[i])
    leaf = want.split("/")[-1]
    out_nodes = ['[node name="%s" type="Node4D"]\n\n' % root_name]
    for full, parent, s in nodes:
        head, body = s.split("\n", 1)
        if full == want:
            head = re.sub(r' parent="[^"]*"', ' parent="."', head)
            # Its place on the floor goes; its height and scale stay.
            body = re.sub(r"(?m)^position = Vector4\(([^,]+), ([^,]+), ([^,]+), ([^)]+)\)$",
                          lambda m: "position = Vector4(0, %s, 0, 0)" % m.group(2).strip(), body)
        else:
            rel = parent[len(want):].lstrip("/")
            head = re.sub(r' parent="[^"]*"', ' parent="%s"' % (leaf + ("/" + rel if rel else "")), head)
        out_nodes.append(head + "\n" + body)
    keep_ext = [ext[i] for i in ext if i in need_ext]
    keep_sub = [sub[i] for i in sub if i in need_sub]
    steps = len(keep_ext) + len(keep_sub) + 1
    text = "[gd_scene load_steps=%d format=3]\n\n" % steps + "".join(keep_ext) + "".join(keep_sub) + "".join(out_nodes)
    text = re.sub(r"\n{3,}", "\n\n", text)
    open(out, "w", encoding="utf-8", newline="\n").write(text)
    print("%s: %d nodes, %d external and %d sub resources" % (out, len(nodes), len(keep_ext), len(keep_sub)))


if __name__ == "__main__":
    main()
