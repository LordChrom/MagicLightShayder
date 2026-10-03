#define DH_SHADER
#define LOD_MOD_SHADER
#ifdef TRANSLUCENT
/* RENDERTARGETS: 3,4 */
#else
/* RENDERTARGETS: 1,2 */
#endif


//#define TEXTURED
#define LIT
#define VERTEX_NORMALS
#define IS_TERRAIN

//#define MATERIALS_TYPE -1


#include "/lib/renderComponents/gbufferFragment.glsl"




in vec4 glcolor;
flat in uint packedNormal;
in float distFromCam;

uniform float far;

void main() {
    if(distFromCam<far)
        discard;
    vec3 normal;
    normal.xy=vec2((uvec2(packedNormal)>>uvec2(17,2))&normPackScale)*(2.0/normPackScale)-1;
    normal.z=dot(normal.xy,normal.xy);
    normal.z = normal.z>=1?0:(sqrt(1-normal.z)*(bool(packedNormal&2u)?1:-1));

    vec2 lmcoord = vec2(0.0);
//    lmcoord = gl_MultiTexCoord2.xy;
    handleFragment(glcolor,normal, lmcoord, vec4(1,1,1,1), int(-1));
    normalOut.a=1.0;
}
