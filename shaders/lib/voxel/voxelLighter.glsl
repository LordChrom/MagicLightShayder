
// rgb is the worldPos of the light source's center
//a encodes partial occlusion, as 4 bits empty, 4x 6 bit slope cutoffs, 4 bits strength.
//each angular cutoff is an inverse slope indicating angle off occlusion from light source, mapping linearly from [0,50] to [-1,1]
layout (rgba32ui) uniform restrict uimage3D lightVox;


layout (rgba8ui) uniform readonly restrict uimage3D worldVox;
#include "/lib/voxel/voxelHelper.glsl"


//#define FULL_SPREAD vec4(1,-1,1,-1);
#define NO_LIGHT 0

uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;

const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = SECTION_WIDTH, local_size_y = SECTION_WIDTH, local_size_z = 1) in;

void lightVoxel(ivec3 sectionPos, uint section,ivec3 progress,uint axisNum){
    vec3 mainWorldPos = sectionPosToWorld(sectionPos);
    float scale = 0.5;

    ivec3 A = axisNumToA(axisNum);
    ivec3 B = axisNumToB(axisNum);

    lightVoxData bestLight;
    float bestStrength = -1;

    vec4 occludedSides; //0 is occluded

    //potential contributions from all nearby neighbors
    //order +a, -a, +b,-b
    for (int i=-1;i<4;i++){
        int axisDir = int(((axisNum|1u)+1+i)%6);
        ivec3 offset = axisNumToVec(axisDir);

        if(i<0) offset=ivec3(0);

        ivec3 rearVoxPos = sectionPos+offset-progress;

        uvec4 rearVoxel = imageLoad(worldVox, rearVoxPos);
        uvec4 neighborVoxel = imageLoad(worldVox,rearVoxPos+progress);
        uint selfEmissive = rearVoxel.a>>4;

        occludedSides[max(0,i)]=1u-(neighborVoxel.a&1u);

        if((rearVoxel.a&1u)==1 && selfEmissive==0) //terrain occludes, and doesnt transmit or emit, light passing into it cannot pass out
            continue;

        lightVoxData lightSrc = unpackLightData(imageLoad(lightVox, rearVoxPos));

        if(selfEmissive>0){
            lightSrc.worldPos = sectionPosToWorld(rearVoxPos);
            lightSrc.recolor=uvec3(0);
            lightSrc.slopes = fullLightSpread;
            lightSrc.emissive=selfEmissive;
        }

        if(lightSrc.emissive==0)
            continue;

        vec3 displ = mainWorldPos-lightSrc.worldPos.xyz;
        float lenSquared = dot(displ,displ);
        float strength = float(lightSrc.emissive)/max(0.1,lenSquared);

        if (selfEmissive==0){
            if(!isAdjustedPointInSlopes(displ+offset,lightSrc.slopes))
                continue;
        }

        if(strength>bestStrength){
            bestLight=lightSrc;
            bestStrength=strength;
        }
    }


    vec3 displ = mainWorldPos-bestLight.worldPos;


    imageStore(lightVox,sectionPos,packLightData(bestLight));
}

void lightVoxels(uvec3 groupId, uvec3 localId){
    uint section = 0;
    ivec3 sectionPos = ivec3(localId)+ivec3(1);

    ivec3 progress = axisNumToVec(debugAxisNum);

    for(int i = frameOffset;i<SECTION_DEPTH;i+=UPDATE_STRIDE){
        lightVoxel(sectionPos+progress*i,section,progress,debugAxisNum);
        groupMemoryBarrier();
    }
}

