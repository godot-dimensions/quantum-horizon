class_name CloudsTestRig
extends Node4D
## Minimal stand-in for VoxelTerrain4D's public interface, exposing only
## what clouds_layer.gd actually reads (grid_size directly, cell_size
## optionally via an "in" check, and an optional "Ground" child it's fine
## never finding) - lets CloudsLayer run completely unmodified in a scene
## with no real terrain at all. Exists for clouds_test.tscn: fast, isolated
## iteration on the clouds shader/mesh without paying VoxelTerrain4D's
## ~15-30s brick generation cost on every single test run.
##
## Clouds must still be parented directly under a node like this one with
## an identity basis - see clouds_layer.gd's own header - so right-drag
## rotation (via VoxelHoverCamera4D's rig_path pointing here) drives the
## Cross-Section slicing exactly the way it does on the real Terrain node.

@export var grid_size: int = 96
@export var cell_size: float = 1.0
