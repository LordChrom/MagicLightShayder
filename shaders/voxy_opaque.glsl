#define VOXY_PATCH

#define TEXTURED
#define LIT
#define VERTEX_NORMALS
#define ALPHATEST
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
