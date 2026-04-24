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
- 1: sunlight
- 2: steady blocklight
- 3: pulsating blocklight (like amethyst crystals)
- 4: analog flickering blocklight (like fire, trial spawners)



# Colortexes
- 0: opaque albedo & main output
- 1: transparent albedo
- 2: normals
- 3: opaque materials info (labpbr specular)
- 4: transparent materials info (labpbr specular)
- 5: vanilla fallback (optional)
- 6: multiplicative lighting
- 7: additive light
- 10: multiplicative accumulation. w holds prev depth if present (optional)
- 11: additive accumulation. w holds previous depth if 10 not present
- 15: debug (optional)



# Layouts
### Voxel map
- RGB are color (7 bits)
- A, 11 bits, is, from MSB to LSB,
- - 5 bits age tag
- - 4 bits its emission type
- - a bit that's 1 for translucent blocks like stained glass
- - a bit that's 1 for surfaces that block light



### Light sample
- Attributes
- - vec3 color
- - vec3 lightTravel,   In zone space. the displacement from the light source voxel center to the sample's voxel center
- - uint type 
- - uint flags          see below
- - occlusion info      see below

- Occlusion data
- - vec2 occlusionRay           ray to corner of occlusion, range [0,1], sign implicitly same as lightTravel.xy
- - uint occlusionMap           quadrants in which occlusion occurs, lit if 1, bits in order of most significant to least, represent quadrants with
                                (+,+), (-,+), (+,-), (-,-) signs for a and b, multiplied by signs of lightTravel.xy.
- - float occlusionHitDistance  distance from the light source to the source of occlusion, for penumbra sharpness

- Packing
- - x is 2x16 a,b of travel
- - y is 12 free, 1x4 light type, 1x16 z of travel
- - z is 3x8 color, 8 flags
- - w 2x8 occlusion ray (b then a), 1x12 occlusion hit distance, 4x1 occlusion map

- flags
- - 6 bits currently used only for DEBUG_SHOW_UPDATES
- - 1 bit unused 
- - 1 bit for if its in a translucent



# General TODO List
### Needs fixing
- sun shadows
- light source duplication at seams
- seam filler not working due to the voxel split changes

### Needs Improvement
- TAA unoptimized
- proper system for unlit geometry
- SSS
- Emissive
- proper lighting on translucents OR have that part of local fog density system

### Necessary additions
- multiple occlusion indicators per sample
- ambient light
- Merge adjacent unoccluded lights of same type
- underwater & underlava fog
- biome colored fog
- think of a name for approach to lighting
- make bloom that's not awful
- make voxel map a lower bit size
- light sampling from lower cascades when possible
- halftones

### Potential additions
- make pixel locked rendering actually only need one sample per pixel
- redo block.properties
- water stuff
- dither positive/negative axes with TAA on
- reflections
- sky stuff & clouds
- alternate mode using visibility samples rather than the oclusion info
- maybe try switching from fixed number of samples per direction to fixed number per voxel + list of relevant samples per voxel
