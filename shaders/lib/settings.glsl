#ifndef SETTINGS_GLSL
#define SETTINGS_GLSL

//#define DEBUG_OCCLUSION_MAP
#define UNFLIP_DEBUG_MAPS
#define DEBUG_OUTLINE_WIDTH 0.04 //[0 0.01 0.02 0.04 0.08 0.16]
#define DEBUG_AXIS -1 //[-1 0 1 2 3 4 5]
#define DEBUG_UPDATES_INTENSITY 0.2 //[0.01 0.03 0.05 0.07 0.1 0.2 0.3 0.4 0.6 0.8 1.0]
//#define DEBUG_DECOLOR
#define DEBUG_GRID_OUTLINE 0 //[0 1 2 4 8 16]
//#define EVERYTHING_IS_THE_SUN
//#define KEEP_FULLY_OCCLUDED_SAMPLES
#define EVERYTHING_FACING_SRC 0 //[0 1 2]
#define DEBUG_SHOW_UPDATES -1 //[-1 0 1]
#define UNOCCLUDED_INTO_BLOCKS
#define LIGHT_SOURCES_BLOCK_CENTERIC
//#define DEBUG_WHITEN
#define DEBUG_WHITE_LEVEL 0.5 //[0 0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1]

#define DEBUG_SPECIAL_VIEW -1 //[-1 0 1 2 3 4 5 6 7 8 9 100 101 102 103 104 105]

#define FLICKER_INTENSITY 0.5
#define BLOCK_LIGHT_STRENGTH 3
#define MIN_COLUMNATION 0.7
#define MAX_LIGHT_STRENGTH 1.5
#define MIN_LIGHT_AMOUNT 0.1
#define PENUMBRA_WIDTH 0.04 //[0.01 0.015 0.02 0.03 0.04 0.06 0.08 0.12 0.16 0.2 0.3]
#define PENUMBRAS_ENABLED

#define VOX_LAYERS 2 //[1 2 3 4]

#define COLORED_TRANSLUCENTS
//#define PRIDE_LIGHTING

//TODO probably remove, after speeding up isLit this seems just like, unambigously worse
//#define SHORTLISTED_COMPARISON
//#define AXES_INORDER
//#define WAVES_INORDER
#define PARALLEL_UNPACK

#define VOLUMETRIC_FOG_SAMPLES 2 //[0 1 2 4 8 16 32]
#define FOG_DENSITY 0.02 //[0.01 0.02 0.03 0.04 0.06 0.08 0.12 0.16 0.24 0.32]
#define FOG_BRIGHTNESS 0.6 //[0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1.0]
#define MAX_FOG_DEPTH 128 //[1 2 4 8 16 32 48 64 96 128 256 512]
#define FOG_DITHER_METHOD 32 //[1 2 4 8 16 32]
#define FOG_TEMPORAL_NOISE
//#define FOG_FILTER
#define FOG_BLUR 2 //[0 1 2]
#define LIGHTS_PER_FOG_SAMPLE 1 //[0 1 2 3 4]
#define FOG_RANDOM_LESSER_SOURCE

#define LIGHTING_RENDERSCALE 1 //[0.01 0.1 0.15 0.2 0.25 0.3333 0.5 0.625 0.6666 0.75 0.8 0.9 1]
#define BLOOM_INTENSITY 1.0 //[0.25 0.5 0.75 1.0 1.5 2.0 3.0]
#define BLOOM_WIDTH 2.0 //[0.5 1.0 1.5 2.0 3.0 4.0]
#define BLOOM_LEVEL 0 //[0 1 2]
#define BLOOM_SMART

#define TONEMAP_METHOD 0 //[-1 0 1 2]


#define NUM_CASCADES 6 //[1 2 3 4 6 8 12 16]
#define MIN_SCALE 1 //[0.5 1 2]

#define UPDATE_STRIDE 16 //[2 4 8 16 32]
#define SECTION_SIZE 16 //[]
#define AREA_WIDTH_SECTIONS 4 //[]

#define MAX_LIGHT_TRAVEL 64 //[-1 0 1 2 4 8 16 24 32 64 128 256 512 1024]

#define LOCAL_SIZE_Z 1

#define VANILLA_FALLBACK
#define TRANSLUCENT_SEPARATE_BUFFER

#define GATEWAYS_IN_GBUFFER

/////
#if LIGHTS_PER_FOG_SAMPLE>=VOX_LAYERS
#undef FOG_RANDOM_LESSER_SOURCE
#endif

#define MAX_SCALE (MIN_SCALE*(1<<(NUM_CASCADES-1)))

///// The following to be copy pasted into shaders.properties

#define AREA_SIZE (AREA_WIDTH_SECTIONS*SECTION_SIZE)

#if AREA_SIZE == 32
    #define AREA_SIZE_MEM 34
#elif AREA_SIZE == 64
    #define AREA_SIZE_MEM 66
#else
#endif

#define MEM_SIZE_BIG_EXACT (AREA_SIZE_MEM*6*VOX_LAYERS*NUM_CASCADES)

#if MEM_SIZE_BIG_EXACT  <=256
    #define MEM_SIZE_BIG  256
#elif MEM_SIZE_BIG_EXACT<=512
    #define MEM_SIZE_BIG  512
#elif MEM_SIZE_BIG_EXACT<=1024
    #define MEM_SIZE_BIG  1024
#elif MEM_SIZE_BIG_EXACT<=2048
    #define MEM_SIZE_BIG  2048
#elif MEM_SIZE_BIG_EXACT<=4096
    #define MEM_SIZE_BIG  4096
#else
    #define MEM_SIZE_BIG 8192
#endif

#define WORLD_MEM_SIZE_BIG_EXACT (AREA_SIZE_MEM*NUM_CASCADES)

#if WORLD_MEM_SIZE_BIG_EXACT  <=64
    #define WORLD_MEM_SIZE_BIG  64
#elif WORLD_MEM_SIZE_BIG_EXACT<=128
    #define WORLD_MEM_SIZE_BIG  128
#elif WORLD_MEM_SIZE_BIG_EXACT<=256
    #define WORLD_MEM_SIZE_BIG  256
#elif WORLD_MEM_SIZE_BIG_EXACT<=512
    #define WORLD_MEM_SIZE_BIG  512
#elif WORLD_MEM_SIZE_BIG_EXACT<=1024
    #define WORLD_MEM_SIZE_BIG  1024
#elif WORLD_MEM_SIZE_BIG_EXACT<=2048
    #define WORLD_MEM_SIZE_BIG  2048
#elif WORLD_MEM_SIZE_BIG_EXACT<=4096
    #define WORLD_MEM_SIZE_BIG  4096
#else
#define WORLD_MEM_SIZE_BIG 8192
#endif

#ifdef BLOOM_SMART
#if LIGHTING_RENDERSCALE<1
    #if BLOOM_LEVEL==1
        #define BLOOM_LEVEL 2
    #elif BLOOM_LEVEL==0
        #define BLOOM_LEVEL 1
    #endif
#endif
#endif
/////



const int SECTIONS_PER_AREA_XY = AREA_WIDTH_SECTIONS*AREA_WIDTH_SECTIONS;

#ifdef WAVES_INORDER
const int SECTIONS_PER_AREA_Z = 1;
#else
const int SECTIONS_PER_AREA_Z = AREA_SIZE/UPDATE_STRIDE;
#endif
const int AREA_POS_MASK = AREA_SIZE-1;


//const int SECTIONS_PER_AREA = AREA_WIDTH_SECTIONS*AREA_WIDTH_SECTIONS*AREA_WIDTH_SECTIONS;
const int AREA_WIDTH_SECTIONS_SHIFT = int(log2(AREA_WIDTH_SECTIONS));
const int AREA_SHIFT = 3*AREA_WIDTH_SECTIONS_SHIFT;
const int ZONE_OFFSET = AREA_SIZE_MEM;
const int AREA_OFFSET = AREA_SIZE_MEM;
const int AREA_COUNT = 1;
const int AREA_HALF_SIZE = int(AREA_SIZE*0.5);


//#define AREA_SIZE_MEM 66
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
const float translucentPrecedenceCutoff = 0.9;

#if BLOOM>0
#ifdef KEEP_FULLY_OCCLUDED_SAMPLES
#ifdef TRANSLUCENT_SEPARATE_BUFFER
#undef IrisOptionsWontShowThisOtherwiseBecauseItsInAPreprocessorThingOtherThanIfdefOrIfndef
#endif
#endif
#endif

#endif