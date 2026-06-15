#define TEXTURED
#define VERTEX_NORMALS
#define LIT
#define WRITE_MATERIALS
#define ENTITY
#define POM_ELLIGIBLE

#if defined IRIS_VERSION && !defined TRANSLUCENT
#if IRIS_VERSION < 11008
#define FAKE_TRANSLUCENT
#define TRANSLUCENT //TODO stupid iris
#endif
#endif


#include "lib/renderComponents/gbufferVertex.glsl"