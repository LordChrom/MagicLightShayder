uniform mat4 gbufferModelView,gbufferProjection;
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
    const float maxCastLen = 1.3;

    float ditherValue = dither(ivec2(gl_FragCoord.xy));
    vec3 hitPosition = screenspaceRaycast(
        depthtex2,stepsPerBounce,maxCastLen,
        screenPos.xyz,viewDirToScreen(normalize(shadowLightPosition), screenPos.xyz),ditherValue,false,
        rayHitReason
    );

    float actualHitDepth = texture(depthtex2,clamp(hitPosition.xy,0,1)).x;
    float sunStrength = max(0,dot(normalize(mat3(gbufferModelView)*normal),normalize(shadowLightPosition)));


    hitPosition.z = depthToLinear(hitPosition.z);
//    bool hitSky = actualHitDepth>=1.0;
    actualHitDepth = depthToLinear(actualHitDepth);

    if(rayHitReason==4) //solid terrain
        sunStrength=0;
    if(rayHitReason==2){//depth difference
        sunStrength*=clamp(abs(actualHitDepth-hitPosition.z)/hitPosition.z,0,1);
        sunStrength=0;
    }
//    if(rayHitReason==1){//edge of screen
        //TODO estimate based on depth & normals at edge of screen
//    }
    return sunStrength;
}