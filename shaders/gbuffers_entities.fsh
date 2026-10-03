#define TEXTURED
#define LIT
#define VERTEX_NORMALS
#define ENTITY
#define ALPHATEST
#define WRITE_MATERIALS
#define POM_ELLIGIBLE
#define NOT_BLOCK

//stupid iris nonsense
#ifndef TRANSLUCENT
    #define FAKE_TRANSLUCENT
    #define TRANSLUCENT
#endif


#include "/lib/renderComponents/gbufferFragment.glsl"