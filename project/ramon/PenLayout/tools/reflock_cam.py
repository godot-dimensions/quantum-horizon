"""The pinhole camera the ref stage renders with, in Python (PenLayout/PLAN_REF_LOCK.md step 4).

Godot's Camera4D, for points in its own slice (w = 0), is a plain pinhole: it looks down its local
-Z with +Y up, and a focal length f (in units of half the viewport's height, the default
KEEP_HEIGHT aspect) puts a point at

    u = W/2 + f * (H/2) * x_c / -z_c
    v = H/2 - f * (H/2) * y_c / -z_c

where (x_c, y_c, z_c) is the point in the camera's frame. ref_stage_runner.gd prints the engine's
own projection of named markers (Camera4D.world_to_viewport) so this can be checked to the pixel.

A camera here is yaw, pitch, roll (radians), its position, and its focal length. Yaw 0 looks north
(-Z), positive yaw turns to the west (toward -X); pitch is positive looking down.
"""
import json
import math
import numpy as np


def axes(yaw, pitch, roll=0.0):
	"""The camera's x (right), y (up), z (back) axes in the world."""
	d = np.array([-math.sin(yaw) * math.cos(pitch), -math.sin(pitch), -math.cos(yaw) * math.cos(pitch)])
	z = -d
	x = np.array([math.cos(yaw), 0.0, -math.sin(yaw)])
	y = np.cross(z, x)
	if roll:
		c, s = math.cos(roll), math.sin(roll)
		x, y = c * x + s * y, -s * x + c * y
	return x, y, z


def project(points, pos, yaw, pitch, roll, focal, width, height, cx=None, cy=None):
	"""Pixel positions of world points (N x 3) through the camera."""
	x, y, z = axes(yaw, pitch, roll)
	R = np.stack([x, y, z])  # rows: camera axes
	pc = (np.asarray(points, float) - np.asarray(pos, float)) @ R.T
	depth = -pc[:, 2]
	F = focal * height / 2.0
	cx = width / 2.0 if cx is None else cx
	cy = height / 2.0 if cy is None else cy
	u = cx + F * pc[:, 0] / depth
	v = cy - F * pc[:, 1] / depth
	return np.stack([u, v], axis=1), depth


def look_from(target, yaw, pitch, distance):
	"""The position a camera with this yaw and pitch sits at to look at target from distance."""
	x, y, z = axes(yaw, pitch)
	return np.asarray(target, float) + z * distance


def preset_view(pos, yaw, pitch, roll, focal, width, height):
	x, y, z = axes(yaw, pitch, roll)
	return {"width": int(width), "height": int(height), "position": [float(c) for c in pos],
		"x_axis": [float(c) for c in x], "y_axis": [float(c) for c in y], "z_axis": [float(c) for c in z],
		"focal": float(focal), "yaw": float(yaw), "pitch": float(pitch), "roll": float(roll)}


def write_presets(path, views, background, player=None, markers=None):
	data = {"background": [int(c) for c in background], "views": views}
	if player is not None:
		data["player"] = [float(c) for c in player]
	if markers:
		data["markers"] = {k: [float(c) for c in v] for k, v in markers.items()}
	with open(path, "w", encoding="utf-8", newline="\n") as f:
		json.dump(data, f, indent=1)
