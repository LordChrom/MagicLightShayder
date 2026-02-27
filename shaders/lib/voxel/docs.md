# Terminology

- a "section" refers to a physical area of the game and all the data associated with it,
  including block voxel maps and light samples, sized 16x16x16 blocks
- an "area" refers to a colection of sections, currently 4x4x4 sections or 64x64x64 blocks
- a "zone" refers to one portion of the data in an area, mapped the entirety of the physical space, 
  but not all types of data. Eg: the light samples in an area in the east direction on the first layer
- a "layer" refers to the fact that there might be multiple samples for a given face.
  each face sample only has one space in memory a single zone, so the additional samples are stored in another layer in another zone

zones and areas in memory, are laid out such that they are 2 extra on each axis,
eg a zone in memory is 66x66x66, with 1-64 representing positions 0-63 of the area

areas and sections share axes with world space, zones/layers have a different set of axis.
each section, zone, and area, all have their own origins 

# light types
- 0: no lighting
- 1: sunlight
- 2: steady blocklight
- 3: pulsating blocklight (like amethyst crystals)
- 4: analog flickering blocklight (like fire, trial spawners)
