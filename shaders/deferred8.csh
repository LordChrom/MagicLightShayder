#version 430
#include "/lib/settings.glsl"
#include "/lib/util/dither.glsl"


//in vec2 jitteredTexcoord;

///* RENDERTARGETS: 6 */
//layout(location = 0) out vec4 voxelLighting;

#define SIZE 8
const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = SWRT_LIGHT_LAYERS) in;
layout (r8) uniform writeonly restrict image3D swrtRayHits;

uniform sampler2D depthtex2;
uniform sampler2D colortex2;


const uint maxSteps = 15u;

uniform vec2 scaledScreenDim;
uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

#include "/lib/lighting/swrt/swrtSampler.glsl"

void main(){
    vec2 jitteredTexcoord = (vec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)+0.5)/scaledScreenDim;
    float solidDepth = texture(depthtex2,jitteredTexcoord).x;
    vec4 normal = texture(colortex2,jitteredTexcoord);
    vec4 worldPos = vec4(jitteredTexcoord,solidDepth,1);


    worldPos.xyz=worldPos.xyz*2-1;
    worldPos = gbufferProjectionInverse*worldPos;
    worldPos/=worldPos.w;
    worldPos.xyz = mat3(gbufferModelViewInverse)*worldPos.xyz+gbufferModelViewInverse[3].xyz;

    float ditherValue = bayer128(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)>>1);

    #ifdef SWRT_NOISY_PENUMBRAS
    ditherValue = temporalNoise(ditherValue);
    #endif


    worldPos.xyz+=clamp(length(worldPos.xyz)*0.001,0.04,0.1)*normalize(normal.xyz*2-1);
    worldPos.xyz+=cameraPosition;
    unitShift = getUnitShift();
    ivec3 areaPos = worldPosToSWRT(worldPos.xyz);
    vec3 subvoxelOffset = 0.5-fract(worldPos.xyz);

    #ifdef SWRT_NOISY_PENUMBRAS
    subvoxelOffset+=penumbraNoise(ditherValue);
    #endif




    if(!(areaPos.x<0||areaPos.y<0||areaPos.z<0||
    areaPos.x>=SWRT_SIZE||areaPos.y>=SWRT_SIZE||areaPos.z>=SWRT_SIZE)
    ){
        uint lightIndex=((gl_LocalInvocationID.x&1u)<<1)+(gl_LocalInvocationID.y&1u);

        uint[SWRT_LIGHT_LAYERS] lights;

        getStridedLightList(lights,areaPos,unitShift,lightIndex);

        //TODO the convergence here is obviously leaving a lot to be desired.
        for(int i=0;i<SWRT_LIGHT_LAYERS;i++){
            float outF = 0.0;
            uint light = lights[i];
            if(bool(light&LIGHT_VALID_BIT)){
                vec3 displacementToLight = uncheckedUnpackListedLight(light)+subvoxelOffset;
                if(traceRay(worldPos.xyz,displacementToLight,unitShift,maxSteps)<0){
                    outF = 1.0;
                }
            }
            imageStore(swrtRayHits,ivec3((gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)>>1,lightIndex+4*i),vec4(outF,0,0,0));
        }
    }
}