
#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE
#define SAMPLES_VOX
#include "/lib/voxel/voxelHelper.glsl"


uniform int frameCounter;
int frameOffset = frameCounter%UPDATE_STRIDE;

layout(std430, binding = 1) restrict buffer indirectDispatches {
    uvec3 dispatches;
} indirectDispatchesAccess;

//const ivec3 workGroups = ivec3(SECTIONS_PER_ZONE,NUM_AREAS,1);

layout (local_size_x = SECTION_SIZE, local_size_y = SECTION_SIZE, local_size_z = 1) in;



#if 0 //dummy definition because intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;uint emission;vec3 lightTravel;float columnation;};
#endif


#ifdef PARALLEL_UNPACK
shared lightVoxData[SECTION_SIZE+2][SECTION_SIZE+2][VOX_LAYERS] sharedSamples;
shared uvec4[SECTION_SIZE+2][SECTION_SIZE+2] sharedFrontVoxels;
shared uvec4[SECTION_SIZE+2][SECTION_SIZE+2] sharedRearVoxels;
#endif


lightVoxData[3][3][VOX_LAYERS] inputSamples;
uvec4[3][3] frontVoxels, rearVoxels;
bool[3][3] obstructions, translucents;
ivec3[VOX_LAYERS] zonePos;
ivec4 areaPos;       //xyz in area mem space, w is area num
ivec3 sectionOffset; //0 to SECTION_SIZE-1
float scale,halfScale;
uint axis;
uint A,B; //1 to SECTION_SIZE
bool translucentsPresent;



void takeSamples(){

    translucentsPresent = false;

    ivec3 aVec = ivec3(areaToZoneSpaceMats[axis][0]);
    ivec3 bVec = ivec3(areaToZoneSpaceMats[axis][1]);
    ivec3 LVec = ivec3(areaToZoneSpaceMats[axis][2]);

    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            ivec3 localOffset = a*aVec+b*bVec;
            uvec4 frontVoxel = getVoxData(areaPos.xyz+localOffset);
            uvec4 rearVoxel = getVoxData(areaPos.xyz+localOffset-LVec);

            bool obstructedOpaque =  ((rearVoxel.w&3u)==1) || ((frontVoxel.w&3u)==1);
            obstructions[a+1][b+1] = obstructedOpaque;

            #ifdef COLORED_TRANSLUCENTS
            bool obstructedTranslucent = ((rearVoxel.w&3u)==2) || ((frontVoxel.w&3u)==2) && !obstructedOpaque;
            translucents[a+1][b+1] = obstructedTranslucent;
            translucentsPresent = translucentsPresent || obstructedTranslucent;
            #endif

            frontVoxels[a+1][b+1] = frontVoxel;
            rearVoxels[a+1][b+1] = rearVoxel;
        }
    }



    #ifdef PARALLEL_UNPACK
    const int halfwayL = SECTION_SIZE / 2;
    const int halfwayH = halfwayL+1;

    uint A2offset=0;
    uint B2offset=0;

    // ↙←     i need samples adjacent to the main region, because an N wide square needs input of width N+2
    // ↙      this shows the direction of the offset for each square inside the corner region, shown for width 8
    // ↙  ↓
    // ↙↙↙↙   (And yes I went out of my way to copypaste these arrows)
    if(A==1 || A==SECTION_SIZE || B==1 || B==SECTION_SIZE){
        A2offset = A<=halfwayL?-1:1;
        B2offset = B<=halfwayL?-1:1;
    }else if((A==halfwayL || A==halfwayH) && (B==2 || B==(SECTION_SIZE-1))){
        B2offset = B<=halfwayL?-2:2;
    }else if((B==halfwayL || B==halfwayH) && (A==2 || A==(SECTION_SIZE-1))){
        A2offset = A<=halfwayL?-2:2;
    }

//    sharedFrontVoxels[A][B] = getVoxData(areaPos.xyz);
//    sharedRearVoxels[A][B] = getVoxData(areaPos.xyz-LVec);

    for(int layer = 0; layer<VOX_LAYERS; layer++){
        ivec3 tmp = zonePos[layer];
        tmp.z--;
        sharedSamples[A][B][layer] = getLightData(tmp);
        if ((A2offset|B2offset) !=0){
            tmp.xy+=ivec2(A2offset,B2offset);
            sharedSamples[A+A2offset][B+B2offset][layer] = getLightData(tmp);
        }
    }

//    memoryBarrierShared();
    groupMemoryBarrier();
    #endif

    for (int a=-1;a<=1;a++){
        for (int b=-1; b<=1;b++){
            uvec4 frontVoxel=frontVoxels[a+1][b+1];
            uvec4 rearVoxel =rearVoxels[a+1][b+1];

            for(int layer = 0; layer<VOX_LAYERS; layer++){
                lightVoxData inputSample;
                #if defined PARALLEL_UNPACK
                inputSample = sharedSamples[A+a][B+b][layer];
                #else
                inputSample = getLightData(zonePos[layer]+ivec3(a,b, -1));
                #endif

            

                if((rearVoxel.w&3u)==1){
                    inputSample=noLight;
                }
                inputSamples[a+1][b+1][layer] = inputSample;
            }
        }
    }
}



const uint shortListLen = 2*VOX_LAYERS;

lightVoxData[VOX_LAYERS] determineBestLightSources(){
    lightVoxData[VOX_LAYERS] bestLights;
    float[VOX_LAYERS] bestStrengths;
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        bestLights[layer] = noLight;
        bestStrengths[layer] = 0;
    }

    float halfScale = 0.5*scale;

#ifdef SHORTLISTED_COMPARISON
    lightVoxData[shortListLen] shortList;
    float[shortListLen] shortListStr;

    for(int i = 0; i<VOX_LAYERS; i++){
        shortListStr[i]=0;
        bestLights[i] = noLight;
    }
    int shortListOccupation=0;
#else
    #define shortListStr bestStrengths
    #define shortList bestLights
    #define shortListOccupation VOX_LAYERS
#endif


    for (int a=-1; a<=1;a++){
        for (int b=-1; b<=1;b++){
            if(obstructions[a+1][b+1] || //block in front
                ( (obstructions[a+1][1]) && (obstructions[1][b+1]) && ((a|b)!=0))){ //neighboring blocks between src and center
                continue;
            }

            for(int layer = 0; layer<VOX_LAYERS; layer++){
                lightVoxData lightSrc = inputSamples[a+1][b+1][layer];
                lightSrc.lightTravel+=vec3(-a, -b, 1)*scale;

                if((lightSrc.emission==0) || (lightSrc.lightTravel.x*a>0) || (lightSrc.lightTravel.y*b>0))
                    continue;

                bool newItem = true;
                for (int i = 0; i<shortListOccupation; i++){ //can maybe make it ordered to allow binary search
                    newItem=newItem && !(lightSrc.lightTravel==shortList[i].lightTravel && lightSrc.color==shortList[i].color);//also check direction here
                }
                //even in the non-shortlisted version, this branch is coherent enough to be worth the overhead
                if((!newItem))
                    continue;

                float lenSquared = dot(lightSrc.lightTravel, lightSrc.lightTravel);
                lenSquared = lenSquared*(1-lightSrc.columnation)+lightSrc.columnation;
                float strength = length(lightSrc.color)/max(0.1, lenSquared);

#ifdef SHORTLISTED_COMPARISON
                uint indexToUse = -1;
                if (shortListOccupation<shortListLen){
                    indexToUse=shortListOccupation;
                    shortListOccupation++;
                }else{
                    //TODO handle this case.
                }

                shortList[indexToUse]=lightSrc;
                shortListStr[indexToUse]=strength;
            }
        }
    }


    for(int i=0;i<shortListOccupation;i++){ { {
                lightVoxData lightSrc = shortList[i];
                float strength = shortListStr[i];

#endif

        //Okay so this is a little wacky but basically, if shortlisted comparisons is on, this loop and the previous for loops are separate
        //if its false, the following code is nested within the previous loop instead of the section starting with indexToUse
        //its a little messy, but the alternative is just 95% duplicated code and would be hard to keep synced
        //I could also easily remove all this later
                vec3 lightTravel = lightSrc.lightTravel;
                vec2 xy = abs(lightTravel.xy);
                vec2 outerSlope  = (xy+halfScale)* abs(scale/(lightTravel.z-halfScale));  //anything more than this will not be visible
                vec2 innerSlope  = (xy-halfScale)*abs(scale/(lightTravel.z+halfScale));

                if(!canIlluminateInBounds(vec4(outerSlope,innerSlope),lightSrc.occlusionRay,lightSrc.occlusionMap))
                    continue;


                for(int rank = 0; rank<VOX_LAYERS; rank++){
                    if (strength>bestStrengths[rank]){
                        float tmpStr = bestStrengths[rank];
                        lightVoxData tmpSrc = bestLights[rank];

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
void pickRelevantInputSamples(lightVoxData bestSource,
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
                relevantSample.lightTravel+=vec3(-a, -b, 1)*scale;

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
void determineOcclusion(lightVoxData[2][2] samples, bool[2][2] relevance, bvec2 alignment, bool[2][2] relevantObstructions, vec3 lightTravel,
    out vec2 outRay, out bvec4 outMap
){

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
            if(relevantObstructions[i][j]){
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


    outMap = bvec4( !(corners[1][1].x<outerSlope.x && corners[1][1].y<outerSlope.y), !(corners[0][1].x>innerSlope.x && corners[0][1].y<outerSlope.y),
                    !(corners[1][0].x<outerSlope.x && corners[1][0].y>innerSlope.y), !(corners[0][0].x>innerSlope.x && corners[0][0].y>innerSlope.y));



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



//
lightVoxData doLightPassage(inout lightVoxData bestLight){
    lightVoxData[2][2] relevantSamples;
    bool[2][2] relevance;
    bvec2 alignment;
    bool[2][2] newObstructions;


    pickRelevantInputSamples(bestLight,
    relevantSamples, relevance, alignment, newObstructions);

    determineOcclusion(relevantSamples, relevance, alignment, newObstructions, bestLight.lightTravel,
    bestLight.occlusionRay, bestLight.occlusionMap);

    if (bestLight.emission==0 || !(bestLight.occlusionMap.x||bestLight.occlusionMap.y||bestLight.occlusionMap.z||bestLight.occlusionMap.w)){
        bestLight=noLight;//TODO just be aware of
    }
    return bestLight;
}


//for one voxel face, determines the light entering that voxel face
//based on the 9 adjacent voxel faces in the previous plane & the nearby terrain voxels
void lightVoxelFace(){

    //all the relevant memory accesses
    takeSamples();


    //determine best light source first
    lightVoxData[VOX_LAYERS] bestLights = determineBestLightSources();

    #ifdef COLORED_TRANSLUCENTS
    lightVoxData transucentPassage = bestLights[0];
//        transucentPassage = inputSamples[1][1][0];
    #endif


    for (int i=0;i<3;i++){
        for (int j=0; j<3;j++){
            obstructions[i][j] = obstructions[i][j] || translucents[i][j];
        }
    }

    for(int layer = 0; layer<VOX_LAYERS; layer++){
        doLightPassage(bestLights[layer]);
    }

    //actual coherent branch
    #ifdef COLORED_TRANSLUCENTS
    if(translucentsPresent){
        for(int i=0; i<3; i++){
            for(int j=0; j<3; j++){
                uint frontw = frontVoxels[i][j].w&3u;
                uint rearw = rearVoxels[i][j].w&3u;

                //TODO this is trash
                obstructions[i][j]= (rearw==1) || (frontw==1) ||
                (true&&(rearw==0 || frontw == 0));

                obstructions[i][j] = !((frontw==2 || rearw==2 )&& !((rearw==1) || (frontw==1)));
            }
        }

        ivec2 travelDirSign = ivec2(sign(transucentPassage.lightTravel.xy));

        int translucentBlocksInSample = 0;
        vec3 color = vec3(0);

        for(int i=0; i<2; i++){
            int a = (i-1)*travelDirSign.x;
            for (int j=0; j<2; j++){
                int b = (j-1)*travelDirSign.y;
                bool frontTrans = (frontVoxels[a+1][b+1].w&3u)==2;
                bool rearTrans = (rearVoxels[a+1][b+1].w&3u)==2;
                rearTrans=false;
                translucentBlocksInSample += int(frontTrans) + int(rearTrans);
                if(frontTrans)
                    color+=vec3(frontVoxels[a+1][b+1].xyz)/255;
                if(rearTrans)
                    color+=vec3(rearVoxels[a+1][b+1].xyz)/255;
            }
        }


        if(translucentBlocksInSample>0){
            color/=translucentBlocksInSample;

            doLightPassage(transucentPassage);
            transucentPassage.color*=color;

            bestLights[VOX_LAYERS-1]=transucentPassage; //TODO better insert
        }
    }
    #endif

    //could maybe be at the top, not sure how much it'd actually help though TODO test later
    if (frontVoxels[1][1].w>0xf){
        bestLights[VOX_LAYERS-1].lightTravel = vec3(0);
        bestLights[VOX_LAYERS-1].color = frontVoxels[1][1].rgb*(1.0/255.0);
        bestLights[VOX_LAYERS-1].emission = frontVoxels[1][1].w>>4;
        bestLights[VOX_LAYERS-1].occlusionMap=bvec4(true);
        bestLights[VOX_LAYERS-1].columnation=0.2;
    }

    for(int layer = 0; layer<VOX_LAYERS; layer++){
        setLightData(bestLights[layer], areaPos, axis, layer);
    }
}

void lightVoxelFaces(uvec3 groupId, uvec3 localId){
//    if(((frameCounter>>4)&0xff)>0x80)
//        return;

    A = localId.x+1;
    B = localId.y+1;

    uint zoneOffset = groupId.x;
    ivec3 sectionBasePos = (ivec3(zoneOffset>>(AREA_WIDTH_SECTIONS_SHIFT+AREA_WIDTH_SECTIONS_SHIFT),
        zoneOffset>>AREA_WIDTH_SECTIONS_SHIFT,
        zoneOffset)&(AREA_WIDTH_SECTIONS-1))*SECTION_SIZE;
    sectionBasePos+=1;

    areaPos.w = int(groupId.y);


    scale = 1;
    halfScale=0.5*scale;




#if DEBUG_AXIS>=0
    axis = debugAxisNum;
#else ifndef AXES_INORDER
    axis = groupId.z;
#else
    for(axis=0;axis<6;axis++)
#endif
    {

        ivec3 aVec = ivec3(areaToZoneSpaceMats[axis][0]);
        ivec3 bVec = ivec3(areaToZoneSpaceMats[axis][1]);
        ivec3 LVec = ivec3(areaToZoneSpaceMats[axis][2]);

//        ivec3 sectionOffsetInitial = ivec3(localId.x*aVec+localId.y*bVec);
//        if ((axis&1u)==0)
//            sectionPosInitial.xyz-=15*LVec;



#if SECTION_SIZE==UPDATE_STRIDE
        uint offset = frameOffset;
#else
        for (int offset = frameOffset;offset<SECTION_SIZE;offset+=UPDATE_STRIDE)
#endif
        {

            int L = ((axis&1u)==0)? offset-(SECTION_SIZE-1):offset;

            sectionOffset = ivec3(localId.x*aVec+localId.y*bVec) + L*LVec;
            areaPos.xyz = ivec3(sectionOffset+sectionBasePos);

            for(int layer = 0; layer<VOX_LAYERS; layer++)
                zonePos[layer]=areaToZoneSpace(areaPos,axis,layer);

            lightVoxelFace();
        }
    }

}

