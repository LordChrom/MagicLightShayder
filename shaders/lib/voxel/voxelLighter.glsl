
layout (rgba32ui) uniform restrict uimage3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;
#include "/lib/voxel/voxelHelper.glsl"


uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;


const ivec3 workGroups = ivec3(1,1,1);
layout (local_size_x = SECTION_WIDTH, local_size_y = SECTION_WIDTH, local_size_z = 1) in;

#if false
//dummy definition because my intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;uint emission;vec3 lightTravel;};
#endif





void takeSamples(ivec3 sectionPos, float scale,
    out lightVoxData [3][3] inputSamples, out uvec4 [3][3] frontVoxels, out uvec4 [3][3] rearVoxels, out bool [3][3] obstructions
){
    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            ivec3 localOffset = ivec3(a,b,-1);
            uvec4 frontVoxel = imageLoad(worldVox,sectionPos+ivec3(localOffset.xy,0));
            uvec4 rearVoxel = imageLoad(worldVox,sectionPos+localOffset);
            lightVoxData inputSample = unpackLightData(imageLoad(lightVox, sectionPos+localOffset));
            inputSample.lightTravel-=vec3(localOffset)*scale;

            bool rearObstructed = (rearVoxel.w&1u)==1;
            bool frontObstructed = (frontVoxel.w&1u)==1;
            //            frontObstructed = frontObstructed && !(a==0&&b==0);

            if(rearVoxel.w==0x01){ //non emissive
                inputSample=noLight;
            }


            obstructions[a+1][b+1]= rearObstructed || frontObstructed; //TODO make better
            frontVoxels[a+1][b+1] = frontVoxel;
            rearVoxels[a+1][b+1] = rearVoxel;
            inputSamples[a+1][b+1] = inputSample;
        }
    }
}



lightVoxData determineBestLightSource( float scale,
    lightVoxData[3][3] inputSamples, uvec4 [3][3] frontVoxels, uvec4 [3][3] rearVoxels, bool [3][3] obstructions
){
    lightVoxData bestLight = noLight;
    float bestStrength = 0;

    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            lightVoxData lightSrc = inputSamples[a+1][b+1];

            if(lightSrc.emission==0)
                continue;

            bool isCenter = (a|b)==0;

            bool selfOccluded = obstructions[a+1][b+1];

            //if corner, its neighbors. If edge, itself and center. If center, itself twice
            //in any case, these both being blocked means no light from this input voxel
            bool helpersOccluded = (obstructions[a+1][1]) && (obstructions[1][b+1]);


            vec3 displ = lightSrc.lightTravel;
            float lenSquared = dot(displ, displ);
            float strength = float(lightSrc.emission)/max(0.1, lenSquared);
            displ.xy+=vec2(a,b)*scale;

            bool srcBlocked = (helpersOccluded && !isCenter) || selfOccluded;

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
//corner closest to source at [0][0], output sample at [1][1]
//newObstructions is flipped to match this, with [2][2] being the firthest corner from source
void pickRelevantInputSamples(lightVoxData bestSource, lightVoxData[3][3] inputSamples, bool[3][3] obstructions, float scale,
    out lightVoxData[2][2] samples, out bool[2][2] relevance, out bvec2 alignment, out bool[2][2] newObstructions){

    vec3 lightTravel = bestSource.lightTravel;
    int aSignSrc = int(sign(lightTravel.x));
    int bSignSrc = int(sign(lightTravel.y));

    for(int i=0; i<2; i++){
        for(int j=0; j<2; j++){
            int a = (i-1)*aSignSrc;
            int b = (j-1)*bSignSrc;
            newObstructions[i][j]=obstructions[1+a][1+b];
            lightVoxData relevantSample = inputSamples[1+a][1+b];
            //TODO: also probably check for color when translucents stuff
            bool sameSource = relevantSample.lightTravel==bestSource.lightTravel;
            bool aligned = (lightTravel.x+a*scale<=0) || (lightTravel.y+b*scale<=0);

            relevance[i][j] = sameSource && !aligned;
            samples[i][j] = relevantSample;
        }
    }
    alignment = bvec2(bSignSrc==0,aSignSrc==0);
}



//11 is top left corner, -1 -1 is bottom left corner
void occludeCorner(inout vec2 corner, vec2 occluder, vec2 whichCorner){
    corner = whichCorner*(max(whichCorner*corner,whichCorner*occluder));
}

//i'll be calling the +b direction "top" and the +a direction "left", both of these directions are away from src
//as though you're looking along the +z direction and the light is going +x+y
void determineOcclusion(lightVoxData[2][2] samples, bool[2][2] relevance, bvec2 alignment, bool[2][2] obstructions, vec3 lightTravel, float scale,
    out vec2 outRay, out bvec4 outMap
){
    float halfScale = 0.5*scale;

    float slopeScaleNear = abs(scale/(lightTravel.z-halfScale));
    float slopeScaleFar  = abs(scale/(lightTravel.z+halfScale));
    vec2 outerSlope  = abs(lightTravel.xy+halfScale)*slopeScaleNear;  //anything more than this will not be visible
    vec2 middleSlope = abs(lightTravel.xy-halfScale)*slopeScaleNear;  //ray going to the center corner of the 4 relevant samples
    vec2 innerSlope  = abs(lightTravel.xy-halfScale)*slopeScaleFar;   //anything less than this will not be visible


    //    bestLight.occlusionRay = abs(bestLight.lightTravel.xy/(bestLight.lightTravel.z-0.5));
//    middleSlope = abs(lightTravel.xy/(lightTravel.z-0.5));

    vec2[2][2] corners = {{vec2(-1,-1),vec2(-1,2)},{vec2(2,-1),vec2(2,2)}};

    //corners from blocks
    for(int i=0; i<2; i++){
        for (int j=0; j<2; j++){
            if(obstructions[i][j]){
                occludeCorner(corners[i][j],middleSlope,vec2(1-(i<<1),1-(j<<1)));
            }
        }
    }

    //corners from samples
    for(int i=0; i<2; i++){
        for(int j=0; j<2; j++){
            if(!relevance[i][j])
                continue;
      }
    }


    outMap = bvec4( !(corners[1][1].x<=outerSlope.x && corners[1][1].y<=outerSlope.y), !(corners[0][1].x>=innerSlope.x && corners[0][1].y<=outerSlope.y),
                    !(corners[1][0].x<=outerSlope.x && corners[1][0].y>=innerSlope.y), !(corners[0][0].x>=innerSlope.x && corners[0][0].y>=innerSlope.y));

    bvec4 edges = getOcclusionEdges(outMap);

//    outMap = edges;

    if(edges.x)
        outRay.x=min(corners[1][0].x,corners[1][1].x);
    if(edges.y)
        outRay.y=min(corners[0][1].y,corners[1][1].y);
    if(edges.z)
        outRay.x=max(corners[0][0].x,corners[0][1].x);
    if(edges.w)
        outRay.y=max(corners[0][0].y,corners[1][0].y);

    int cornerCount = int(outMap.x)+int(outMap.y)+int(outMap.z)+int(outMap.w);
    if(cornerCount==3){//only one corner is obstructed
        if(!outMap.x) outRay=corners[1][1];
        if(!outMap.y) outRay=corners[0][1];
        if(!outMap.z) outRay=corners[1][0];
        if(!outMap.w) outRay=corners[0][0];
    }

//    outRay = abs(middleSlope);
//    outMap = bvec2(true,false).xyyx;
//        outRay = abs(lightTravel.xy/(lightTravel.z-0.5));
}





//for one voxel face, determines the light entering that voxel face
//based on the 9 adjacent voxel faces in the previous plane & the nearby terrain voxels
void lightVoxelFace(ivec3 sectionPos, uint section,ivec3 progress,uint axisNum){
    float scale = 1;

    lightVoxData[3][3] inputSamples;
    uvec4[3][3] frontVoxels;
    uvec4[3][3] rearVoxels;
    bool[3][3] obstructions;

    //all the relevant memory accesses
    takeSamples(sectionPos,scale,
        inputSamples, frontVoxels, rearVoxels, obstructions
    );


    //determine best light source first
    lightVoxData bestLight = determineBestLightSource(
        scale, inputSamples, frontVoxels, rearVoxels, obstructions
    );


    // then pick the 4 relevant input samples
    // (the voxels further from the center of the light source do not contribute)
    lightVoxData[2][2] relevantSamples;
    bool[2][2] relevance;
    bvec2 alignment;
    bool[2][2] newObstructions;

    pickRelevantInputSamples(bestLight, inputSamples, obstructions, scale,
        relevantSamples, relevance, alignment, newObstructions);

    determineOcclusion(relevantSamples, relevance, alignment, newObstructions, bestLight.lightTravel, scale,
        bestLight.occlusionRay, bestLight.occlusionMap);

    //could maybe be at the top, not sure how much it'd actually help though TODO test later
    if (frontVoxels[1][1].w>0xf){
        bestLight.lightTravel = vec3(0);
        bestLight.color = frontVoxels[1][1].rgb*(1.0/255.0);
        bestLight.emission = frontVoxels[1][1].w>>4;
        bestLight.occlusionMap=bvec4(true);
    }

//    bestLight.occlusionRay = abs(bestLight.lightTravel.xy/(bestLight.lightTravel.z-0.5));
//    bestLight.occlusionMap = bvec2(true,false).xyyx;

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

