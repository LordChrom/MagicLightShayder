#define SAMPLES_LIGHT_FACE
#define WRITES_LIGHT_FACE
#define SAMPLES_VOX
#include "/lib/voxel/voxelHelper.glsl"

#ifdef WAVES_INORDER
    #define LIGHTER_WORK_GROUP_Z 1
#else
    #define LIGHTER_Z_EXACT AREA_SIZE/UPDATE_STRIDE

    //TODO make this more complete from the script
    #if LIGHTER_Z_EXACT<=1
        #define LIGHTER_WORK_GROUP_Z 1
    #elif LIGHTER_Z_EXACT<=2
        #define LIGHTER_WORK_GROUP_Z 2
    #elif LIGHTER_Z_EXACT<=4
        #define LIGHTER_WORK_GROUP_Z 4
    #elif LIGHTER_Z_EXACT<=8
        #define LIGHTER_WORK_GROUP_Z 8
    #else
        #define LIGHTER_WORK_GROUP_Z 16
    #endif

#endif

#if AREA_WIDTH_SECTIONS<=1
    #define LIGHTER_WORK_GROUP_X 1
#elif AREA_WIDTH_SECTIONS<=2
    #define LIGHTER_WORK_GROUP_X 4
#elif AREA_WIDTH_SECTIONS<=4
    #define LIGHTER_WORK_GROUP_X 16
#elif AREA_WIDTH_SECTIONS<=8
    #define LIGHTER_WORK_GROUP_X 64
#elif AREA_WIDTH_SECTIONS<=16
    #define LIGHTER_WORK_GROUP_X 256
#else
    #define LIGHTER_WORK_GROUP_X 1024
#endif
const ivec3 workGroups = ivec3(LIGHTER_WORK_GROUP_X,LIGHTER_WORK_GROUP_Y,LIGHTER_WORK_GROUP_Z);
layout (local_size_x = SECTION_SIZE, local_size_y = SECTION_SIZE, local_size_z = LOCAL_SIZE_Z) in;

//different per invocation
ivec3 areaPos = ivec3(0);
ivec3 zonePos = ivec3(0);
#define A (gl_LocalInvocationID.x+1)
#define B (gl_LocalInvocationID.y+1)

#ifdef SSBO_WORKSPACE
    layout(std430, binding = 0) buffer ssbo0 {
        uvec4[][SECTION_SIZE+2][SECTION_SIZE+2] bufferedWorkData;
    };

    uint workGroupOffset;


    uvec4 getInputSample(int a, int b, uint layer){
        return bufferedWorkData[layer+workGroupOffset][A+a][B+b];
    }
    void setSharedSample(int a, int b, uint layer, uvec4 data){
        bufferedWorkData[layer+workGroupOffset][A+a][B+b]= data;
    }
#else
    shared uvec4[SECTION_SIZE+2][SECTION_SIZE+2][LIGHT_LAYERS] sharedPackedPool;
    uvec4 getInputSample(int a, int b, uint layer){return sharedPackedPool[A+a][B+b][layer];}
    void setSharedSample(int a, int b, uint layer, uvec4 data){
        sharedPackedPool[A+a][B+b][layer]=data;
    }
#endif

shared uint[SECTION_SIZE+2][SECTION_SIZE+2] sharedPackedFrontVoxels;
shared uint[SECTION_SIZE+2][SECTION_SIZE+2] sharedPackedRearVoxels;

void setSharedVoxels(int a, int b,uint front, uint rear){
    sharedPackedFrontVoxels[A+a][B+b]=front;
    sharedPackedRearVoxels[A+a][B+b]=rear;
}

uint getFrontVoxel(int a, int b){return sharedPackedFrontVoxels[A+a][B+b];}
uint getRearVoxel(int a, int b){return sharedPackedRearVoxels[A+a][B+b];}

//same accross group
ivec3 zoneShift = ivec3(0);
ivec3 areaShift = ivec3(0);
ivec3 upZoneShift = ivec3(0);
ivec3 upAreaShift = ivec3(0);
float scale = 0;
uint axis = 0;
uint cascadeLevel = 0;


#ifdef FALLBACK_RADIANCE
uvec4 radiance = uvec4(0);
#endif


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
    uint sampleCascade = cascadeLevel;
    uint areaMemOffset = areaOffset(cascadeLevel);
    uint sampleAreaMemOffset = areaMemOffset;
    ivec3 sampleZoneShift = zoneShift;
    ivec3 sampleAreaShift = areaShift;
    ivec3 frontVoxelPos = areaPos.xyz+ivec3(aVec(axis)*a + bVec(axis)*b);
    ivec3 rearVoxelPos = frontVoxelPos-lVec(axis);

    bool sideOob = voxelIsSplit(frontVoxelPos,areaShift,cascadeLevel) ||
        (sampleZonePos.x<0) || (sampleZonePos.x>=AREA_SIZE) ||
        (sampleZonePos.y<0) || (sampleZonePos.y>=AREA_SIZE) ;
    bool rearOob = voxelIsSplit(rearVoxelPos,areaShift,cascadeLevel) || (sampleZonePos.z<0) || (sampleZonePos.z>=AREA_SIZE) ;

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
            setSharedVoxels(a,b,0u,0u);
            uvec4 defaultLight = ((!hasCeiling) && zonePos.z<=0) ? getSunlight(axis) : uvec4(0);
    #ifdef DEBUG_DISABLE_SUN
            defaultLight=uvec4(0);
    #endif
            for(int layer = 0; layer<VOX_LAYERS; layer++){
                setSharedSample(a,b,layer,defaultLight);
            }
        #ifdef FALLBACK_RADIANCE
            setSharedSample(a,b,RADIANCE_LAYER,uvec4(0));
        #endif
            return;
        }
    }

    uint frontVoxel = getVoxData(frontVoxelPos,sideOob?sampleAreaShift:areaShift,sideOob?sampleAreaMemOffset:areaMemOffset);

    uint rearVoxel = getVoxData(rearVoxelPos,sampleAreaShift,sampleAreaMemOffset);
    setSharedVoxels(a,b,frontVoxel,rearVoxel);
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        uvec4 light = sampleLightData(sampleZonePos, sampleZoneShift, zoneOffset(axis,layer,sampleCascade));
        if(rearOob && (unpackLightType(light)!=LIGHT_TYPE_SUN)){
            setPackedLightTravel(light,unpackLightTravel(light)+zonePosRemnants);
        }

        setSharedSample(a,b,layer,maybeBlockLight(light,rearVoxel));
    }


#ifdef FALLBACK_RADIANCE
    uvec4 r = uvec4(0);
    //TOOD recoloring radiance
    if(!bool(rearVoxel&WORLDVOX_OPAQUE)){
       r = sampleLightData(sampleZonePos, sampleZoneShift, zoneOffset(axis,RADIANCE_LAYER,sampleCascade));
    }
    setSharedSample(a,b,RADIANCE_LAYER,r);
#endif

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
//    memoryBarrier();
}



uvec4 convertToRadiance(uvec4 lightSrc){
    vec3 color = unpackLightColor(lightSrc).rgb*BLOCK_LIGHT_STRENGTH;

    vec3 displacement = unpackLightTravel(lightSrc);
    float lengthSquared = dot(displacement,displacement);
    float columnation = MIN_COLUMNATION;
    lengthSquared = lengthSquared*(1-columnation)+columnation;
    const float b = 1/float(MAX_LIGHT_STRENGTH*MAX_LIGHT_STRENGTH);

    color*=pow(lengthSquared*lengthSquared*(1-columnation)+b,-0.8); //the -0.8 is a fudge
    return uvec4(packUnorm4x8(0.25*vec4(color,0)));
}

uvec4 combineRadiance(uvec4 a, uvec4 b, float weight){
    uvec4 ret;
    for(int i=0; i<4; i++){
        vec4 color = 4*(unpackUnorm4x8(a[i])+weight*unpackUnorm4x8(b[i]));
        float len = length(color);
        if(len>2)
            color*=(0.3*(len-2)+2)/len;
        ret[i]=packUnorm4x8(0.25*color);
    }
    return ret;
}

uvec4[VOX_LAYERS] determineBestLightSources(){
    uvec4[VOX_LAYERS] bestLights;
    uint[VOX_LAYERS] bestStrengths;
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        bestLights[layer]=uvec4(0);
        bestStrengths[layer] = 0;
    }



    uint blocksInFront = 0;

    for (int a=-1; a<=1;a++){
        for (int b=-1; b<=1;b++){
            #ifdef FALLBACK_RADIANCE
            uvec4 sampleRad = getInputSample(a, b, VOX_LAYERS);
            if(a<0)
                sampleRad.xz=uvec2(0);
            else if(a>0)
                sampleRad.yw=uvec2(0);

            if(b<0)
                sampleRad.xy=uvec2(0);
            else if(b>0)
                sampleRad.zw=uvec2(0);

            const float[] weights = {0.4,0.2,0.15};
            radiance = combineRadiance(radiance, sampleRad, weights[abs(a)+abs(b)]);
            #endif

            #ifndef UNOCCLUDED_INTO_BLOCKS
            bool blockInFront = bool((getRearVoxel(a,b)|getFrontVoxel(a,b))&WORLDVOX_OPAQUE)
            || ( bool(getFrontVoxel(a,0)&WORLDVOX_OPAQUE) && bool(getFrontVoxel(0,b)&WORLDVOX_OPAQUE) && ((a|b)!=0));  //neighboring blocks between src and center
            blocksInFront |= (uint(blockInFront)<<uint(16+a+(b<<2)));
            #endif
        }
    }

    for(int layer = 0; layer<VOX_LAYERS; layer++){
        for (int a=-1; a<=1;a++){
            for (int b=-1; b<=1;b++){
                uvec4 lightSrc = getInputSample(a,b,layer);
                #if defined READS_MUST_BE_UNIFORM && !defined UNOCCLUDED_INTO_BLOCKS
                if(bool(blocksInFront&(1u<<uint(16+a+(b<<2))))) continue;
                #endif
                uint type = unpackLightType(lightSrc);
                vec3 travel = unpackLightTravel(lightSrc);
                if(type!=LIGHT_TYPE_SUN){
                    travel+=vec3(-a, -b, 1)*scale;
                    setPackedLightTravel(lightSrc,travel);
                }

                if((type==0) || (travel.x*a>0) || (travel.y*b>0))
                    continue;
                uint strength = getLightStrength(lightSrc);
#ifdef FALLBACK_RADIANCE
                strength = (strength&~1u)|uint(a==0&&b==0);
#endif


                vec2 xy = abs(travel.xy);
                float halfScale = 0.5*scale;
                vec2 outerSlope  = (xy+halfScale) * abs(scale/(travel.z-halfScale));
                vec2 innerSlope  = (xy-halfScale) * abs(scale/(travel.z+halfScale));

                uint occlusion = getPackedOcclusion(lightSrc);
                if(!canIlluminateInBounds(vec4(outerSlope,innerSlope),unpackOcclusionRay(occlusion),unpackOcclusionMap(occlusion)))
                    continue;

#ifdef FALLBACK_RADIANCE
                const int lastRank = VOX_LAYERS+1;
#else
                const int lastRank = VOX_LAYERS;
#endif

                for(int rank = 0; rank<lastRank; rank++){
#ifdef FALLBACK_RADIANCE
                    if(rank==VOX_LAYERS){
                        if(bool(strength))
                            radiance=combineRadiance(radiance,convertToRadiance(lightSrc),1);
                        break;
                    }
#endif

                    if(sameLight(lightSrc,bestLights[rank]))
                        break;

                    if (strength>bestStrengths[rank]){
                        uint tmpStr = bestStrengths[rank];
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
    out uint[2][2][OCCLUDERS_PER_LIGHT] relevantOcclusionSamples, out bool[2][2] relevance, out bvec2 alignment, out bool[2][2] newObstructions
){

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
            relevantOcclusionSamples[i][j][0]=0u;
            relevance[i][j]=false;
            localFronts[i][j]=getFrontVoxel(a,b);
            localRears[i][j]=getRearVoxel(a,b);
        }
    }

    bool sampleFreshlyTranslucent = bool(unpackLightFlags(bestSource)&1u);
//    bool sampleLeavingGlass = sampleFreshlyTranslucent && bool(localRears[1][1]&WORLDVOX_TRANSLUCENT) && !bool(localFronts[1][1]&WORLDVOX_TRANSLUCENT) ;
    uint obstructingTerrainMask = (sampleFreshlyTranslucent || translucentTerrain)?WORLDVOX_OPAQUE:WORLDVOX_NOT_AIR;
    bool cornerBlocked = !(alignment.x||alignment.y);

    bool earlyReturn = bool(localFronts[1][1]&WORLDVOX_TRANSLUCENT)&&!(sampleFreshlyTranslucent || translucentTerrain);
    #ifndef READS_MUST_BE_UNIFORM
    if(earlyReturn) return;
    #endif

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

            if(!earlyReturn)
                newObstructions[i][j]=blockBlocked;

            bool sampleDoneProcessing = (alignment.x&&j==0) || (alignment.y&&i==0) || blockBlocked || earlyReturn;
            #ifndef READS_MUST_BE_UNIFORM
            if(sampleDoneProcessing) continue;
            #endif


            for(int layer = 0; layer<VOX_LAYERS; layer++){
                uvec4 relevantSample = getInputSample(a,b,layer);
                #ifdef READS_MUST_BE_UNIFORM
                if(sampleDoneProcessing) continue;
                #endif
                if(lightTravel.x*a>0 || lightTravel.y*b>0)
                    continue;

                vec3 newLightTravel = unpackLightTravel(relevantSample);
                if(unpackLightType(relevantSample)!=LIGHT_TYPE_SUN)
                    newLightTravel+= vec3(-a, -b, 1)*scale;

                setPackedLightTravel(relevantSample,newLightTravel);

                if (sameLight(relevantSample,bestSource)){
                    relevance[i][j] = true;
                    relevantOcclusionSamples[i][j][0] = getPackedOcclusion(relevantSample);
                    break;
                }
            }
            #ifdef READS_MUST_BE_UNIFORM
            if(sampleDoneProcessing) continue;
            #endif

            ivec2 effectivePos = ivec2(a,b)+zonePos.xy;
            newObstructions[i][j]=newObstructions[i][j]
                ||((!relevance[i][j])&&(effectivePos.x>=0 && effectivePos.x<AREA_SIZE && effectivePos.y>=0 && effectivePos.y<AREA_SIZE))
            ;
        }
    }

    newObstructions[0][0] = newObstructions[0][0] || cornerBlocked;
    relevance[0][0]=relevance[0][0]&&!cornerBlocked;
}



//TODO after this is all done, test removing all the packing/unpacking
//also replace the bool arrays with uints
uint getTerrainOcclusion(vec3 travel, bool[2][2] relevantObstructions, bvec2 alignment){
    float halfScale = 0.5*scale;
    vec2 ray = (abs(travel.xy)-halfScale)/abs(travel.z-halfScale);
    uint map = 15u^bvec4ToUint(bvec4(relevantObstructions[1][1],relevantObstructions[0][1],relevantObstructions[1][0],relevantObstructions[0][0]));
    float hitDist = travel.z-0.6*scale;

    if(alignment.x){
        map = map&((map<<2u) | (map>>2u));
        ray.y=0;
    }
    if(alignment.y){
        map = map&(((map&5u)<<1u) | ((map&10u)>>1u));
        ray.x=0;
    }

    if(ray.y>=0.999){
        map=map&3u;
        map|=map<<2u;
    }

    if(ray.x>=0.999){
        map=map&5u;
        map|=map<<1u;
    }

    if(!bool((map^(map>>1u))&5u))
        ray.x=0;
    if(!bool((map^(map>>2u))&3u))
        ray.y=0;

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
    uint mapA = unpackOcclusionMap(occlusionA);
    uint mapB = unpackOcclusionMap(occlusionB);
    if(mapA == 0xfu) return occlusionB;
    if(mapB == 0xfu) return occlusionA;
    uint outMap = mapA & mapB;
    float outHitDist = min(unpackOcclusionHitDist(occlusionA),unpackOcclusionHitDist(occlusionB));


    //left, top, right, bottom
    uint occlEdges = getOcclusionEdges(outMap);

    vec2 rayA = unpackOcclusionRay(occlusionA);
    vec2 rayB = unpackOcclusionRay(occlusionB);


    int covering = int(mapA==outMap)-int(mapB==outMap);
//    covering=0;
    if(bool(covering)){
        if(covering<0){
            vec2 tmp = rayB;
            rayB=rayA;
            rayA=tmp;
            uint tmpu = mapB;
            mapB=mapA;
            mapA=tmpu;
        }

        uint coveredAreas = 0xfu^mapB;
        if(rayB.x>rayA.x){
            coveredAreas|=(coveredAreas<<1u)&10u;
        }else if(rayB.x<rayA.x){
            coveredAreas|=(coveredAreas>>1u)&5u;
        }

        if(rayB.y>rayA.y){
            coveredAreas|=(coveredAreas<<2u)&12u;
        }else if(rayB.y<rayA.y){
            coveredAreas|=(coveredAreas>>2u)&3u;
        }


        if(!bool(coveredAreas&outMap))
            return covering>0?occlusionA:occlusionB;
    }
    vec2 minRay = min(rayA,rayB);
    vec2 maxRay = max(rayA,rayB);

    uint edgesH = occlEdges&10u;
    uint edgesV = occlEdges&5u;
    uint edgeCount = bitCount(occlEdges);
    if(edgeCount==0){
        edgesH = ((outMap&10u)==10u)?2u:8u;
        edgesV = ((outMap&12u)==12u)?1u:4u;
    }

    vec2 outRay= vec2(
        (edgesH==8u)?(minRay.x):(edgesH==2u?maxRay.x:0),
        (edgesV==4u)?(minRay.y):(edgesV==1u?maxRay.y:0)
    );


    return packOcclusionInfo(outRay, outMap, outHitDist);
}



//i'll be calling the +b direction "top" and the +a direction "left", both of these directions are away from src
//as though you're looking along the +z direction, with light traveling along L=+z and also somewhat +x+y
void doOcclusion(uint[2][2][OCCLUDERS_PER_LIGHT] relevantOcclusionSamples, bool[2][2] relevance, bvec2 alignment, bool[2][2] relevantObstructions,
    inout uvec4 lightSrc
){
    bool isSun = unpackLightType(lightSrc)==LIGHT_TYPE_SUN;
    if(!(relevance[0][0]||relevance[0][1]||relevance[1][0]||relevance[1][1])){
        setPackedOcclusion(lightSrc,FULL_OCCLUSION);
        return;
    }

    vec3 travel = unpackLightTravel(lightSrc);
//    if(isSun) travel.z=sunDist;
    vec2 sunOffset = isSun?abs(travel.xy*scale/travel.z):vec2(0);

    vec2 travel2d= abs(travel.xy);

    //outer xy, inner xy
    float halfScale = 0.5*scale;

    vec4 slopeBounds = vec4(
        travel2d.xy+halfScale,
        travel2d.xy-halfScale
    );
    slopeBounds*=abs(1/(travel.z+vec2(-halfScale,halfScale))).xxyy;
    vec4 litBounds = vec4(1,1,0,0);


    setPackedOcclusion(lightSrc,getTerrainOcclusion(travel,relevantObstructions,alignment));
    if(isSun){
        slopeBounds=vec4(1,1,0,0);
        uint occlusion = getPackedOcclusion(lightSrc);
        vec2 r = unpackOcclusionRay(occlusion);
        r=vec2(0);
        r-=sunOffset;
        setPackedOcclusion(lightSrc,packOcclusionInfo(r,unpackOcclusionMap(occlusion),unpackOcclusionHitDist(occlusion)));
    }


    vec2 travelSignScale = sign(travel.xy)*scale;

    for(int i=0; i<2; i++){
        for (int j=1-i; j<2; j++){
            if ((!(relevance[i][j])) || (i==0 && alignment.y) || (j==0 && alignment.x))
                continue;

            uint occl = relevantOcclusionSamples[i][j][0];
            uint map = unpackOcclusionMap(occl);
            vec2 ray = unpackOcclusionRay(occl)+sunOffset;
            if(isSun){
//                ray+=10*sign(travel.xy)*scale*(1-vec2(i,j));
            }
            uint lightEdges = getLightEdges(map); //left, top, right, bottom
            lightEdges = lightEdges & ~((lightEdges<<2u)|(lightEdges>>2u));

            if(bool(i) && bool(lightEdges&8u))
                litBounds.x=min(litBounds.x,ray.x);
            if(bool(j) && bool(lightEdges&4u))
                litBounds.y=min(litBounds.y,ray.y);

            if((!bool(i)) && bool(lightEdges&2u))
                litBounds.z=max(litBounds.z,ray.x);
            if((!bool(j)) && bool(lightEdges&1u))
                litBounds.w=max(litBounds.w,ray.y);
        }
    }

    for(int i=0; i<2; i++){
        for(int j=0; j<2; j++){
            if((!relevance[i][j]) || (i==0 && alignment.y) || (j==0 && alignment.x))
                continue;

            uint occl = relevantOcclusionSamples[i][j][0];
            uint map = unpackOcclusionMap(occl);
            vec2 ray = unpackOcclusionRay(occl);
            if(isSun){
                ray+=sunOffset;
                ray-=scale*(1-vec2(i,j));
                if(ray.y<0){
                    map=(map&12u);
                    map+=map>>2u;
                }
                if(ray.x<0){
                    map=(map&10u);
                    map+=map>>1u;
                }
//                    map=15u;
            }

            //corners to edges
            if(ray.y>slopeBounds.y)
                map=map&((map<<2u)|3u);

            if(ray.x>slopeBounds.x)
                map=map&((map<<1u)|5u);

            //edges or Ls truncated to corners
            //TODO condense this
            if(i==0){
                if(ray.x<slopeBounds.z && ray.x>0){
                    //TODO lossy
                    map=10u|(map>>1u);
                    ray.x=litBounds.x;
                }else if((((map>>1u)&5u)==(map&5u))&&!alignment.y){
                    map|=10u;
                    ray.x=litBounds.x;
                }
            }else{
                if(ray.x>slopeBounds.x){
                    map|=10u;
                    ray.x=litBounds.x;
                }else if((((map>>1u)&5u)==(map&5u))&&!alignment.y){
                    map|=5u;
                    ray.x=litBounds.x;
                }
            }
            if(j==0){
                if(ray.y<slopeBounds.w && ray.y>0){
                    //TODO lossy
                    map=12u|(map>>2u);
                    ray.y=litBounds.y;
                }else if(((map>>2u)==(map&3u))&&!alignment.x){
                    map|=12u;
                    ray.y=litBounds.y;
                }
            }else{
                if(ray.y>slopeBounds.y){
                    map|=12u;
                    ray.y=litBounds.y;
                }else if(((map>>2u)==(map&3u))&&!alignment.x){
                    map|=3u;
                    ray.y=litBounds.y;
                }
            }


            if(!bool((map^(map>>1u))&5u))
                ray.x=0;
            if(!bool((map^(map>>2u))&3u))
                ray.y=0;

            uint lightEdges = getLightEdges(map); //left, top, right, bottom
            uint darkEdges = getOcclusionEdges(map);

            lightEdges = lightEdges & ~((lightEdges<<2u)|(lightEdges>>2u));
            uint darkEdges2 = darkEdges & ~((darkEdges<<2u)|(darkEdges>>2u));

            uint inBoundsLight = (uint(ray.x<=slopeBounds.x)<<3u) | (uint(ray.y<=slopeBounds.y)<<2u)|
                                 (uint(ray.x>=slopeBounds.z)<<1u) | (uint(ray.y>=slopeBounds.w));

            inBoundsLight |= (bool(5u&(map^(map>>1u)))?10u:0u)|(bool(3u&(map^(map>>2u)))?5u:0u);

            bool anythingInBounds = bool(inBoundsLight&darkEdges)||((inBoundsLight==15u)&&(darkEdges==0u)&&(map!=15u));

            if(!anythingInBounds) continue;

            //TODO more efficient repacking
            occl=packOcclusionInfo(ray,map,unpackOcclusionHitDist(occl)+(isSun?scale:0));
            uint oldOcclusion = getPackedOcclusion(lightSrc);
            setPackedOcclusion(lightSrc,combineOcclusions(oldOcclusion,occl));
        }
    }
}





void doLightPassage(inout uvec4 bestLight, bool translucentTerrain){
    uint[2][2][OCCLUDERS_PER_LIGHT] relevantOcclusionSamples;
    bool[2][2] relevance;
    bvec2 alignment;
    bool[2][2] newObstructions;

    pickRelevantInputSamples(bestLight, translucentTerrain, relevantOcclusionSamples, relevance, alignment, newObstructions);

    doOcclusion(relevantOcclusionSamples, relevance, alignment, newObstructions, bestLight);

#if !(defined KEEP_FULLY_OCCLUDED_SAMPLES && defined DEBUG_OCCLUSION_MAP)
    if ( !bool(unpackOcclusionMap(getPackedOcclusion(bestLight)))){
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
    color/=translucentBlocksInSample;


    #ifdef READS_MUST_BE_UNIFORM
    doLightPassage(translucentPassage,true);
    #endif

    if(translucentBlocksInSample>0){
        #ifndef READS_MUST_BE_UNIFORM
        doLightPassage(translucentPassage,true);
        #endif
        if(bool(unpackOcclusionMap(getPackedOcclusion(translucentPassage)))){
            setPackedLightColor(translucentPassage,unpackLightColor(translucentPassage)*color);
            setPackedLightFlags(translucentPassage,unpackLightFlags(translucentPassage)|1u); //TODO make this not dumb

            bestLights[VOX_LAYERS-1]=translucentPassage;
        }else{
            translucentBlocksInSample=0;
        }
    }
#endif

    for(int layer = 0; layer<VOX_LAYERS; layer++){
        bool isOverwrittenTranslucentLayer = false;
#ifdef COLORED_TRANSLUCENTS
        isOverwrittenTranslucentLayer= (translucentBlocksInSample>0 && layer==VOX_LAYERS-1);
#endif
        uvec4 light = bestLights[layer];
        #ifndef READS_MUST_BE_UNIFORM
        if(isOverwrittenTranslucentLayer) break;
        #endif
        doLightPassage(light,false);
        setPackedLightFlags(light,unpackLightFlags(bestLights[layer])&0xfeu);
        if(!isOverwrittenTranslucentLayer)
            bestLights[layer] = light;
    }

    //could maybe be at the top, not sure how much it'd actually help though TODO test later
    uint front = getFrontVoxel(0,0);
    if (bool(front&(0xfu<<VOXEL_TYPE_SHIFT))){
        vec3 lightTravel;
#ifdef LIGHT_SOURCES_BLOCK_CENTERIC
        if(scale<1){
            vec3 worldPos = vec3(areaPos.xyz)*scale-0.5*scale+globalOrigin;
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

#ifdef FALLBACK_RADIANCE
    setLightData(radiance, zonePos, zoneShift, zoneOffset(axis,RADIANCE_LAYER,cascadeLevel));
#endif

}

void main(){
    #if LIGHTER_PASS>=LIGHTING_SYSTEM_PASSES
    if(true)
        return;
    #endif

    #ifdef SSBO_WORKSPACE
    workGroupOffset = ((gl_WorkGroupID.x*LIGHTER_WORK_GROUP_Y+gl_WorkGroupID.y)*LIGHTER_WORK_GROUP_Z+gl_WorkGroupID.z)*(LIGHT_LAYERS+1);
    #endif

    zonePos.xy=ivec2(
        gl_LocalInvocationID.x+(gl_WorkGroupID.x%AREA_WIDTH_SECTIONS)*SECTION_SIZE,
        gl_LocalInvocationID.y+(gl_WorkGroupID.x/AREA_WIDTH_SECTIONS)*SECTION_SIZE
    );

    int frameBasedOffset = frameCounter;
    cascadeLevel = getVariableCascadeLevel(frameBasedOffset,bool(gl_WorkGroupID.y&1u));
    if(cascadeLevel>=NUM_CASCADES) return;
#ifdef DOUBLE_PROC
    frameBasedOffset=(frameBasedOffset>>cascadeLevel);
#else
    frameBasedOffset=(frameBasedOffset>>(cascadeLevel+1));
#endif

    scale = getScale(cascadeLevel);
    areaShift = getAreaShift(scale);
    upAreaShift = getAreaShift(scale*2);

#if DEBUG_AXIS>=0
    axis = DEBUG_AXIS;
#else
    axis = gl_WorkGroupID.y/PROC_MULT;
#endif

    zoneShift = areaToZoneSpace(areaShift,axis);
    upZoneShift = areaToZoneSpace(upAreaShift,axis);

    frameBasedOffset = (frameBasedOffset*LIGHTING_SYSTEM_PASSES-zoneShift.z + LIGHTER_PASS)%UPDATE_STRIDE;


#ifdef WAVES_INORDER
    for(;frameBasedOffset<AREA_SIZE;frameBasedOffset+=UPDATE_STRIDE)
#endif
    {
        zonePos.z = int((gl_WorkGroupID.z)*UPDATE_STRIDE)+frameBasedOffset;
        if(zonePos.z>=AREA_SIZE)
            return;
        areaPos = zoneToAreaSpace(zonePos, axis);

        lightVoxelFace();
    }
}