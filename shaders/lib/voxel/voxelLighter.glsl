
//+z in lightVox space is always the direction along which light propogates
//rgb are offset to light source
//a encodes partial occlusion, as 4 bits strength, 4x 7 bit anglular cutoffs.
//each angular cutoff is a slope indicating angle off occlusion from light source. Anything exceeding the slope in that dir is unlit.
layout (rgba32f) uniform coherent restrict image3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;
#include "/lib/voxel/voxelHelper.glsl"


#define SECTION_WIDTH 16
#define SECTION_DEPTH 16
#define UPDATE_INTERVAL 2

#define FULL_SPREAD 64*0x4081;

uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_INTERVAL;

const int stepCount = SECTION_DEPTH/UPDATE_INTERVAL;

const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = SECTION_WIDTH, local_size_y = SECTION_WIDTH, local_size_z = 1) in;

void lightVoxel(ivec3 sectionPos, uint section,ivec3 progress,uint axisNum){
    vec4 voxOutput = vec4(0);
    uvec4 thisBlock = imageLoad(worldVox,sectionPos);
    uint transmissive = (thisBlock.a&1u)^1u;
    uint emissive = thisBlock.a>>4;

    vec3 outgoingLight;
    uint spread = 0;
    if(emissive>0){
        outgoingLight = vec3(0);
        spread += emissive;
    }else {
        vec4 bestSofar = imageLoad(lightVox, sectionPos-progress);
        bestSofar.xyz-=progress;
        float len = length(bestSofar.xyz);
        float strength = float(floatBitsToUint(bestSofar.a)*transmissive&4u)/(len*len);
        float bestStrength = strength;

        uint cutoffDirs = 0;
        for (uint i=0;i<4;i++){
            uint testAxisDir = ((axisNum|1u)+1+i)%6;
            ivec3 offset = axisNumToVec(testAxisDir);

            vec4 testLightSample = imageLoad(lightVox, sectionPos+offset-progress);
            uvec4 testVoxel = imageLoad(worldVox,sectionPos+offset);
            if((testVoxel.a&1u)==1u){
                continue;
            }
            testLightSample.xyz+=offset-progress;
            len = length(testLightSample.xyz);
            strength = float(floatBitsToUint(testLightSample.a)&4u)/(len*len);
            if(strength>bestStrength){
                bestSofar=testLightSample;
                bestStrength=strength;
            }
        }


        outgoingLight = (bestSofar.xyz-progress);

        outgoingLight = bestSofar.xyz;
        spread = floatBitsToUint(bestSofar.a);
    }

    imageStore(lightVox,sectionPos,vec4(outgoingLight,uintBitsToFloat(spread)));

}

void lightVoxels(uvec3 groupId, uvec3 localId){
    uint section = 0;
    ivec3 sectionPos = ivec3(localId)+ivec3(1);

    ivec3 progress = axisNumToVec(debugAxisNum);

    for(int i = frameOffset;i<SECTION_DEPTH;i+=UPDATE_INTERVAL){
        lightVoxel(sectionPos+progress*i,section,progress,debugAxisNum);
        groupMemoryBarrier();
    }
}

