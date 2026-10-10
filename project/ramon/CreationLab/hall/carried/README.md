# Carried into the Creation Lab v2 (9 Oct 2026)

From the Voxel Lab, preloads pointed at the Creation Lab's own kit copies, nothing else changed:

- `vl_shimmer_4d.gd` from `VoxelLab/room/vl_shimmer_4d.gd`: the hologram doorway (flash_out / flash_in).
- `vl_load_board.gd` from `VoxelLab/room/vl_load_board.gd`: the loading board.
- `hall_oak_4d.gd` from `chickenpen/scripts/pen_oak_4d.gd`: the pen's oak and its bakes, unchanged.
- `grass/hall_grass_4d.gd`, `grass/hall_grass_lattice.gdshader` (10 Oct, round 3): the pen's grass by way of the Botany Lab's
  copy (`Arboretum/botany_lab/carried/grass/`), on each pedestal deck; what changed is in the script's header.
- `hall_light_editor.gd` (10 Oct, round 3): the Botany Lab's Tab light panel (`Arboretum/botany_lab/room/bl_light_editor.gd`),
  its preloads on the Creation Lab's kit, saving to `hall/creature_hall_lights.cfg`.
- `hall_float_panel_4d.gd` (10 Oct, round 3): the Botany Lab's framed specimen label (`Arboretum/botany_lab/carried/voxel_lab/float_panel_4d.gd`),
  its preloads on the Creation Lab's kit; one at the front of every creature pedestal.
- `hall_dreamer_4d.gd` (10 Oct, round 3): Azathoth, the cave's dreamer (`LabKit/carried/chickenpen/cave/cave_dreamer_4d.gd`), with
  `curl_scale` and `w_follow` added (both off by default); on the technical pedestal where the horse stood.
- `hall_chipmunk_4d.gd` (10 Oct, round 3): the lab's chipmunk (`LabKit/carried/chickenpen/lookout/chipmunk_4d.gd`) with a visible
  tail, sat on its deck, its idle cycle fixed and rounder; the changes are marked THE HALL in it.
