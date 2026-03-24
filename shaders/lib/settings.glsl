//#define DEBUG_OCCLUSION_MAP
#define UNFLIP_DEBUG_MAPS
#define DEBUG_OUTLINE_WIDTH 0.04 //[0 0.01 0.02 0.04 0.08 0.16]
#define DEBUG_AXIS -1 //[-1 0 1 2 3 4 5]
#define DEBUG_SCALE 1.0 //[1.0 0.5 0.25]
#define DEBUG_UPDATES_INTENSITY 0.05 //[0.01 0.03 0.05 0.07 0.1 0.2 0.3 0.4 0.6]
//#define DEBUG_DECOLOR
#define DEBUG_GRID_OUTLINE 0 //[0 1 2 4 8 16]
//#define EVERYTHING_IS_THE_SUN
//#define KEEP_FULLY_OCCLUDED_SAMPLES
#define EVERYTHING_FACING_SRC 0 //[0 1 2]
#define DEBUG_SHOW_UPDATES -1 //[-1 0 1]
#define UNOCCLUDED_INTO_BLOCKS
#define LIGHT_SOURCES_BLOCK_CENTERIC

#define FLICKER_INTENSITY 0.5
#define BLOCK_LIGHT_STRENGTH 3
#define MIN_COLUMNATION 0.7
#define MAX_LIGHT_STRENGTH 1.5
#define MIN_LIGHT_AMOUNT 0.1
#define PENUMBRA_WIDTH 0.04 //[0.01 0.015 0.02 0.03 0.04 0.06 0.08 0.12 0.16 0.2 0.3]
#define PENUMBRAS_ENABLED

#define VOX_LAYERS 2 //[1 2 3]

#define COLORED_TRANSLUCENTS
//#define PRIDE_LIGHTING

//TODO probably remove, after speeding up isLit this seems just like, unambigously worse
//#define SHORTLISTED_COMPARISON
#define AXES_INORDER
#define PARALLEL_UNPACK


#define SECTION_SIZE 16
#define UPDATE_STRIDE 16 //[16 8]
#define AREA_WIDTH_SECTIONS 4
const uvec3 AREAS = ivec3(1,1,1);


const uint NUM_AREAS = AREAS.x*AREAS.y*AREAS.z;

const int SECTIONS_PER_AREA = AREA_WIDTH_SECTIONS*AREA_WIDTH_SECTIONS*AREA_WIDTH_SECTIONS;
const int AREA_SIZE =  AREA_WIDTH_SECTIONS*SECTION_SIZE;
const int AREA_POS_MASK = AREA_SIZE-1;

#define AREA_SIZE_MEM 66 //Update Manually

//const int SECTIONS_PER_AREA = AREA_WIDTH_SECTIONS*AREA_WIDTH_SECTIONS*AREA_WIDTH_SECTIONS;
const int AREA_WIDTH_SECTIONS_SHIFT = int(log2(AREA_WIDTH_SECTIONS));
const int AREA_SHIFT = 3*AREA_WIDTH_SECTIONS_SHIFT;
const int ZONE_OFFSET = AREA_SIZE+4;
const int AREA_COUNT = 1;
const int AREA_HALF_SIZE = int(AREA_SIZE*0.5);

#define LOCAL_SIZE_Z 1

//#define VOX_SIZE 66
//#define VOX_SIZE_BIG 840

const vec3 testVoxOriginOffset = vec3(-16,48,-16);
const vec3 voxWorldSize = vec3(AREA_SIZE);
const vec3 sectionCount = vec3(2);

//a section is 16x16x16 voxels
//a zone is a group of up to 4x4x4 sections, specifically limited to 1 axis/layer where it comes to faces

#if DEBUG_AXIS>=0
const uint debugAxisNum = DEBUG_AXIS;
#endif


const float voxelDistance = 160.0;
const float shadowDistance = 160.0;
const int shadowMapResolution = 1;

#ifdef KEEP_FULLY_OCCLUDED_SAMPLES
#undef IrisOptionsWontShowThisOtherwiseBecauseItsInAPreprocessorThingOtherThanIfdefOrIfndef
#endif