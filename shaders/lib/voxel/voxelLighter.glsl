
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
    float voxHalf = 0.5;

    ivec3 A = axisNumToA(axisNum);
    ivec3 B = axisNumToB(axisNum);

    lightVoxData bestLight = unpackLightData(uvec4(0));
    float bestStrength = 0;

//    uvec4 occludedSides; //1 is occluded

    //potential contributions from all nearby neighbors

    uvec4 [3][3] nearbyVoxels;
    bool [3][3] frontOcclusions;
    bool [3][3] rearOcclusions;

    ivec3 rearVoxPos = sectionPos-progress;



    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            uvec4 frontVoxel = imageLoad(worldVox,sectionPos+ivec3(a,b,0));
            uvec4 rearVoxel = imageLoad(worldVox,rearVoxPos+ivec3(a,b,0));
            nearbyVoxels[a+1][b+1]=rearVoxel;
            rearOcclusions[a+1][b+1]=(rearVoxel.w&1u)==1;
            frontOcclusions[a+1][b+1]=(frontVoxel.w&1u)==1;
        }
    }

    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            ivec3 offset = ivec3(a,b,0);

            lightVoxData lightSrc = unpackLightData(imageLoad(lightVox, rearVoxPos+offset));
            uvec4 rearVoxel = nearbyVoxels[a+1][b+1];
            uint selfEmission = rearVoxel.a>>4;
            bool selfEmissive = selfEmission>0;


            if (selfEmissive){
                lightSrc.worldPos = sectionPosToWorld(rearVoxPos+offset);
                lightSrc.recolor = uvec3(0);
                lightSrc.slopes = fullLightSpread;
                lightSrc.emissive=selfEmission;

//                lightSrc.slopes=uvec4(40,16,48,16);
            }

            bool isCorner = a*b!=0;
            bool isCenter = (a|b)==0;
            bool isEdge = !isCenter && !isCorner;

            bool centerRearOccluded = rearOcclusions[1][1];
            bool centerFrontOccluded = frontOcclusions[1][1];
            bool selfRearOccluded = rearOcclusions[a+1][b+1];
            bool selfFrontOccluded = frontOcclusions[a+1][b+1];

            //if corner, its neighbors. If edge, itself and center. If center, itself twice
            //in any case, these both being blocked means no light from this input voxel
            bool helpersOccluded = (rearOcclusions[a+1][1]||frontOcclusions[a+1][1]) && (rearOcclusions[1][b+1] || frontOcclusions[1][b+1]);


            if((selfEmissive&&selfFrontOccluded) || (selfRearOccluded&&!selfEmissive)
            || centerFrontOccluded || (helpersOccluded && !isCenter)){
                continue;
            }

            vec3 displ = mainWorldPos-lightSrc.worldPos.xyz;
            float lenSquared = dot(displ, displ);
            float strength = float(lightSrc.emissive)/max(0.1, lenSquared);

            if(!isAdjustedPointInSlopes(displ+offset*voxHalf+progress*voxHalf, lightSrc.slopes)) continue;
            if (strength>bestStrength){
                bestLight=lightSrc;
                bestStrength=strength;
            }

        }
    }


    vec3 displ = mainWorldPos-bestLight.worldPos-voxHalf*progress;
    vec2 voxelOutset = vec2(voxHalf,-voxHalf);
    uvec4 slopes = convertSlopesFtoU(vec4(displ.x+voxelOutset,displ.y+voxelOutset),displ.z);


    imageStore(lightVox,sectionPos,packLightData(bestLight));
}

void lightVoxels(uvec3 groupId, uvec3 localId){
    uint section = 0;
    ivec3 sectionPos = ivec3(localId)+ivec3(1);

    ivec3 progress = axisNumToVec(debugAxisNum);

    for(int i = frameOffset;i<SECTION_DEPTH;i+=UPDATE_STRIDE){
        lightVoxel(sectionPos+progress*i,section,progress,debugAxisNum);
    }
}

