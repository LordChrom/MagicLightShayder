
#define READS_LIGHT_FACE
#define WRITES_LIGHT_FACE
#define READS_VOX
#include "/lib/voxel/voxelHelper.glsl"


uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;

const int groupCountXY = 1;

#if DEBUG_AXIS<0
const int groupCountZ = groupCountXY*6;
#else
const int groupCountZ = groupCountXY;
#endif

//const ivec3 workGroups = ivec3(groupCountXY,groupCountXY,groupCountZ);
const ivec3 workGroups = ivec3(1,1,6);
layout (local_size_x = SECTION_WIDTH, local_size_y = SECTION_WIDTH, local_size_z = 1) in;

#if false //dummy definition because intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;uint emission;vec3 lightTravel;};
#endif





void takeSamples(ivec4 sectionPos, float scale, uint axis,
    out lightVoxData[3][3][VOX_LAYERS] inputSamples, out uvec4[3][3] frontVoxels, out uvec4[3][3] rearVoxels, out bool[3][3] obstructions
){

    ivec3 aVec = ivec3(worldToSectionSpaceMats[axis][0]);
    ivec3 bVec = ivec3(worldToSectionSpaceMats[axis][1]);
    ivec3 LVec = ivec3(worldToSectionSpaceMats[axis][2]);

    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            ivec3 localOffset = a*aVec+b*bVec;
            uvec4 frontVoxel = getVoxData(sectionPos.xyz+localOffset);
            uvec4 rearVoxel = getVoxData(sectionPos.xyz+localOffset-LVec);

            bool rearObstructed = (rearVoxel.w&1u)==1;
            bool frontObstructed = (frontVoxel.w&1u)==1;

            for(int layer = 0; layer<VOX_LAYERS; layer++){
                ivec3 faceSpacePos = sectionToFaceSpace(sectionPos, axis, layer);

                lightVoxData inputSample = getLightData(faceSpacePos+ivec3(a, b, -1));
                inputSample.lightTravel+=vec3(-a, -b, 1)*scale;
                if(rearObstructed)
                    inputSample=noLight;
                inputSamples[a+1][b+1][layer] = inputSample;
            }

            obstructions[a+1][b+1] = rearObstructed || frontObstructed;//TODO make better
            frontVoxels[a+1][b+1] = frontVoxel;
            rearVoxels[a+1][b+1] = rearVoxel;
        }
    }
}



lightVoxData[VOX_LAYERS] determineBestLightSources( float scale,
    lightVoxData[3][3][VOX_LAYERS] inputSamples, uvec4 [3][3] frontVoxels, uvec4 [3][3] rearVoxels, bool [3][3] obstructions
){
    lightVoxData[VOX_LAYERS] bestLights;
    float[VOX_LAYERS] bestStrengths;
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        bestLights[layer] = noLight;
        bestStrengths[layer] = 0;
    }

//    uint layer = 0;

    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){


            bool isCenter = (a|b)==0;

            bool selfOccluded = obstructions[a+1][b+1];

            //if corner, its neighbors. If edge, itself and center. If center, itself twice
            //in any case, these both being blocked means no light from this input voxel
            bool helpersOccluded = (obstructions[a+1][1]) && (obstructions[1][b+1]);
            bool outerSrcBlocked = (helpersOccluded && !isCenter) || selfOccluded;

            for(int layer = 0; layer<VOX_LAYERS; layer++){

                lightVoxData lightSrc = inputSamples[a+1][b+1][layer];

                if (lightSrc.emission==0)
                    continue;

                vec3 displ = lightSrc.lightTravel;
                float lenSquared = dot(displ, displ);
                float strength = float(lightSrc.emission)/max(0.1, lenSquared);
                displ.xy+=vec2(a, b)*scale;


                bool srcBlocked = outerSrcBlocked || (displ.x*a>0) || (displ.y*b>0);//will be unnecessary soontm

                //occlusion stuff goes here, maybe

                if (srcBlocked){
                    inputSamples[a+1][b+1][layer].emission=0;
                    continue;
                }

                //make this sort more efficient than insertion sort if scaling layer count
                for(int rank = 0; rank<VOX_LAYERS; rank++){
                    lightVoxData tmpSrc = bestLights[rank];
                    if(tmpSrc.lightTravel==lightSrc.lightTravel &&
                        tmpSrc.color == lightSrc.color){
                        rank=VOX_LAYERS;
                        continue;
                    }
                    if (strength>bestStrengths[rank]){
                        float tmpStr = bestStrengths[rank];

                        bestLights[rank]=lightSrc;
                        bestStrengths[rank]=strength;

                        lightSrc=tmpSrc;
                        strength=tmpStr;
                    }

                }
            }
        }
    }

    return bestLights;
}



//out of 9 input samples, only up to 4 can have any light flowing between the source and the output
//for all 2x2 selected sample arrays, corner closest to source at [0][0], output sample at [1][1]
//newObstructions is flipped to match this, with [2][2] being the firthest corner from source
void pickRelevantInputSamples(lightVoxData bestSource, lightVoxData[3][3][VOX_LAYERS] inputSamples, bool[3][3] obstructions, float scale,
    out lightVoxData[2][2] samples, out bool[2][2] relevance, out bvec2 alignment, out bool[2][2] newObstructions){

    vec3 lightTravel = bestSource.lightTravel;
    int aSignSrc = int(sign(lightTravel.x));
    int bSignSrc = int(sign(lightTravel.y));
    alignment = bvec2(bSignSrc==0,aSignSrc==0);

    for(int i=0; i<2; i++){
        int a = (i-1)*aSignSrc;
        for(int j=0; j<2; j++){
            int b = (j-1)*bSignSrc;
            bool blockBlocked = obstructions[1+a][1+b];
            newObstructions[i][j]=blockBlocked;
            bool alignedX = (lightTravel.x-a*scale==0);
            bool alignedY = (lightTravel.y-b*scale==0);

            if((alignment.x&&j==0)||(alignment.y&&i==0)||(blockBlocked)){
                samples[i][j]=noLight;
                relevance[i][j]=false;
                continue;
            }

            for(int layer = 0; layer<VOX_LAYERS; layer++){
                lightVoxData relevantSample = inputSamples[1+a][1+b][layer];
                bool sameSource = (relevantSample.lightTravel==bestSource.lightTravel)
                && relevantSample.emission == bestSource.emission
                && relevantSample.color == bestSource.color;

                if (sameSource){
                    relevance[i][j] = true;
                    samples[i][j] = relevantSample;
                }
            }

        }
    }

    bool cornerBlocked = (newObstructions[1][0] && newObstructions[0][1]);
    newObstructions[0][0] = newObstructions[0][0] || cornerBlocked;
    relevance[0][0]=relevance[0][0]&&!cornerBlocked;

}



//for this function only, 1,1 is top left corner, -1,-1 is bottom right corner
void occludeCorner(inout float cornerX, inout float cornerY, vec2 occluder, vec2 whichCorner){
    cornerX = whichCorner.x*(min(whichCorner.x*cornerX,whichCorner.x*occluder.x));
    cornerY = whichCorner.y*(min(whichCorner.y*cornerY,whichCorner.y*occluder.y));
}

void occludeCorner(inout vec2 corner, vec2 occluder, vec2 whichCorner){
    occludeCorner(corner.x,corner.y,occluder,whichCorner);
}

//i'll be calling the +b direction "top" and the +a direction "left", both of these directions are away from src
//as though you're looking along the +z direction and the light is going +x+y
void determineOcclusion(lightVoxData[2][2] samples, bool[2][2] relevance, bvec2 alignment, bool[2][2] obstructions, vec3 lightTravel, float scale,
    out vec2 outRay, out bvec4 outMap
){
    float halfScale = 0.5*scale;

    lightTravel.xy=abs(lightTravel.xy);
    float slopeScaleNear = abs(scale/(lightTravel.z-halfScale));
    float slopeScaleFar  = abs(scale/(lightTravel.z+halfScale));
    vec2 outerSlope  = (lightTravel.xy+halfScale)*slopeScaleNear;  //anything more than this will not be visible
    vec2 middleSlope = (lightTravel.xy-halfScale)*slopeScaleNear;  //ray going to the center corner of the 4 relevant samples
    vec2 innerSlope  = (lightTravel.xy-halfScale)*slopeScaleFar;   //anything less than this will not be visible

    outRay=abs(lightTravel.xy/lightTravel.z);


    vec2[2][2] corners = {{vec2(-1,-1),vec2(-1,2)},{vec2(2,-1),vec2(2,2)}};

    //corners from blocks
    for(int i=0; i<2; i++){
        for (int j=0; j<2; j++){
            if(obstructions[i][j]){
                occludeCorner(corners[i][j],middleSlope,vec2((i<<1)-1,(j<<1)-1));
            }
        }
    }

    bool anyRelevantSamples = false;


    for(int i=0; i<2; i++){
        for(int j=0; j<2; j++){
            if((!relevance[i][j]) || (i==0 && alignment.y) || (j==0 && alignment.x))
                continue;

            //1 if outer of block is inner of sample, -1 if outer
            bvec4 map = samples[i][j].occlusionMap;
            vec2 ray = samples[i][j].occlusionRay;


            bool inOuterA = ray.x<=outerSlope.x|| true;
            bool inOuterB = ray.y<=outerSlope.y|| true;
            bool inInnerA = ray.x>=innerSlope.x;
            bool inInnerB = ray.y>=innerSlope.y;


//            bool truncatedAl = false;
//            bool truncatedAh = false;
//            bool truncatedBl = false;
//            bool truncatedBr = false;
            bool truncatedA = false;
            bool truncatedB = false;
            if(i==1){
                lightVoxData innerNeighbor = samples[0][j];
                truncatedA = (innerNeighbor.occlusionRay.x>=innerSlope.x) &&
                            innerNeighbor.occlusionMap.y&&innerNeighbor.occlusionMap.w &&
                            !(innerNeighbor.occlusionMap.x&&innerNeighbor.occlusionMap.z);
            }
            if(j==1){
                lightVoxData innerNeighbor = samples[i][0];
                truncatedB = (innerNeighbor.occlusionRay.y>=innerSlope.y) &&
                            innerNeighbor.occlusionMap.z&&innerNeighbor.occlusionMap.w &&
                            !(innerNeighbor.occlusionMap.x&&innerNeighbor.occlusionMap.y);
            }

//            truncatedA=false;
//            truncatedB=false;


            anyRelevantSamples = anyRelevantSamples ||
            (map.x&&inOuterA&&inOuterB)||
            (map.y&&inInnerA&&inOuterB)||
            (map.z&&inOuterA&&inInnerB)||
            (map.w&&inInnerA&&inInnerB);



            if((!map.x) && inOuterA && inOuterB){
                vec2 oldCorner = corners[1][1];
                oldCorner.x=min(oldCorner.x,inInnerA?ray.x:2);
                oldCorner.y=min(oldCorner.y,inInnerB?ray.y:2);
                corners[1][1]=oldCorner;
            }
            if((!map.y) && inOuterB && inInnerA && !truncatedA){
                vec2 oldCorner = corners[0][1];
                oldCorner.x=max(oldCorner.x,ray.x);
                oldCorner.y=min(oldCorner.y,inInnerB?ray.y:2);
                corners[0][1]=oldCorner;
            }
            if((!map.z) && inOuterA && inInnerB && !truncatedB){
                vec2 oldCorner = corners[1][0];
                oldCorner.x=min(oldCorner.x,inInnerA?ray.x:2);
                oldCorner.y=max(oldCorner.y,ray.y);
                corners[1][0]=oldCorner;
            }
            if((!map.w) && inOuterA && inOuterB && (inInnerA && inInnerB) && !(truncatedA || truncatedB)){
                vec2 oldCorner = corners[0][0];
                oldCorner.x=max(oldCorner.x,ray.x);
                oldCorner.y=max(oldCorner.y,ray.y);
                corners[0][0]=oldCorner;
            }

      }
    }


    outMap = bvec4( !(corners[1][1].x<=outerSlope.x && corners[1][1].y<=outerSlope.y), !(corners[0][1].x>=innerSlope.x && corners[0][1].y<=outerSlope.y),
                    !(corners[1][0].x<=outerSlope.x && corners[1][0].y>=innerSlope.y), !(corners[0][0].x>=innerSlope.x && corners[0][0].y>=innerSlope.y));



    bvec4 edges = getOcclusionEdges(outMap);

    bool aEdges = edges.x||edges.z;
    bool bEdges = edges.y||edges.w;

    if(edges.x /*&&!bEdges*/)
        outRay.x=min(corners[1][0].x,corners[1][1].x);
    if(edges.y /*&&!aEdges*/)
        outRay.y=min(corners[1][1].y,corners[0][1].y);
    if(edges.z /*&&!bEdges*/)
        outRay.x=max(corners[0][1].x,corners[0][0].x);
    if(edges.w /*&&!aEdges*/)
        outRay.y=max(corners[0][0].y,corners[1][0].y);


    int edgeCount = int(edges.x)+int(edges.y)+int(edges.z)+int(edges.w);
    if(edgeCount==0){//only one corner is obstructed
        if(!(edges.x||edges.z)) outRay.x=0;
        if(!(edges.y||edges.w)) outRay.y=0;
        if(!outMap.x) outRay=corners[1][1];
        if(!outMap.y) outRay=corners[0][1];
        if(!outMap.z) outRay=corners[1][0];
        if(!outMap.w) outRay=corners[0][0];
    }


    if(alignment.x){
        outMap=and(outMap, outMap.zwxy);
        outRay.y=0;
    }
    if(alignment.y){
        outMap=and(outMap, outMap.yxwz);
        outRay.x=0;
    }

    if(!anyRelevantSamples){
        outMap=bvec4(false);
    }

}





//for one voxel face, determines the light entering that voxel face
//based on the 9 adjacent voxel faces in the previous plane & the nearby terrain voxels
void lightVoxelFace(ivec4 sectionPos, uint section,uint axis){
    float scale = 1;

    lightVoxData[3][3][VOX_LAYERS] inputSamples;
    uvec4[3][3] frontVoxels;
    uvec4[3][3] rearVoxels;
    bool[3][3] obstructions;

    //all the relevant memory accesses
    takeSamples(sectionPos,scale, axis,
        inputSamples, frontVoxels, rearVoxels, obstructions
    );


    //determine best light source first
    lightVoxData[VOX_LAYERS] bestLights = determineBestLightSources(
        scale, inputSamples, frontVoxels, rearVoxels, obstructions
    );


    for(int layer = 0; layer<VOX_LAYERS; layer++){
        lightVoxData bestLight = bestLights[layer];

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

        if (bestLight.emission==0 || !(bestLight.occlusionMap.x||bestLight.occlusionMap.y||bestLight.occlusionMap.z||bestLight.occlusionMap.w)){
            bestLight=noLight;//TODO just be aware of
        }
        bestLights[layer]=bestLight;
    }

    //could maybe be at the top, not sure how much it'd actually help though TODO test later
    if (frontVoxels[1][1].w>0xf){
        bestLights[VOX_LAYERS-1].lightTravel = vec3(0);
        bestLights[VOX_LAYERS-1].color = frontVoxels[1][1].rgb*(1.0/255.0);
        bestLights[VOX_LAYERS-1].emission = frontVoxels[1][1].w>>4;
        bestLights[VOX_LAYERS-1].occlusionMap=bvec4(true);
    }

    for(int layer = 0; layer<VOX_LAYERS; layer++){
        setLightData(bestLights[layer], sectionPos, axis, layer);
    }
}

void lightVoxelFaces(uvec3 groupId, uvec3 localId){
    uint section = 0;

    #if DEBUG_AXIS<0
    uint axis = groupId.z;
    #else
    uint axis = debugAxisNum;
    #endif

    ivec3 aVec = ivec3(worldToSectionSpaceMats[axis][0]);
    ivec3 bVec = ivec3(worldToSectionSpaceMats[axis][1]);
    ivec3 LVec = ivec3(worldToSectionSpaceMats[axis][2]);



    ivec4 sectionPos = ivec4(localId.x*aVec+localId.y*bVec,section); //TODO change
    if((axis&1u)==0)
        sectionPos.xyz-=15*LVec;
    sectionPos.xyz+=1;

    for(int i = frameOffset;i<SECTION_DEPTH;i+=UPDATE_STRIDE){
        lightVoxelFace(sectionPos+ivec4(LVec*i,0),section,axis);
    }
}

