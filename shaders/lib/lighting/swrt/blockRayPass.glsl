#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/util/dither.glsl"
uniform vec2 scaledScreenDim;
#include "/lib/util/taaJitter.glsl"

#define SIZE 16
const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba8) uniform writeonly restrict image2D swrtRayHits;

uniform sampler2D colortex5;
uniform sampler2D colortex2;



uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

const uint swrtMaxSteps = 15u;
#define SWRT_INCLUDE_TRACE
#include "/lib/lighting/swrt/swrtSampler.glsl"

vec4 writeColor = vec4(0);

void shade(){
    vec2 texcoord = vec2((gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)|1u);
    #ifdef TAA
    texcoord+=unscaledJitter();
    #endif
    texcoord/=scaledScreenDim;
    float solidDepth = texture(colortex5,texcoord).x;
    vec3 normal = texture(colortex2,texcoord).xyz;
    vec4 worldPos = vec4(texcoord,solidDepth,1);

    if(solidDepth>=1.0)
        return;

    worldPos.xyz=worldPos.xyz*2-1;
    worldPos = mat3x4(gbufferProjectionInverse)*worldPos.xyz+gbufferProjectionInverse[3];
    worldPos/=worldPos.w;
    worldPos.xyz = mat3(gbufferModelViewInverse)*worldPos.xyz+gbufferModelViewInverse[3].xyz;



    worldPos.xyz+=clamp(length(worldPos.xyz),1f,16f)*normal/2048f;
    worldPos.xyz+=cameraPosition;
    ivec3 areaPos = worldPosToSWRT(worldPos.xyz);


    if((areaPos.x<0||areaPos.y<0||areaPos.z<0||
        areaPos.x>=SWRT_SIZE||areaPos.y>=SWRT_SIZE||areaPos.z>=SWRT_SIZE)
    )
    return;

    float ditherValue = bayer128(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)>>1);
    #if SWRT_PENUMBRA_SIZE!=-1
    ditherValue = temporalNoise(ditherValue);
    #endif

    uint index = ((gl_LocalInvocationID.x&1u)<<1) + (gl_LocalInvocationID.y&1u) + 4u*gl_LocalInvocationID.z;
    uint light = getListLight(areaPos,index);
    writeColor.a = float(((areaPos.x*53)^(areaPos.y*17)^(areaPos.z*97))%255)/255.0;

    if(!bool(light&LIGHT_VALID_BIT))
        return;
    vec3 displacementToLight = displacementToListedLight(light,worldPos.xyz);
    #if SWRT_PENUMBRA_SIZE!=-1
    displacementToLight+=penumbraNoise(ditherValue);
    #endif

//    ivec3 lightHash3 = floatBitsToInt(floor(worldPos.xyz+displacementToLight));
//    float lightHash = float(((lightHash3.x*53)^(lightHash3.y*17)^(lightHash3.z*97))%255)/255.0;
//    writeColor.a = lightHash;

    if(traceRay(worldPos.xyz,displacementToLight)>=0)
        return;


    writeColor.rgb=vec3(1);
    #if SWRT_TRANSLUCENCY>0
    writeColor.rgb*=unpackSwrtTranslucency();
    #endif
}

void main(){
    shade();
    uint index = ((gl_LocalInvocationID.x&1u)<<1) + (gl_LocalInvocationID.y&1u) + 4u*gl_LocalInvocationID.z;
    imageStore(swrtRayHits,(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)>>1)+ivec2(index*imageSize(swrtRayHits).x/SWRT_LIGHTS_PER_BLOCK,0),writeColor);
}