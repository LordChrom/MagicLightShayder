uniform mat4 gbufferModelView,gbufferProjection;
uniform vec3 sunPosition;
#ifdef GBUFFER_SHADER
uniform sampler2D depthtex2;
#endif
#include "/lib/util/conversions.glsl"
#include "/lib/util/raycast.glsl"
#include "/lib/util/dither.glsl"

vec3 viewDirToScreen(vec3 viewDirection, vec3 screenPos){
    vec4 pos = mat3x4(gbufferProjection)*viewDirection;

    return normalize(pos.xyz-pos.w*(2*screenPos-1));
}

float sampleScreenspaceShadow(vec3 worldPos, vec3 normal){
    vec4 screenPos = gbufferProjection*vec4(mat3(gbufferModelView)*(worldPos-cameraPosition),1);
    screenPos.xyz=(screenPos.xyz/screenPos.w)*0.5+0.5;

    uint rayHitReason;

    const int stepsPerBounce=30;
    const float maxCastLen = 0.5;

    float ditherValue = dither(ivec2(gl_FragCoord.xy));
    screenspaceRaycast(
        depthtex2,stepsPerBounce,maxCastLen,
        screenPos.xyz,viewDirToScreen(sunPosition, screenPos.xyz),ditherValue,
        rayHitReason
    );
    float sunStrength = max(0,dot(normalize(mat3(gbufferModelView)*normal),normalize(sunPosition)));
    if(rayHitReason==4)
        sunStrength=0;
    if(rayHitReason==2)
        sunStrength=0.5;
    return sunStrength;
}