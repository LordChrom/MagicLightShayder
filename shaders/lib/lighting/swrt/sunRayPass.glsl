#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/util/dither.glsl"
uniform vec2 scaledScreenDim;
#include "/lib/util/taaJitter.glsl"

#define SIZE 16
const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

#if SWRT_TRANSLUCENCY>0
layout (rgba16f) uniform writeonly restrict image2D colorimg6;
#endif

uniform sampler2D colortex5;
uniform sampler2D colortex2;


const uint maxSteps = 15u;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

#include "/lib/lighting/swrt/swrtSampler.glsl"
#include "/lib/util/shadowLightInfo.glsl"

#ifdef SHADOWMAP_SHADOWS
#include "/lib/lighting/shadowmap/shadowSampler.glsl"
#endif

#define SWRT_TRANSLUCENCY 0

void main(){
    imageStore(colorimg6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),vec4(0,0,0,-1));

    vec2 jitteredTexcoord = ((gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)+0.5);
    #ifdef TAA
    jitteredTexcoord+=unscaledJitter();
    #endif
    jitteredTexcoord/=scaledScreenDim;
    float solidDepth = texture(colortex5,jitteredTexcoord).x;
    vec4 worldPos = vec4(jitteredTexcoord,solidDepth,1);

    if(solidDepth>=1.0)
        return;

    worldPos.xyz=worldPos.xyz*2-1;
    worldPos = mat3x4(gbufferProjectionInverse)*worldPos.xyz+gbufferProjectionInverse[3];
    worldPos/=worldPos.w;
    worldPos.xyz = mat3(gbufferModelViewInverse)*worldPos.xyz+gbufferModelViewInverse[3].xyz;



    worldPos.xyz+=cameraPosition;

    vec3 displacementToLight = normalize(mat3(gbufferModelViewInverse)*shadowLightPosition);
    worldPos.xyz+=0.01*displacementToLight;
    displacementToLight*=100;

    ivec3 areaPos = worldPosToSWRT(worldPos.xyz);


    if((areaPos.x<0||areaPos.y<0||areaPos.z<0||
        areaPos.x>=SWRT_SIZE||areaPos.y>=SWRT_SIZE||areaPos.z>=SWRT_SIZE)
    )
        return;

    float ditherValue = bayer128(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)>>1);
    #if SWRT_PENUMBRA_SIZE!=-1
    ditherValue = temporalNoise(ditherValue);
    #endif

    unitShift = getUnitShift();


    #if SWRT_PENUMBRA_SIZE!=-1
//    displacementToLight+=penumbraNoise(ditherValue);
    #endif

    uint translucencies;
    vec4 hitDepths;
    float hitD = traceRay(worldPos.xyz,displacementToLight,unitShift,maxSteps,translucencies,hitDepths);

    vec4 writeColor;
    #if SWRT_TRANSLUCENCY>0
//    writeColor = vec4(1.0,1.0,1.0,0);
//    for(int i=0;(i<SWRT_TRANSLUCENCY)&&bool(translucencies);i++){
//        writeColor.rgb*= getLightIDColor(translucencies&0x3fu);
//        translucencies>>=6;
//    }
    #else
//    writeColor = vec4(1.0,0,0,0);
    #endif

    writeColor.a = hitD>0?0.0:1.0;

    #ifdef SHADOWMAP_SHADOWS
    if(hitD<0){
        displacementToLight=normalize(displacementToLight);
        displacementToLight*=float(maxSteps)/3.0; //TODO make actually respect angles
        worldPos.xyz+=displacementToLight;
        writeColor.a=max(shadowmapSampleFog(worldPos.xyz),0.01);
    }
    #endif
    writeColor.rgb=writeColor.aaa;

    imageStore(colorimg6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),writeColor);
}