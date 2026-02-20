#define DEBUG_OCCLUSION_MAP
#define UNFLIP_DEBUG_MAPS
#define DEBUG_OUTLINE_WIDTH 0.02 //[0 0.01 0.02 0.04 0.08 0.16]
#define DEBUG_AXIS 5 //[-1 0 1 2 3 4 5]

#if DEBUG_AXIS>=0
const uint debugAxisNum = DEBUG_AXIS;
#endif