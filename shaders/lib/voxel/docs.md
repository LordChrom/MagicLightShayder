# Terminology

- Direction - The 6 main directions along the positive or negative extents of each axis.
- Voxel - you know what a voxel is. In this project specifically, it refers to all the data associated with one voxel position
- Light Sample - a light sample stores information regarding the light entering a voxel from a particular source through a specific face
- Section - refers to a physical area of the game and all the data associated with it,
  including block voxel maps and light samples.
- Area - refers to a contiguous collection of sections.
- Zone - refers to one portion of the data in an area, mapped the entirety of the physical space, 
  but not all types of data. Eg: the light samples in an area in the east direction on the first layer
- Layer - Each zone stores only one sample per voxel, so adding layers allows multiple samples in the same position and direction
- Boundary - zones and areas, in memory, have an additional voxel in every direction to represent incoming light from bordering areas
- - eg a 64x64x64 area has 66x66x66 representation in memory, with area pos = -1 or 64 (mem pos 0 or 65) being the boundary

Currently a section is 16x16x16 voxels, and an area is 4x4x4 sections or 64x64x64 voxels. This is subject to change

# Spaces
| space | axes  | range                        | unit scale | 
|:------|:------|:-----------------------------|:-----------|
| World | mc    | inf                          | block      |
| Area  | mc    | [-1,AREA_SIZE]               | voxel      |
| Zone  | light | [-1,AREA_SIZE]               | voxel      |
| Mem   | mixed | xy=[0,AREA_SIZE+1],z=[0,TBD) | mixed      |

- world space is always in floats, mem space is always ints, zone and area space are usually ints
- area positions may be bundled with a 4th element representing which area number the position belongs to
- the spaces are all continuous mapping from themself to the world, except for mem space
- mem space, per-element, will map boundary positions 1:1, but internal positions will be shuffled around relative to
- area/zone space to allow the samples to be moved without mass copying.
- the TBD max size of mem's z will be (AREA_SIZE+2)\*6\*VOX_LAYERS\*(max number of zones). depends on me figuring out a good way to resize the custom uimage3d in iris
- axes in zone space are represented as a,b,L, with L positive in the direction light travels. examples are shown in the table
- - Yes it fails to preserve handedness, no that doesnt matter here

| direction | number | a,b,L  |
|-----------|--------|--------|
| -x        | 0      | y,z,-x |
| +x        | 1      | y,z,x  |
| -y        | 2      | z,x,-y |
| +y        | 3      | z,x,y  |
| -z        | 4      | x,y,-z |
| +z        | 5      | x,y,z  |

# light types
- 0: no lighting
- 1: sunlight
- 2: steady blocklight
- 3: pulsating blocklight (like amethyst crystals)
- 4: analog flickering blocklight (like fire, trial spawners)

# Colortexes
- 0: opaque albedo & main output
- 1: transparent albedo
- 2: normals
- 3: opaque materials info (labpbr specular)
- 5: vanilla fallback (optional)
- 6: multiplicative lighting
- 7: additive light
- 15: debug (optional)


# General TODO List
- Merge adjacent unoccluded lights of same type
- fix corner cases of occlusion system
- ambient light
- maybe try switching from fixed number of samples per direction to fixed number per voxel + list of relevant samples per voxel
- make bloom that's not awful
- think of a name for approach to lighting
- subsurface scattering
- sky stuff & clouds
- timekeeping method that advances proportionally to game ticks regardless of world time
- PBR
- reflections
- water stuff
- biome colored fog
- make sun shadows better & respect angles
- redo block.properties