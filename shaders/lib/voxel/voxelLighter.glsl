#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE
#define SAMPLES_VOX
#include "/lib/voxel/voxelHelper.glsl"

//workGroups is indirect, determined in voxelSeamFill
layout (local_size_x = SECTION_SIZE, local_size_y = SECTION_SIZE, local_size_z = LOCAL_SIZE_Z) in;


shared uvec4[SECTION_SIZE+2][SECTION_SIZE+2][VOX_LAYERS] sharedPackedSamples;
shared uint[SECTION_SIZE+2][SECTION_SIZE+2] sharedPackedFrontVoxels;
shared uint[SECTION_SIZE+2][SECTION_SIZE+2] sharedPackedRearVoxels;

//same accross group
ivec3 zoneShift,areaShift, upZoneShift, upAreaShift;
ivec3 aVec, bVec, LVec;
float scale,halfScale;
uint axis, cascadeLevel;

//different per invocation
ivec3 areaPos, zonePos;
uint A,B; //1 to SECTION_SIZE


uvec4 getInputSample(int a, int b, uint layer){return sharedPackedSamples[A+a][B+b][layer];}
uint getFrontVoxel(int a, int b){return sharedPackedFrontVoxels[A+a][B+b];}
uint getRearVoxel(int a, int b){return sharedPackedRearVoxels[A+a][B+b];}

uvec4 maybeBlockLight(uvec4 light, uint voxel){
    return (
        bool(voxel&WORLDVOX_OPAQUE)
        || ((bool(voxel&WORLDVOX_TRANSLUCENT)) &&!bool(unpackLightFlags(light)&1u))
#if MAX_LIGHT_TRAVEL > 0
        || (unpackLightTravel(light).z>MAX_LIGHT_TRAVEL)
#endif
    )? uvec4(0):light;
}

void saveSharedSample(int a, int b){
    ivec3 sampleZonePos = zonePos+ivec3(a, b, -1);
    bool sideOob =
        (sampleZonePos.x<0) || (sampleZonePos.x>=AREA_SIZE) ||
        (sampleZonePos.y<0) || (sampleZonePos.y>=AREA_SIZE) ;
    bool rearOob = (sampleZonePos.z<0) || (sampleZonePos.z>=AREA_SIZE) ;
    uint sampleCascade = cascadeLevel;
    uint areaMemOffset = areaOffset(cascadeLevel);
    uint sampleAreaMemOffset = areaMemOffset;
    ivec3 sampleZoneShift = zoneShift;
    ivec3 sampleAreaShift = areaShift;
    ivec3 frontVoxelPos = areaPos.xyz+ivec3(aVec*a + bVec*b);
    ivec3 rearVoxelPos = frontVoxelPos-LVec;

    vec3 zonePosRemnants;


    if(sideOob || rearOob){
        sampleZonePos = uppperCascadeZonePos(zonePos,zoneShift,axis,scale,zonePosRemnants);
        zonePosRemnants.z-=scale;
        sampleCascade++;
        sampleZoneShift=upZoneShift;
        sampleAreaShift=upAreaShift;
        sampleAreaMemOffset = areaOffset(sampleCascade);

        if(sideOob)
            frontVoxelPos=upperCascadeAreaPos(frontVoxelPos,areaShift);
        rearVoxelPos=upperCascadeAreaPos(rearVoxelPos,areaShift);

        if(cascadeLevel>=(NUM_CASCADES-1)){
            sharedPackedRearVoxels[A+a][B+b]=sharedPackedFrontVoxels[A+a][B+b]=0u;
            uvec4 defaultLight = ((!hasCeiling) && axis==2 && zonePos.z<=0) ? defaultSunLight : noLight;
    #ifdef DEBUG_DISABLE_SUN
            defaultLight=noLight;
    #endif
            for(int layer = 0; layer<VOX_LAYERS; layer++){
                sharedPackedSamples[A+a][B+b][layer] = defaultLight;
            }
            return;
        }
    }

    sharedPackedFrontVoxels[A+a][B+b] = getVoxData(frontVoxelPos,sideOob?sampleAreaShift:areaShift,sideOob?sampleAreaMemOffset:areaMemOffset);

    uint rearVoxel = sharedPackedRearVoxels[A+a][B+b] = getVoxData(rearVoxelPos,sampleAreaShift,sampleAreaMemOffset);
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        uvec4 light = sampleLightData(sampleZonePos, sampleZoneShift, zoneOffset(axis,layer,sampleCascade));
        if(rearOob && (unpackLightType(light)!=LIGHT_TYPE_SUN)){
            setPackedLightTravel(light,unpackLightTravel(light)+zonePosRemnants);
        }

        sharedPackedSamples[A+a][B+b][layer] = maybeBlockLight(light,rearVoxel);
    }

}



ivec2 getBonusPosOffset(){
    const int halfwayL = SECTION_SIZE / 2;
    const int halfwayH = halfwayL+1;

    // ↙←     i need samples adjacent to the main region, because an N wide square needs input of width N+2
    // ↙      this shows the direction of the offset for each square inside the corner region, shown for width 8
    // ↙  ↓
    // ↙↙↙↙   (And yes I went out of my way to copypaste these arrows) Min section size is 6x6 because of this
    if(A==1 || A==SECTION_SIZE || B==1 || B==SECTION_SIZE){
        return ivec2(
            A<=halfwayL?-1:1,
            B<=halfwayL?-1:1
        );
    }else if((A==halfwayL || A==halfwayH) && (B==2 || B==(SECTION_SIZE-1))){
        return ivec2(0, B<=halfwayL?-2:2);
    }else if((B==halfwayL || B==halfwayH) && (A==2 || A==(SECTION_SIZE-1))){
        return ivec2(A<=halfwayL?-2:2,0);
    }else
        return ivec2(0);
}

void takeSamples(){
    saveSharedSample(0,0);
    ivec2 bonusPos = getBonusPosOffset();
    if (bonusPos!=ivec2(0)){
        saveSharedSample(bonusPos.x,bonusPos.y);
    }

    barrier(); //disable for fun party :)
}



const uint shortListLen = 2*VOX_LAYERS;

uvec4[VOX_LAYERS] determineBestLightSources(){
    uvec4[VOX_LAYERS] bestLights;
    float[VOX_LAYERS] bestStrengths;
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        bestLights[layer]=uvec4(0);
        bestStrengths[layer] = 0;
    }


    for (int a=-1; a<=1;a++){
        for (int b=-1; b<=1;b++){
            if(bool((getRearVoxel(a,b)|getFrontVoxel(a,b))&WORLDVOX_OPAQUE) || //block in front
                ( bool(getFrontVoxel(a,0)&WORLDVOX_OPAQUE) && bool(getFrontVoxel(0,b)&WORLDVOX_OPAQUE) && ((a|b)!=0))){ //neighboring blocks between src and center
                continue;
            }

            for(int layer = 0; layer<VOX_LAYERS; layer++){
                uvec4 lightSrc = getInputSample(a,b,layer);
                uint type = unpackLightType(lightSrc);
                vec3 travel = unpackLightTravel(lightSrc);
                if(type!=LIGHT_TYPE_SUN){
                    travel+=vec3(-a, -b, 1)*scale;
                    setPackedLightTravel(lightSrc,travel);
                }

                if((type==0) || (travel.x*a>0) || (travel.y*b>0))
                    continue;

                float lenSquared = dot(travel, travel);
                float strength = (1+length(unpackLightColor(lightSrc)))/max(0.1, lenSquared);
                if(type==LIGHT_TYPE_SUN)
                    strength*=1e3;

                vec2 xy = abs(travel.xy);
                vec2 outerSlope  = (xy+halfScale) * abs(scale/(travel.z-halfScale));
                vec2 innerSlope  = (xy-halfScale) * abs(scale/(travel.z+halfScale));

                if(!canIlluminateInBounds(vec4(outerSlope,innerSlope),unpackOcclusionRay(lightSrc.w),unpackOcclusionMap(lightSrc.w)))
                    continue;

                for(int rank = 0; rank<VOX_LAYERS; rank++){
                    if(sameLight(lightSrc,bestLights[rank]))
                        break;

                    if (strength>bestStrengths[rank]){
                        float tmpStr = bestStrengths[rank];
                        uvec4 tmpSrc = bestLights[rank];

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
//alignment.x means it is on the a axis,
void pickRelevantInputSamples(uvec4 bestSource, bool translucentTerrain,
    out uvec4[2][2] samples, out bool[2][2] relevance, out bvec2 alignment, out bool[2][2] newObstructions){

    vec3 lightTravel = unpackLightTravel(bestSource);
    int aSignSrc = int(sign(lightTravel.x));
    int bSignSrc = int(sign(lightTravel.y));
    alignment = bvec2(bSignSrc==0,aSignSrc==0);

    uint[2][2] localFronts;
    uint[2][2] localRears;

    for(int i=0; i<2; i++){
        int a = (i-1)*aSignSrc;
        for (int j=0; j<2; j++){
            int b = (j-1)*bSignSrc;
            samples[i][j]=uvec4(0);
            relevance[i][j]=false;
            localFronts[i][j]=getFrontVoxel(a,b);
            localRears[i][j]=getRearVoxel(a,b);
        }
    }

    bool sampleFreshlyTranslucent = bool(unpackLightFlags(bestSource)&1u);
    uint obstructingTerrainMask = (sampleFreshlyTranslucent || translucentTerrain)?WORLDVOX_OPAQUE:WORLDVOX_NOT_AIR;
    bool cornerBlocked = !(alignment.x||alignment.y);

    if(bool(localFronts[1][1]&WORLDVOX_TRANSLUCENT)&&!(sampleFreshlyTranslucent || translucentTerrain))
        return;

#ifdef UNOCCLUDED_INTO_BLOCKS
    bool frontBlockedCompletely = bool(localFronts[1][1]&WORLDVOX_OPAQUE);
#endif

    //i=0 means a=offset, i=1 means a=0;
    for(int i=0; i<2; i++){
        int a = (i-1)*aSignSrc;
        for(int j=0; j<2; j++){
            int b = (j-1)*bSignSrc;

            uint front = localFronts[i][j];
            uint rear = localRears[i][j];

#ifdef UNOCCLUDED_INTO_BLOCKS
            if(frontBlockedCompletely){
                front&=~WORLDVOX_OPAQUE;
                rear&=~WORLDVOX_OPAQUE;
            }
#endif
            bool rearTranslucent = bool(rear&WORLDVOX_TRANSLUCENT);


            bool blockBlocked = bool((front|rear)&obstructingTerrainMask)
            ||
                ((!bool(front&WORLDVOX_TRANSLUCENT)&&translucentTerrain) && ( //only cutoff the outside when its at the front
                    (i==1 && aSignSrc!=0)||
                    (j==1 && bSignSrc!=0)
                ))
            ||
                ((!bool(rear&WORLDVOX_TRANSLUCENT)&&translucentTerrain) && (
                    (i==0&&bool(localRears[1][j]&WORLDVOX_TRANSLUCENT))||
                    (j==0&&bool(localRears[i][1]&WORLDVOX_TRANSLUCENT)))
                )
            ;

            //TODO figure out if this is necessary after handling the opposing corners case
            cornerBlocked = cornerBlocked && (i==j || bool(front&WORLDVOX_OPAQUE));

            newObstructions[i][j]=blockBlocked;

            if((alignment.x&&j==0) || (alignment.y&&i==0) || blockBlocked)
                continue;


            for(int layer = 0; layer<VOX_LAYERS; layer++){
                uvec4 relevantSample = getInputSample(a,b,layer);
                if(lightTravel.x*a>0 || lightTravel.y*b>0)
                    continue;

                setPackedLightTravel(relevantSample,
                    unpackLightTravel(relevantSample) + vec3(-a, -b, 1)*scale
                );

                if (sameLight(relevantSample,bestSource)){
                    relevance[i][j] = true;
                    samples[i][j] = relevantSample;
                    break;
                }
            }

        }
    }

    newObstructions[0][0] = newObstructions[0][0] || cornerBlocked;
    relevance[0][0]=relevance[0][0]&&!cornerBlocked;
}



//i'll be calling the +b direction "top" and the +a direction "left", both of these directions are away from src
//as though you're looking along the +z direction, with light traveling along L=+z and also somewhat +x+y
void doOcclusionOld(uvec4[2][2] samples, bool[2][2] relevance, bvec2 alignment, bool[2][2] relevantObstructions,
    inout uvec4 lightSrc
){
    vec3 travel = unpackLightTravel(lightSrc);
    vec2 travel2d= abs(travel.xy);
    float slopeScaleNear = abs(1/(travel.z-halfScale));
    float slopeScaleFar  = abs(1/(travel.z+halfScale));
    vec2 outerSlope  = (travel2d.xy+halfScale)*slopeScaleNear;  //anything more than this will not be visible
    vec2 middleSlope = (travel2d.xy-halfScale)*slopeScaleNear;  //ray going to the center corner of the 4 relevant samples
    vec2 innerSlope  = (travel2d.xy-halfScale)*slopeScaleFar;   //anything less than this will not be visible

    vec2 outRay = vec2(0);
    outRay=abs(travel2d/travel.z);
    uint outMap = unpackOcclusionMap(lightSrc.w);
    float outHitDist = unpackOcclusionHitDist(lightSrc.w);



    //each corner is represented by (cornersX.N,cornersY.N), with N corresponding to
    //the same corner as represented by occlusionMap.N
    vec4 cornersX=vec4(2,-1,2,-1);
    vec4 cornersY=vec4(2,2,-1,-1);

    vec4 litBounds = vec4(outerSlope.xy,innerSlope.xy);
    vec4 shadedBounds = litBounds;

    bool anyRelevantSamples = false;


    for(int i=0; i<2; i++){
        for(int j=0; j<2; j++){
            if((!relevance[i][j]) || (i==0 && alignment.y) || (j==0 && alignment.x))
                continue;


            uint map = unpackOcclusionMap(samples[i][j].w);
            vec2 ray = unpackOcclusionRay(samples[i][j].w);

            uint lightEdges = getLightEdges(map); //left, top, right, bottom
            uint darkEdges = getOcclusionEdges(map);

            //for all of these, it will truncate the outer bounds if both samples on that edge are lit,
            //but one or both of the inner samples are obstructed.
            //this is mostly for when edges intersect at a corner to prevent the edges from continuing past that corner

            lightEdges = lightEdges & ~((lightEdges<<2)|(lightEdges>>2));
            uint darkEdges2 = darkEdges & ~((darkEdges<<2)|(darkEdges>>2));
            if(i==1 && bool(lightEdges&8u))   //left
                litBounds.x = min(litBounds.x,ray.x);
            if(j==1 && bool(lightEdges&4u))   //top
                litBounds.y = min(litBounds.y,ray.y);
            if(i==0 && bool(lightEdges&2u))   //right
                litBounds.z = max(litBounds.z,ray.x);
            if(j==0 && bool(lightEdges&1u))   //bottom
                litBounds.w = max(litBounds.w,ray.y);

            if(i==1 && bool(darkEdges2&8u))   //left
                shadedBounds.x = min(shadedBounds.x,ray.x);
            if(j==1 && bool(darkEdges2&4u))   //top
                shadedBounds.y = min(shadedBounds.y,ray.y);
            if(i==0 && bool(darkEdges2&2u))   //right
                shadedBounds.z = max(shadedBounds.z,ray.x);
            if(j==0 && bool(darkEdges2&1u))   //bottom
                shadedBounds.w = max(shadedBounds.w,ray.y);

            vec4 sX=ternary(map,vec4(2,-1,2,-1),vec4(ray.x)); //represents the ways this sample shadows the output's
            vec4 sY=ternary(map,vec4(2,2,-1,-1),vec4(ray.y)); //corners

            uint shadowedCorners = (~map)&bvec4ToUint(bvec4(
                sX.x<outerSlope.x && sY.x<outerSlope.y,
                sX.y>innerSlope.x && sY.y<outerSlope.y,
                sX.z<outerSlope.x && sY.z>innerSlope.y,
                sX.w>innerSlope.x && sY.w>innerSlope.y
            ));

            if(bool(shadowedCorners&8u)){
                cornersX.x=min(cornersX.x,(sX.x>=innerSlope.x)?ray.x:2);
                cornersY.x=min(cornersY.x,(sY.x>=innerSlope.y)?ray.y:2);
            }
            if(bool(shadowedCorners&4u)){
                cornersX.y=max(cornersX.y,ray.x);
                cornersY.y=min(cornersY.y,(sY.y>=innerSlope.y)?ray.y:2);
            }
            if(bool(shadowedCorners&2u)){
                cornersX.z=min(cornersX.z,(sX.z>=innerSlope.x)?ray.x:2);
                cornersY.z=max(cornersY.z,ray.y);
            }
            if(bool(shadowedCorners&1u)){
                cornersX.w=max(cornersX.w,ray.x);
                cornersY.w=max(cornersY.w,ray.y);
            }


            bool thisSampleRelevant = bool(15u^shadowedCorners);
            anyRelevantSamples = anyRelevantSamples || thisSampleRelevant;

            if(thisSampleRelevant
                &&bool(darkEdges&bvec4ToUint(bvec4(ray.x<outerSlope.x,ray.y<outerSlope.y,ray.x>innerSlope.x,ray.y>innerSlope.y)))
            ){
                outHitDist=max(outHitDist, unpackOcclusionHitDist(samples[i][j].w));
            }
        }
    }


    bool newObstruction= false;

    //TODO shape of shadows of corners should maybe be a little different
    if(!alignment.y){
        if(relevantObstructions[0][0]&&!alignment.x){
            newObstruction=newObstruction||(middleSlope.x>cornersX.w || middleSlope.y>cornersY.w);
            cornersX.w=max(cornersX.w,middleSlope.x);
            cornersY.w=max(cornersY.w,middleSlope.y);
            litBounds.z=litBounds.w=-1;
        }
        if(relevantObstructions[0][1]){
            newObstruction=newObstruction||(middleSlope.x>cornersX.y || (middleSlope.y<cornersY.y&&!alignment.x));
            cornersX.y=max(cornersX.y,middleSlope.x);
            cornersY.y=min(cornersY.y,middleSlope.y);
            litBounds.y=2;
            litBounds.z=-1;
        }
    }
    {
        if(relevantObstructions[1][0]&&!alignment.x){
            newObstruction=newObstruction||((middleSlope.x<cornersX.z &&!alignment.y) || middleSlope.y>cornersY.z);
            cornersX.z=min(cornersX.z,middleSlope.x);
            cornersY.z=max(cornersY.z,middleSlope.y);
            litBounds.x=2;
            litBounds.w=-1;
        }
        if(relevantObstructions[1][1]){
            newObstruction=newObstruction||((middleSlope.x<cornersX.x &&!alignment.y) || (middleSlope.y<cornersY.x&&!alignment.x));
            cornersX.x=min(cornersX.x,middleSlope.x);
            cornersY.x=min(cornersY.x,middleSlope.y);
            litBounds.x=litBounds.y=2;
        }
    }

    if(newObstruction && (outHitDist<=0)){  //TODO still needs work
        outHitDist=travel.z-0.6*scale;
    }

    outerSlope=min(outerSlope,0.999);

    outMap = 15^(bvec4ToUint(bvec4(
        cornersX.x<outerSlope.x, cornersX.y>innerSlope.x,
        cornersX.z<outerSlope.x, cornersX.w>innerSlope.x
    )) & bvec4ToUint(bvec4(
        cornersY.x<outerSlope.y, cornersY.y<outerSlope.y,
        cornersY.z>innerSlope.y, cornersY.w>innerSlope.y
    )));

    if(cornersY.z>=outerSlope.y && !bool(outMap&2u)){
        outMap&=7u;
    }
    if(cornersY.w>=outerSlope.y && !bool(outMap&1u)){
        outMap&=11u;
    }

    if(cornersX.y>=outerSlope.x && !bool(outMap&4u)){
        outMap&=7u;
    }
    if(cornersX.w>=outerSlope.x && !bool(outMap&1u)){
        outMap&=13u;
    }


    //TODO better way of combining these at corners of conflicting types
    //the inner ones before the outer ones helps stuff like corners of glass shadows
    if(innerSlope.x<max(litBounds.z,shadedBounds.z)){
        outMap = (outMap&10u)|(5u*uint(litBounds.z>shadedBounds.z));
    }
    if(innerSlope.y<max(litBounds.w,shadedBounds.w)){
        outMap = (outMap&12u)|(3u*uint(litBounds.w>shadedBounds.w));
    }

    if(outerSlope.x>min(litBounds.x,shadedBounds.x)){
        outMap = (outMap&5u)|(10u*uint(litBounds.x<shadedBounds.x));
    }
    if(outerSlope.y>min(litBounds.y,shadedBounds.y)){
        outMap = (outMap&3u)|(12u*uint(litBounds.y<shadedBounds.y));
    }

    uint edges = getOcclusionEdges(outMap); //left, top, right, bottom
    int edgeCount = anyRelevantSamples? bitCount(edges): 4;

    switch(edgeCount){
        //TODO improve the opposite corners one (esp. with one glass one solid)
        case 0: //no corner, 1 corner, or opposite corners
            uint notOutMap = ~outMap;
            outRay=vec2(0);
            if(bool(notOutMap&8u)) outRay=vec2(cornersX.x,cornersY.x);
            if(bool(notOutMap&4u)) outRay=vec2(cornersX.y,cornersY.y);
            if(bool(notOutMap&2u)) outRay=vec2(cornersX.z,cornersY.z);
            if(bool(notOutMap&1u)) outRay=vec2(cornersX.w,cornersY.w);
            break;

        case 1: //one edge
            if(bool(edges&8u))
                outRay.x=min(cornersX.z,cornersX.x);
            if(bool(edges&4u))
                outRay.y=min(cornersY.x,cornersY.y);
            if(bool(edges&2u))
                outRay.x=max(cornersX.y,cornersX.w);
            if(bool(edges&1u))
                outRay.y=max(cornersY.w,cornersY.z);
            break;

        case 2: //L shape
            outRay = bool(edges&1u)? //arranged by which corner is lit
                (bool(edges&2u)?vec2(cornersX.y,cornersY.z):vec2(cornersX.x,cornersY.w)):
                (bool(edges&2u)?vec2(cornersX.w,cornersY.x):vec2(cornersX.z,cornersY.y));
            break;
        default:
        case 4:
            outMap=0u;
    }

    if(alignment.x){
        outMap = outMap&((outMap<<2) | (outMap>>2));
        outRay.y=0;
    }
    if(alignment.y){
        outMap = outMap&(((outMap&5u)<<1) | ((outMap&10u)>>1));
        outRay.x=0;
    }

    lightSrc.w=packOcclusionInfo(outRay,outMap, outHitDist);
}


//TODO after this is all done, test removing all the packing/unpacking
//also replace the bool arrays with uints
uint getTerrainOcclusion(vec3 travel, bool[2][2] relevantObstructions, bvec2 alignment){
    vec2 ray = (abs(travel.xy)-halfScale)/abs(travel.z-halfScale);
    uint map = 15u^bvec4ToUint(bvec4(relevantObstructions[1][1],relevantObstructions[0][1],relevantObstructions[1][0],relevantObstructions[0][0]));
    float hitDist = travel.z-0.6*scale;

    if(alignment.x){
        map = map&((map<<2) | (map>>2));
        ray.y=0;
    }
    if(alignment.y){
        map = map&(((map&5u)<<1) | ((map&10u)>>1));
        ray.x=0;
    }

    return (map==15u)?NO_OCCLUSION:packOcclusionInfo(ray, map, hitDist);
}

bool occlusionsPerfectlyCombinable(uint mapA, uint mapB){
    uint edgesA = getOcclusionEdges(mapA);
    uint edgesB = getOcclusionEdges(mapB);
    uint typeA = bitCount(mapA);
    uint typeB = bitCount(mapB);

    return false;
}

uint combineOcclusions(uint occlusionA, uint occlusionB){
    vec2 rayA = unpackOcclusionRay(occlusionA);
    vec2 rayB = unpackOcclusionRay(occlusionB);
    uint mapA = unpackOcclusionMap(occlusionA);
    uint mapB = unpackOcclusionMap(occlusionB);
    return occlusionB;
}

void doOcclusion(uvec4[2][2] samples, bool[2][2] relevance, bvec2 alignment, bool[2][2] relevantObstructions,
    inout uvec4 lightSrc
){
//#define NEW_OCCLUSION
#ifndef NEW_OCCLUSION
    if(true){
        doOcclusionOld(samples,relevance,alignment,relevantObstructions,lightSrc);
        return;
    }
#endif

    vec3 travel = unpackLightTravel(lightSrc);
    uint terrainOcclusion = getTerrainOcclusion(travel,relevantObstructions,alignment);
    lightSrc.w=combineOcclusions(lightSrc.w,terrainOcclusion);
}





void doLightPassage(inout uvec4 bestLight, bool translucentTerrain){
    uvec4[2][2] relevantSamples;
    bool[2][2] relevance;
    bvec2 alignment;
    bool[2][2] newObstructions;


    pickRelevantInputSamples(bestLight, translucentTerrain,
    relevantSamples, relevance, alignment, newObstructions);

    doOcclusion(relevantSamples, relevance, alignment, newObstructions, bestLight);

#if !(defined KEEP_FULLY_OCCLUDED_SAMPLES && defined DEBUG_OCCLUSION_MAP)
    if ( !bool(unpackOcclusionMap(bestLight.w))){
        bestLight=uvec4(0);
    }
#endif
}


//for one voxel face, determines the light entering that voxel face
//based on the 9 adjacent voxel faces in the previous plane & the nearby terrain voxels
void lightVoxelFace(){
    takeSamples();
    uvec4[VOX_LAYERS] bestLights = determineBestLightSources();


#ifdef COLORED_TRANSLUCENTS
    uvec4 translucentPassage = bestLights[0];

    ivec2 travelDirSign = ivec2(sign(unpackLightTravel(translucentPassage).xy));

    int translucentBlocksInSample = 0;
    vec3 color = vec3(0);

    for(int i=0; i<2; i++){
        int a = (i-1)*travelDirSign.x;
        for (int j=0; j<2; j++){
            int b = (j-1)*travelDirSign.y;

            uint front = getFrontVoxel(a,b);
            uint rear = getRearVoxel(a,b);

            bool frontTrans = bool(front&WORLDVOX_TRANSLUCENT);
            bool rearTrans = bool(rear&WORLDVOX_TRANSLUCENT);
            rearTrans=false;
            translucentBlocksInSample += int(frontTrans) + int(rearTrans);
            if(frontTrans)
                color+=worldVoxColor(front);
            if(rearTrans)
                color+=worldVoxColor(rear);
        }
    }

    if(translucentBlocksInSample>0){
        color/=translucentBlocksInSample;

        doLightPassage(translucentPassage,true);
        if(bool(unpackOcclusionMap(translucentPassage.w))){
            setPackedLightColor(translucentPassage,unpackLightColor(translucentPassage)*color);
            setPackedLightFlags(translucentPassage,unpackLightFlags(translucentPassage)|1u); //TODO make this not dumb

            bestLights[VOX_LAYERS-1]=translucentPassage;
        }else{
            translucentBlocksInSample=0;
        }
    }
#endif

    for(int layer = 0; layer<VOX_LAYERS; layer++){
#ifdef COLORED_TRANSLUCENTS
        if(translucentBlocksInSample>0 && layer==VOX_LAYERS-1) break;
#endif
        doLightPassage(bestLights[layer],false);
        setPackedLightFlags(bestLights[layer],unpackLightFlags(bestLights[layer])&0xfeu);
    }

    //could maybe be at the top, not sure how much it'd actually help though TODO test later
    uint front = getFrontVoxel(0,0);
    if (bool(front&(0xfu<<VOXEL_TYPE_SHIFT))){
        vec3 lightTravel;
#ifdef LIGHT_SOURCES_BLOCK_CENTERIC
        if(scale<1){
            vec3 worldPos = vec3(areaPos.xyz)*scale-halfScale+globalOrigin;
            vec3 subBlockOffset = areaToZoneSpaceRelative((worldPos-round(worldPos)),axis);
            lightTravel = subBlockOffset;
        }else
#endif
        {
            lightTravel = vec3(0);
        }
        bestLights[VOX_LAYERS-1] = packLightData(vec2(0),15u,worldVoxColor(front),lightTravel,0,(front>>VOXEL_TYPE_SHIFT)&0xfu,0);
    }


    for(int layer = 0; layer<VOX_LAYERS; layer++){
        setLightData(bestLights[layer], zonePos, zoneShift, zoneOffset(axis,layer,cascadeLevel));
    }

}

void lightVoxelFaces(uvec3 groupId, uvec3 localId){
    ivec3 zoneBasePos = ivec3(
        localId.x+(groupId.x%AREA_WIDTH_SECTIONS)*SECTION_SIZE,
        localId.y+(groupId.x/AREA_WIDTH_SECTIONS)*SECTION_SIZE,
        (groupId.y)*UPDATE_STRIDE
    );

    int frameBasedOffset = frameCounter;
    cascadeLevel = getVariableCascadeLevel(frameBasedOffset,bool(groupId.z&1u));
    if(cascadeLevel>=NUM_CASCADES) return;
#ifdef DOUBLE_PROC
    frameBasedOffset=(frameBasedOffset>>cascadeLevel);
#else
    frameBasedOffset=(frameBasedOffset>>(cascadeLevel+1));
#endif

    A = localId.x+1;
    B = localId.y+1;


    scale = getScale(cascadeLevel);
    areaShift = getAreaShift(scale);
    upAreaShift = getAreaShift(scale*2);
    halfScale=0.5*scale;

#if DEBUG_AXIS>=0
    axis = DEBUG_AXIS;
#else
    axis = groupId.z/PROC_MULT;
#endif

    aVec = ivec3(areaToZoneSpaceMats[axis][0]);
    bVec = ivec3(areaToZoneSpaceMats[axis][1]);
    LVec = ivec3(areaToZoneSpaceMats[axis][2]);
    zoneShift = areaToZoneSpace(areaShift,axis);
    upZoneShift = areaToZoneSpace(upAreaShift,axis);

    frameBasedOffset = (frameBasedOffset*LIGHTING_SYSTEM_PASSES-zoneShift.z + LIGHTER_PASS)%UPDATE_STRIDE;


#ifdef WAVES_INORDER
    for(;frameBasedOffset<AREA_SIZE;frameBasedOffset+=UPDATE_STRIDE)
#endif
    {
        int offset = frameBasedOffset;
        zonePos = ivec3(zoneBasePos.xy, zoneBasePos.z+offset);
        areaPos = zoneToAreaSpace(zonePos, axis);

        lightVoxelFace();
    }
}