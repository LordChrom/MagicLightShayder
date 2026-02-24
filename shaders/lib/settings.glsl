#define DEBUG_OCCLUSION_MAP
#define UNFLIP_DEBUG_MAPS
#define DEBUG_OUTLINE_WIDTH 0.02 //[0 0.01 0.02 0.04 0.08 0.16]
#define DEBUG_AXIS 5 //[-1 0 1 2 3 4 5]
#define DEBUG_SCALE 1.0 //[1.0 0.5 0.25]


#define VOX_LAYERS 2 //[1 2]



#define SECTION_SIZE 16
#define UPDATE_STRIDE 16
#define SECTIONS_PER_ZONE 64

const int ZONE_WIDTH_SECTIONS = int(pow(SECTIONS_PER_ZONE,0.334));
const int ZONE_SIZE =  ZONE_WIDTH_SECTIONS*SECTION_SIZE;
//const int SECTIONS_PER_ZONE = ZONE_WIDTH_SECTIONS*ZONE_WIDTH_SECTIONS*ZONE_WIDTH_SECTIONS;
const int ZONE_WIDTH_SECTIONS_SHIFT = int(log2(ZONE_WIDTH_SECTIONS));
const int ZONE_SHIFT = 3*ZONE_WIDTH_SECTIONS_SHIFT;


//#define VOX_SIZE 66
//#define VOX_SIZE_BIG 840

const vec3 voxOriginOffset = vec3(-16,48,-16);
const vec3 voxWorldSize = vec3(64);
const vec3 sectionCount = vec3(2);

//a section is 16x16x16 voxels
//a zone is a group of up to 4x4x4 sections, specifically limited to 1 axis/layer where it comes to faces

#if DEBUG_AXIS>=0
const uint debugAxisNum = DEBUG_AXIS;
#endif


const float voxelDistance = 160.0;
const float shadowDistance = 160.0;
const int shadowMapResolution = 1;

#define LIGHT_SAMPLES_IMAGE
//if false its stored in an SSBO