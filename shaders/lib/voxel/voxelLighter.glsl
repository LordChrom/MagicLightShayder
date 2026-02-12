
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

                rearOcclusions[a+1][b+1]=false;
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

            vec3 centerDispl = mainWorldPos-voxHalf*progress-lightSrc.worldPos.xyz;
            float lenSquared = dot(centerDispl, centerDispl);
            float strength = float(lightSrc.emissive)/max(0.1, lenSquared);
            vec3 displ = centerDispl + offset*2*voxHalf;
            bool connectionBlocked = centerFrontOccluded || (displ.x*offset.x>0) || (displ.y*offset.y>0);


            connectionBlocked = connectionBlocked || (!(
                isAdjustedPointInSlopes(displ, lightSrc.slopes)||
                isAdjustedPointInSlopes(displ+offset*voxHalf, lightSrc.slopes)||
                isAdjustedPointInSlopes(displ+offset*voxHalf, lightSrc.slopes) || true
            ));


//            strength*=(lightSrc.slopes.x-lightSrc.slopes.y)*(lightSrc.slopes.z-lightSrc.slopes.w);


            uvec4 oldBounds = bestLight.slopes;
            bool sameSource = bestLight.worldPos==lightSrc.worldPos;

            if (strength>bestStrength && !connectionBlocked){
                bestLight=lightSrc;
                bestStrength=strength;
            }


//            if(sameSource  && !connectionBlocked && isEdge){
//                uvec4 directionsToTake = uvec4(0);
//                directionsToTake = uvec4(bvec4(
//                    b==0 && centerDispl.x>0,
//                    b==0 && centerDispl.x<0,
//                    a==0 && centerDispl.y>0,
//                    a==0 && centerDispl.y<0
//                ));
//
//                uvec4 newBounds = lightSrc.slopes*directionsToTake + (1-directionsToTake)*fullLightSpread;
//
//                neighborBounds = combineSlopeBounds(neighborBounds,newBounds);
////                neighborBounds=fullLightSpread;
//            }
        }
    }

    int centerOccluded = int(frontOcclusions[1][1]||rearOcclusions[1][1]);

//    bestLight.slopes=centerBounds*(1-centerOccluded)+neighborBounds*centerOccluded;

//    bestLight.slopes=centerBounds;


    vec3 displ = mainWorldPos-voxHalf*progress-bestLight.worldPos;
    vec2 voxelOutset = vec2(voxHalf,-voxHalf);

    uvec4 bounds = fullLightSpread;
    uvec4 edgeSlopes = convertSlopesFtoU(vec4(displ.x+voxelOutset,displ.y+voxelOutset),displ.z);

        edgeSlopes+=(1-centerOccluded)*ivec4(1,-1,1,-1);
//    edgeSlopes+=ivec4(1,-1,1,-1);

    //1 means the edge in that dir is occupied
    uvec4 edgeOcclusions = uvec4(
        frontOcclusions[2][1]||rearOcclusions[2][1],
        frontOcclusions[0][1]||rearOcclusions[0][1],
        frontOcclusions[1][2]||rearOcclusions[1][2],
        frontOcclusions[1][0]||rearOcclusions[1][0]
    );


    //1 means light is free to travel in that direction
    uvec4 lightDirMask = uvec4(step(-0.1,vec4(displ.x,-displ.x,displ.y,-displ.y)));
//        bounds=combineSlopeBounds(bounds, slopeOffset + uvec2(slopeScale,-slopeScale).xyxy*lightDirMask);



//
    if(centerOccluded>0){
        uvec4 faceBounds = edgeSlopes.yxwz*lightDirMask;
        faceBounds.xz = max(uvec2(slopeOffset),faceBounds.xz);
        faceBounds.yw = min(uvec2(slopeOffset),faceBounds.yw);

//        bounds.xy = faceBounds.xy;
        faceBounds.zw=uvec2(slopeMax,slopeMin);
//
        bounds=combineSlopeBounds(bounds,faceBounds);
        bounds=faceBounds;
    }else{
//        bounds=uvec

//        if((edgeOcclusions.x*edgeOcclusions.y*edgeOcclusions.z*edgeOcclusions.w)!=0){
//            bounds = uvec4(74,54,74,54);
//        }
            edgeOcclusions *=(1-lightDirMask);
//            edgeOcclusions|=uint(frontOcclusions[1][1]||rearOcclusions[1][1]);

            bounds=edgeOcclusions*edgeSlopes+(1-edgeOcclusions)*fullLightSpread;
    }


//    bounds.y=64;
//    combineSlopeBounds(slopes, uvec4().xxyy*vec2(slopeScale,-slopeScale).yxyx+slopeOffset));

    bestLight.slopes=combineSlopeBounds(bestLight.slopes,bounds);

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

