#undef COLORED
#undef CUTOUT
#undef TEXTURED

#ifdef SHADOW_WATER
    #define COLORED
    #define CAN_VOXELIZE
#elif defined SHADOW_CUTOUT || defined SHADOW_FALLBACK
    #define CUTOUT
    #define CAN_VOXELIZE
#elif defined SHADOW_BLOCK_ENTITIES
    #define CUTOUT
#elif defined SHADOW_ENTITIES
    #define CUTOUT
#elif defined SHADOW_SOLID
    #define CAN_VOXELIZE
#endif

#ifdef COLORED
    #define CUTOUT
#endif

#ifdef CUTOUT
    #define TEXTURED
#endif

#ifndef SHADOWMAP_SHADOWS
    #undef COLORED
    #undef CUTOUT
    #undef TEXTURED
#endif

#ifndef COLORED_SHADOWS
    #undef COLORED
#endif