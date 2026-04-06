#define TEXTURED
#define LIT
#define VERTEX_NORMALS
#define ENTITY
#define ALPHATEST
#define WRITE_MATERIALS

//26.1: on is broken & off is correct
//1.21.10/11: on is broken with lighing in a few cases (shulker boxes), off is broken with which textures are on top
#ifdef IRIS_VERSION
#if IRIS_VERSION < 11080
#define TRANSLUCENT //TODO stupid iris
#endif
#endif

#include "lib/renderComponents/gbufferFragment.glsl"