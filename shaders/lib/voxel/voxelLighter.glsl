
layout (rgba32ui) uniform restrict uimage3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;
#include "/lib/voxel/voxelHelper.glsl"


uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;


const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = SECTION_WIDTH, local_size_y = SECTION_WIDTH, local_size_z = 1) in;



lightVoxData determineBestLightSource(
    float scale,
    lightVoxData[3][3] inputSamples, uvec4 [3][3] frontVoxels, uvec4 [3][3] rearVoxels, bool [3][3] frontOcclusions, bool [3][3] rearOcclusions
){
    lightVoxData bestLight = noLight;
    float bestStrength = 0;

    bool centerFrontOccluded = (frontVoxels[1][1].w&1u)==1u;

    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            lightVoxData lightSrc = inputSamples[a+1][b+1];

            if(lightSrc.emissive==0)
                continue;

            bool isCenter = (a|b)==0;

            bool selfRearOccluded = rearOcclusions[a+1][b+1];
            bool selfFrontOccluded = frontOcclusions[a+1][b+1];

            //if corner, its neighbors. If edge, itself and center. If center, itself twice
            //in any case, these both being blocked means no light from this input voxel
            bool helpersOccluded = (rearOcclusions[a+1][1]||frontOcclusions[a+1][1]) && (rearOcclusions[1][b+1] || frontOcclusions[1][b+1]);


            vec3 displ = lightSrc.lightTravel;
            float lenSquared = dot(displ, displ);
            float strength = float(lightSrc.emissive)/max(0.1, lenSquared);
            displ.xy+=vec2(a,b)*scale;

            bool srcBlocked = centerFrontOccluded || (helpersOccluded && !isCenter) ||
            (selfFrontOccluded || selfRearOccluded);

            srcBlocked = srcBlocked || (displ.x*a>0) || (displ.y*b>0); //will be unnecessary soon

            //TODO: occlusion stuff goes here

//            blocked[a+1][b+1]=srcBlocked;
            if(srcBlocked)
                inputSamples[a+1][b+1].emissive=0;

            if (strength>bestStrength && !srcBlocked){
                bestLight=lightSrc;
                bestStrength=strength;
            }
        }
    }

    return bestLight;
}



//out of 9 input samples, only up to 4 can have any light flowing between the source and the output
//output format has center at [0][0], corner at [1][1],
lightVoxData[2][2] pickRelevantInputSamples(lightVoxData bestSource, lightVoxData[3][3] inputSamples){
    int a = int(sign(bestSource.lightTravel.x));
    int b = int(sign(bestSource.lightTravel.y));
    lightVoxData[2][2] ret = {{inputSamples[1][1],inputSamples[a+1][1]},{inputSamples[1][b+1],inputSamples[a+1][b+1]}};

    for(int i=0; i<2; i++){
        for(int j=0; j<2; j++){
            //the lights dont contribute if from a different source, or if they're on an outer axis but the light doesnt travel along that axis
            //eg, if the light was directly behind the output sample, all input samples to the side should contribute nothing
            if(ret[i][j].lightTravel!=bestSource.lightTravel || bool(i&~a) || bool(j&~b))
                ret[i][j]=noLight;
        }
    }

    return ret;
}



//for one voxel face, determines the light entering that voxel face
//based on the 9 adjacent voxel faces in the previous plane & the nearby terrain voxels
void lightVoxelFace(ivec3 sectionPos, uint section,ivec3 progress,uint axisNum){
    float scale = 1;

    lightVoxData [3][3] inputSamples;
    uvec4 [3][3] frontVoxels;
    uvec4 [3][3] rearVoxels;
    bool [3][3] frontOcclusions;
    bool [3][3] rearOcclusions;

    //all the relevant memory accesses
    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            ivec3 localOffset = ivec3(a,b,-1);
            uvec4 frontVoxel = imageLoad(worldVox,sectionPos+ivec3(localOffset.xy,0));
            uvec4 rearVoxel = imageLoad(worldVox,sectionPos+localOffset);
            lightVoxData inputSample = unpackLightData(imageLoad(lightVox, sectionPos+localOffset));
            inputSample.lightTravel-=vec3(localOffset)*scale;

            rearOcclusions[a+1][b+1]=(rearVoxel.w&1u)==1;
            frontOcclusions[a+1][b+1]=(rearVoxel.w&1u)==1 || (frontVoxel.w&1u)==1;
            frontVoxels[a+1][b+1] = frontVoxel;
            rearVoxels[a+1][b+1] = rearVoxel;
            inputSamples[a+1][b+1] = inputSample;
        }
    }


    //determine best light source first
    lightVoxData bestLight = determineBestLightSource(
        scale, inputSamples, frontVoxels, rearVoxels, frontOcclusions, rearOcclusions
    );

    vec3 displ = bestLight.lightTravel;

    // then pick the 4 relevant input samples
    // (the voxels further from the center of the light source do not contribute)
    lightVoxData[2][2] relevantSources = pickRelevantInputSamples(bestLight, inputSamples);


    //then calculate new occlusion values (the following code will change cuz the whole current approach is flawed)

//    int centerOccluded = int(frontOcclusions[1][1]||rearOcclusions[1][1]);
//    vec2 voxelOutset = vec2(voxHalf,-voxHalf);
//
//    uvec4 bounds = fullLightSpread;
//    uvec4 edgeSlopes = convertSlopesFtoU(vec4(displ.x+voxelOutset,displ.y+voxelOutset),displ.z);
//
//    edgeSlopes+=(1-centerOccluded)*ivec4(1,-1,1,-1);
//
//    //1 means the edge in that dir is occupied
//    uvec4 edgeOcclusions = uvec4(
//        frontOcclusions[2][1]||rearOcclusions[2][1],
//        frontOcclusions[0][1]||rearOcclusions[0][1],
//        frontOcclusions[1][2]||rearOcclusions[1][2],
//        frontOcclusions[1][0]||rearOcclusions[1][0]
//    );
//
//    //1 means light is free to travel in that direction
//    uvec4 lightDirMask = uvec4(step(-0.1,vec4(displ.x,-displ.x,displ.y,-displ.y)));
//
//    if(centerOccluded>0){
//        uvec4 faceBounds = edgeSlopes.yxwz*lightDirMask;
//        faceBounds.xz = max(uvec2(slopeOffset),faceBounds.xz);
//        faceBounds.yw = min(uvec2(slopeOffset),faceBounds.yw);
//
//        faceBounds.zw=uvec2(slopeMax,slopeMin);
//
//        bounds=combineSlopeBounds(bounds,faceBounds);
//    }else{
//            edgeOcclusions *=(1-lightDirMask);
//            bounds=edgeOcclusions*edgeSlopes+(1-edgeOcclusions)*fullLightSpread;
//    }
//
//
//    bestLight.slopes=combineSlopeBounds(bestLight.slopes,bounds);



//    bestLight.slopes=fullLightSpread;

    if (frontVoxels[1][1].w>0xf){
        bestLight.lightTravel = vec3(0);
        bestLight.recolor = uvec3(0);
//        bestLight.slopes = fullLightSpread;
        bestLight.emissive = frontVoxels[1][1].w>>4;
    }

    imageStore(lightVox,sectionPos,packLightData(bestLight));
}

void lightVoxelFaces(uvec3 groupId, uvec3 localId){
    uint section = 0;
    ivec3 sectionPos = ivec3(localId)+ivec3(1);
    ivec3 progress = axisNumToVec(debugAxisNum);

    for(int i = frameOffset;i<SECTION_DEPTH;i+=UPDATE_STRIDE){
        lightVoxelFace(sectionPos+progress*i,section,progress,debugAxisNum);
    }
}

