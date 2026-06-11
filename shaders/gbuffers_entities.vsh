#define TEXTURED
#define VERTEX_NORMALS
#define LIT
#define WRITE_MATERIALS

#ifdef IRIS_VERSION
#if IRIS_VERSION < 11008
#define FAKE_TRANSLUCENT
#define TRANSLUCENT //TODO stupid iris
#endif
#endif


#include "lib/renderComponents/gbufferVertex.glsl"