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

//void handleFragment(vec4 glcolor,vec3 normal, vec2 lmcoord, vec4 voxycolor, int materialID)





in vec4 glcolor;
flat in uint packedNormal;

void main() {
    vec3 normal;
    normal.xy=vec2((uvec2(packedNormal)>>uvec2(17,2))&normPackScale)*(2.0/normPackScale)-1;
    normal.z=dot(normal.xy,normal.xy);
    normal.z = normal.z>=1?0:(sqrt(1-normal.z)*(bool(packedNormal&2u)?1:-1));

    handleFragment(glcolor,normal, vec4(1,1,1,1), int(0));
    normalOut.a=1.0;
}
