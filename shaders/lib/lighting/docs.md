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

By default a section is 16x16x16 voxels, and an area is 4x4x4 sections or 64x64x64 voxels, but this can be changed



# Spaces
| space | axes  | range                        | unit scale | 
|:------|:------|:-----------------------------|:-----------|
| World | mc    | inf                          | block      |
| Area  | mc    | [0,AREA_SIZE-1]              | voxel      |
| Zone  | light | [0,AREA_SIZE-1]              | voxel      |
| Mem   | mixed | xy=[0,AREA_SIZE-1],z=[0,TBD) | mixed      |

- world space is always in floats, mem space is always ints, zone and area space are usually ints
- area positions may be bundled with a 4th element representing which area number the position belongs to
- the spaces are all continuous mapping from themself to the world, except for mem space
- mem space will be shuffled around relative to area/zone space to allow the area to be moved without mass copying.
- the TBD max size of mem's z will be (AREA_SIZE)\*6\*VOX_LAYERS\*(max number of zones). depends on me figuring out a good way to resize the custom uimage3d in iris
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
- 1:
- 2: steady blocklight
- 3: pulsating blocklight (like amethyst crystals)
- 4: analog flickering blocklight (like fire, trial spawners)



# Colortexes
| format  | num | purpose                      | scale | clear |
|---------|-----|------------------------------|-------|-------|
|         | 0   | main output                  |       |       |
| RGBA8   | 1   | albedo                       |       |       |
| RGBA8   | 2   | normals                      |       |       |
| RGBA8   | 3   | transparent abledo           |       | y     |
|         | 4   |                              |       |       |
|         | 5   |                              |       |       |
| RGB16F  | 6   | multiplicative lighting      | y     |       |
| RGBA16F | 7   | additive light               | y     |       |
| RGBA8UI | 8   | Materials                    | y     | y     |
| R32F    | 9   | prev frame depth             |       | n     |
| RGB16F  | 10  | multiplicative accumulation. |       | n     |
| RGBA16F | 11  | additive accumulation.       |       | n     |
| RG16F   | 12  | DoF stuff                    |       |       |
| RGBA16F | 13  | Downsampling stuff           |       |       |
| RGBA8   | 14  | temporary                    |       |       |
|         | 15  |                              |       |       |
|         | 19  | debug (optional)             | y     |       |

- albedo.a is 1 exclusively for pre-lit geometry
- normals.a is 0 for solid, 0.5 for hand, 1 for translucent

# Layouts
### Block.properties
- 8 bits unused
- 2 bits opacity type (0 is air, 1 is unused, 2 is full opacity, 3 is shaped opacity)
- 6 bits light ID (also hardcoded subsurface info)

//fences, panes, walls, stairs/slabs, layers, trapdoors,
//rods, chests
//fence gates, signs, torches, pots, buttons, levers, plants, anvils, rails, banners

### Voxel map image storage layout
//
- 4: Age                      (could be separated
- 6: blockage directions
- 1: translucent              (partially redundant now)
- 1: opaque
- 4: emission intensity
- 16: blockID

### Light sample
Attributes
- vec3 color
- vec3 lightTravel,   In zone space. the displacement from the light source voxel center to the sample's voxel center
- uint type
- uint flags          see below
- occlusion info      see below

Flags
- 6 bits currently used only for DEBUG_SHOW_UPDATES
- 1 bit unused
- 1 bit for if its in a translucent

Packing
- x is 2x7 a,b of travel, 1x6 L of travel, 1x8 flags, 1x4 light type
- y is 3x8 color, 8 free
- z is occlusion data
- w is currently free, probably more occlusion data in the future

### Occlusion data
Attributes
- vec2 occlusionRay           ray to corner of occlusion, range [0,1], sign implicitly same as lightTravel.xy
- uint occlusionMap           quadrants in which occlusion occurs, lit if 1, bits in order of most significant to least, represent quadrants with (+,+), (-,+), (+,-), (-,-) signs for a and b, multiplied by signs of lightTravel.xy.
- float occlusionHitDistance  distance from the light source to the source of occlusion, for penumbra sharpness

Packing
- 2x8 occlusion ray (b then a), 1x12 occlusion hit distance, 4x1 occlusion map

# Programs
### setup & begin
- currently unused
### shadowcomp
- 1: covers the gaps in cascaded shadows caused by geometry that straddles the border
### prepare
- 0: voxel map cleaner & expirer
- 3: flood shadow seam filler
- 10-17: flood shadow lighting
- 20: basic floodfill lighter & filler
### deferred
- 1: main lighting for solid terrain
- 2: SSAO filter to reeduce noise
### composite
- 2: volumetric fog
- 5: depth Hi-z, disabled & unused
- 6-8: hq fog blur & (bad) bloom
- 9: reflections if subject to blur, probably can move or remove
- 10: cheap fog blur
- 11: reflections if not subject to blur
- 30: taa accumulation
- 50: combination of lighting with terrain
- 84: DoF setup
- 85: (csh) Dof main work,
- 85: (fsh) DoF combination
- 90-95: Old DoF, probably can remove once new DoF is polished
- 99: Debug views

# General TODO List
### Needs fixing
- reflections when view bobbing
- POM on non-square surfaces
- voxelizing end gates
- subsurface on lava
- other subsurface edge cases (directly contacting light source)
- shadowmap light leak underground (esp for subsurface)
- reflections secondary bouncing on translucent

### Needs Improvement
- shadowmap sun shadows
- TAA performance
- proper system for unlit geometry
- resolution scaling DoF
- enchant glint

### Necessary additions
- water waves
- multiple occlusion indicators per sample
- ambient light
- Merge adjacent unoccluded lights of same type
- underwater & underlava fog
- biome colored fog
- bloom
- make voxel map a lower bit size
- halftones
- sky stuff & clouds

### Potential additions
- more efficient memory scaling for advanced voxel system
- yet another lighting mode