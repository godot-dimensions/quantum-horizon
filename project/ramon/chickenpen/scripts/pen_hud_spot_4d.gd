extends RefCounted

## FIRST FREE SPOT, for the HUD panels that are placed rather than anchored (the Lookout card,
## the camera picker, the grass panel). Each gives a short list of places it would like to be,
## best first, and takes the first that sits on the screen and over no other panel - the dial
## counted as the circle it draws, not its square.
##
## WHY (3 Oct, merging the Lookout and the grass into the pen: "check for ... menu locations, fix
## it accordingly"). On a 2560 x 1440 screen at 125% the right column ends where the dial starts:
## the Lookout card hung under the Cinematics card straight across the dial, the camera picker
## sat inside its circle (in the pen before the merge too), and the grass panel, grown tall,
## ran up into the murmuration card. A fixed place right for one window size was wrong for
## another; a list of places, checked against what is actually on screen, is right for both.
##
## Panels that cover the whole screen (the belt's layer, the dialogue boxes) are layers, not
## panels, and are not counted.

## Where [param c] is on the canvas, scale included.
static func rect_of(c: Control) -> Rect2:
	return c.get_global_transform() * Rect2(Vector2.ZERO, c.size)


## What [param c] draws, on the canvas: its drawn_rect() when it has one (the info card, a fixed card inside a much
## larger Control), else its rect.
static func drawn_of(c: Control) -> Rect2:
	if c.has_method("drawn_rect"):
		var d: Rect2 = c.call("drawn_rect")
		return c.get_global_transform() * Rect2(d.position - c.position, d.size)
	return rect_of(c)


## What is already on screen under [param ui], other than [param me] and [param ignore]: a Rect2
## per panel, and the dial as Vector3(centre x, centre y, radius).
static func taken(ui: Node, me: Control, ignore: Array = []) -> Array:
	var out: Array = []
	if ui == null:
		return out
	var screen: Vector2 = me.get_viewport_rect().size
	for child in ui.get_children():
		var c := child as Control
		if c == null or c == me or ignore.has(c) or not c.is_visible_in_tree() or c.modulate.a < 0.05:
			continue
		if c.has_method("dial_circle"):
			out.append(c.call("dial_circle"))
			continue
		# A readout with nothing to say draws nothing (7 Oct: the info card's empty rows, a screen wide, kept the
		# panels out of the room under it).
		if c is Label and (c as Label).text.strip_edges() == "":
			continue
		var r: Rect2 = drawn_of(c)
		if r.size.x < 2.0 or r.size.y < 2.0:
			continue
		if r.size.x > screen.x * 0.9 and r.size.y > screen.y * 0.9:
			continue
		out.append(r)
	return out


## Whether [param r] is on the screen and over none of [param taken].
static func is_free(r: Rect2, taken: Array, screen: Vector2) -> bool:
	if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > screen.x or r.end.y > screen.y:
		return false
	var inner: Rect2 = r.grow(-1.0)
	for t in taken:
		if t is Rect2:
			if inner.intersects(t):
				return false
		else:
			var circle: Vector3 = t
			var near := Vector2(clampf(circle.x, inner.position.x, inner.end.x), clampf(circle.y, inner.position.y, inner.end.y))
			if near.distance_to(Vector2(circle.x, circle.y)) < circle.z:
				return false
	return true


## The first of [param places] (top-left corners) where a panel of [param size] is free. If none
## is - a small window at a big UI size has no room for everything - the one, kept on the screen,
## that covers the least of the rest.
static func first(places: Array, size: Vector2, taken: Array, screen: Vector2) -> Vector2:
	for p in places:
		if is_free(Rect2(p, size), taken, screen):
			return p
	var best := Vector2.ZERO
	var least: float = INF
	for p in places:
		var q: Vector2 = on_screen(p, size, screen)
		var cover: float = covered(Rect2(q, size), taken)
		if cover < least:
			least = cover
			best = q
	return best


## [param p] moved just enough to keep a panel of [param size] on the screen.
static func on_screen(p: Vector2, size: Vector2, screen: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0.0, maxf(screen.x - size.x, 0.0)), clampf(p.y, 0.0, maxf(screen.y - size.y, 0.0)))


## How much of [param taken] the rect [param r] lies over, in square pixels (the dial's circle
## as its square, near enough to choose by).
static func covered(r: Rect2, taken: Array) -> float:
	var total: float = 0.0
	# abs(): with no window (a headless runner) panels measure negative, and Rect2 complains on
	# every call, which filled a three-minute test's log with 600,000 lines.
	r = r.abs()
	for t in taken:
		var other: Rect2
		if t is Rect2:
			other = (t as Rect2).abs()
		else:
			var c: Vector3 = t
			other = Rect2(c.x - c.z, c.y - c.z, c.z * 2.0, c.z * 2.0).abs()
		var cut: Rect2 = r.intersection(other)
		total += maxf(cut.size.x, 0.0) * maxf(cut.size.y, 0.0)
	return total
