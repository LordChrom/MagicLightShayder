#define TEXTURED
#define VERTEX_NORMALS
#define LIT
#define WRITE_MATERIALS
#define ENTITY
#define POM_ELLIGIBLE
#define NOT_BLOCK

//stupid iris nonsense
#ifndef TRANSLUCENT
    #define FAKE_TRANSLUCENT
    #define TRANSLUCENT
#endif

#include "/lib/renderComponents/gbufferVertex.glsl"