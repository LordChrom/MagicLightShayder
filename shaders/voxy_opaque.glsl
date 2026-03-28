#define VOXY_PATCH

#define TEXTURED
#define LIT
#define VERTEX_NORMALS
#define ALPHATEST

#if VOXY >=2
vec4 voxyLighting(vec2 lightcoord){
    return texture(lightmap,lightcoord);
}
#else

const vec3 blocklightColor = vec3(1.0, 0.5, 0.08);
const vec3 skylightColor = vec3(0.05, 0.15, 0.3);
const vec3 sunlightColor = vec3(1.0);
const vec3 ambientColor = vec3(0.1);

vec4 voxyLighting(vec2 lightcoord){
    return vec4((lightcoord.x*blocklightColor + lightcoord.y*max(skylightColor, 1.0) + ambientColor), 1);
}

#endif

#include "lib/renderComponents/gbufferFragment.glsl"


//struct VoxyFragmentParameters {
//    vec4 sampledColour;
//    vec2 tile;
//    vec2 uv;
//    uint face;
//    uint modelId;
//    vec2 lightMap;
//    vec4 tinting;
//    uint customId;
//};

void voxy_emitFragment(VoxyFragmentParameters parameters) {
    uint upper = parameters.face>>1;
    vec3 normal = vec3(upper==2,upper==0,upper==1);

    if((parameters.face&1)==0) normal=-normal;

//    parameters.lightMap
    handleFragment(parameters.tinting,normal, clamp(parameters.lightMap,vec2(0),vec2(0.5)), parameters.sampledColour);

}
