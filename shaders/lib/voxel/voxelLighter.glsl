
layout (rgba32ui) uniform restrict uimage3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;
#include "/lib/voxel/voxelHelper.glsl"


uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;


const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = SECTION_WIDTH, local_size_y = SECTION_WIDTH, local_size_z = 1) in;



lightVoxData determineBestLightSource( float scale,
    lightVoxData[3][3] inputSamples, uvec4 [3][3] frontVoxels, uvec4 [3][3] rearVoxels, bool [3][3] obstructions
){
    lightVoxData bestLight = noLight;
    float bestStrength = 0;

    bool centerFrontOccluded = (frontVoxels[1][1].w&1u)==1u;

    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            lightVoxData lightSrc = inputSamples[a+1][b+1];

            if(lightSrc.emission==0)
                continue;

            bool isCenter = (a|b)==0;

//            bool selfRearOccluded = rearOcclusions[a+1][b+1];
//            bool selfFrontOccluded = frontOcclusions[a+1][b+1];
            bool selfOccluded = obstructions[a+1][b+1];

            //if corner, its neighbors. If edge, itself and center. If center, itself twice
            //in any case, these both being blocked means no light from this input voxel
            bool helpersOccluded = (obstructions[a+1][1]) && (obstructions[1][b+1]);


            vec3 displ = lightSrc.lightTravel;
            float lenSquared = dot(displ, displ);
            float strength = float(lightSrc.emission)/max(0.1, lenSquared);
            displ.xy+=vec2(a,b)*scale;

            bool srcBlocked = centerFrontOccluded || (helpersOccluded && !isCenter) || selfOccluded;

            srcBlocked = srcBlocked || (displ.x*a>0) || (displ.y*b>0); //will be unnecessary soon

            //occlusion stuff goes here, maybe

            if(srcBlocked)
                inputSamples[a+1][b+1].emission=0;

            if (strength>bestStrength && !srcBlocked){
                bestLight=lightSrc;
                bestStrength=strength;
            }
        }
    }

    return bestLight;
}



//out of 9 input samples, only up to 4 can have any light flowing between the source and the output
//center at [0][0], corner at [1][1],
//each vec4 is an illuminate/occlude thing
vec4[2][2] pickRelevantInputSamples(lightVoxData bestSource, lightVoxData[3][3] inputSamples, bool[3][3] obstructions, float scale){
    vec4[2][2] ret;
    vec3 lightTravel = bestSource.lightTravel;
    int aSignSrc = int(sign(lightTravel.x));
    int bSignSrc = int(sign(lightTravel.y));

    float slopeScale = scale/lightTravel.z;

    //of the output voxel face, represents outer a, outer b, inner a, inner b bounds
    vec4 occludeSlopes = (abs(lightTravel.xy).xyxy + vec4(0.5,0.5,-0.5,-0.5))*slopeScale;

    //00 01 10 11
    vec2 potentialOcclusions = {{occludeSlopes.xy,occludeSlopes.xw},{occludeSlopes.zy,occludeSlopes.zw}};

    for(int i=0; i<2; i++){
        for(int j=0; j<2; j++){
            int a = -i*aSignSrc;
            int b = -j*bSignSrc;
            lightVoxData relevantSample = inputSamples[1+a][1+b];
            bool sameSource = relevantSample.lightTravel==bestSource.lightTravel;
            bool obstructed = obstructions[1+a][1+b];
            bvec2 aligned = bvec2(lightTravel.x+a==0,lightTravel.y+b==0); //on the same axis from light src direction


            vec4 occlusion = relevantSample.occlusion;
            //TODO make this branchless once it all works
            if(obstructed){
                if(i==1){ //edge/corner
                    occlusion.z = occludeSlopes.x;//increase occlusion.
                }else { //center/edge
                    occlusion.x = occludeSlopes.x;//reduce illumination
                }

                if(j==1){ //edge/corner
                    occlusion.w = occludeSlopes.y;//increase occlusion.
                }else { //center/edge
                    occlusion.y = occludeSlopes.y;//reduce illumination
                }

                if(i==1 && j==1){ //corner only

                }
            }

            if(aligned.x)
                occlusion.yw=vec2(1,0);
            if(aligned.y)
                occlusion.xz=vec2(1,0);

            if(!sameSource)
                occlusion=vec4(0); //not 100% sure about this

            ret[i][j]=occlusion;
        }
    }

    return ret;
}



//output is
vec4 doIlluminationOcclusion(vec4 illumA, vec4 illumB, vec4 occlA, vec4 occlB){

    return vec4(0);
}



//for one voxel face, determines the light entering that voxel face
//based on the 9 adjacent voxel faces in the previous plane & the nearby terrain voxels
void lightVoxelFace(ivec3 sectionPos, uint section,ivec3 progress,uint axisNum){
    float scale = 1;

    lightVoxData [3][3] inputSamples;
    uvec4 [3][3] frontVoxels;
    uvec4 [3][3] rearVoxels;
    bool [3][3] obstructions;

    //all the relevant memory accesses
    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            ivec3 localOffset = ivec3(a,b,-1);
            uvec4 frontVoxel = imageLoad(worldVox,sectionPos+ivec3(localOffset.xy,0));
            uvec4 rearVoxel = imageLoad(worldVox,sectionPos+localOffset);
            lightVoxData inputSample = unpackLightData(imageLoad(lightVox, sectionPos+localOffset));
            inputSample.lightTravel-=vec3(localOffset)*scale;

            obstructions[a+1][b+1]=(rearVoxel.w&1u)==1 || (frontVoxel.w&1u)==1;
            frontVoxels[a+1][b+1] = frontVoxel;
            rearVoxels[a+1][b+1] = rearVoxel;
            inputSamples[a+1][b+1] = inputSample;
        }
    }


    //determine best light source first
    lightVoxData bestLight = determineBestLightSource(
        scale, inputSamples, frontVoxels, rearVoxels, obstructions
    );

    vec3 displ = bestLight.lightTravel;

    // then pick the 4 relevant input samples
    // (the voxels further from the center of the light source do not contribute)
    vec4[2][2] relevantSources = pickRelevantInputSamples(bestLight, inputSamples, obstructions, scale);


    //then calculate new illumination/occlusion values


    if (frontVoxels[1][1].w>0xf){
        bestLight.lightTravel = vec3(0);
        bestLight.color = frontVoxels[1][1].rgb*(1.0/255.0);
        bestLight.emission = frontVoxels[1][1].w>>4;
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

