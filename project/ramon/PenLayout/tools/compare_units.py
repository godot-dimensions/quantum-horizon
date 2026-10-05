"""Compares two dumps of _verify_units_runner.gd: nothing may have moved in the world, and every link
must still point at the same node.

    python compare_units.py <before.txt> <after.txt>
"""
import sys


def load(path):
	nodes, links = {}, {}
	for line in open(path, encoding="utf-8"):
		parts = line.rstrip("\n").split("\t")
		if parts[0] == "N":
			nodes[parts[1]] = (parts[2], parts[3])
		elif parts[0] == "L":
			links[(parts[1], parts[2])] = parts[3]
	return nodes, links


def close(a, b, eps=1e-3):
	fa = [float(x) for x in a.replace("|", ",").split(",")]
	fb = [float(x) for x in b.replace("|", ",").split(",")]
	return all(abs(x - y) <= eps for x, y in zip(fa, fb))


def main():
	bn, bl = load(sys.argv[1])
	an, al = load(sys.argv[2])
	bad = 0
	for k in sorted(set(bn) | set(an)):
		if k not in an:
			print("GONE   node %s" % k); bad += 1
		elif k not in bn:
			print("NEW    node %s" % k); bad += 1
		elif not close(bn[k][0], an[k][0]) or not close(bn[k][1], an[k][1]):
			print("MOVED  %s: %s -> %s" % (k, bn[k][0], an[k][0])); bad += 1
	for k in sorted(set(bl) | set(al)):
		b, a = bl.get(k), al.get(k)
		if b != a:
			print("LINK   %s.%s: %s -> %s" % (k[0], k[1], b, a)); bad += 1
	print("COMPARE %s: %d nodes, %d links, %d differences" % ("SAME" if bad == 0 else "DIFFERENT", len(an), len(al), bad))
	sys.exit(0 if bad == 0 else 1)


if __name__ == "__main__":
	main()
