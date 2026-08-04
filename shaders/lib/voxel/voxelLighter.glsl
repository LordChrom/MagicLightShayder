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

#define A (gl_LocalInvocationID.x+1)
#define B (gl_LocalInvocationID.y+1)

//same accross group
uint zonePosZ = 0;
float scale = 0;

#if DEBUG_AXIS>=0
    #define axis DEBUG_AXIS
#else
    #define axis (gl_WorkGroupID.y/PROC_MULT)
#endif

#ifdef SSBO_WORKSPACE
    uint workGroupOffset;

    layout(std430, binding = 0) buffer ssbo0 {
        uvec4[][LIGHT_LAYERS][SECTION_SIZE+2][SECTION_SIZE+2] bufferedWorkData;
    };

    void setSharedSample(int a, int b, uint layer, uvec4 data){
        bufferedWorkData[workGroupOffset][layer][A+a][B+b]= data;
    }
    uvec4 getInputSample(int a, int b, uint layer){
        return bufferedWorkData[workGroupOffset][layer][A+a][B+b];
    }
#else
    shared uvec4[SECTION_SIZE+2][SECTION_SIZE+2][LIGHT_LAYERS] sharedPackedPool;
    uvec4 getInputSample(int a, int b, uint layer){return sharedPackedPool[A+a][B+b][layer];}
    void setSharedSample(int a, int b, uint layer, uvec4 data){
        sharedPackedPool[A+a][B+b][layer]=data;
    }


#endif

uvec4[VOX_LAYERS] bestLights;
void setBestLight(uint layer, uvec4 data){
    bestLights[layer]=data;
}

uvec4 getBestLight(uint layer){
    return bestLights[layer];
}

shared uint[SECTION_SIZE+2][SECTION_SIZE+2] sharedPackedFrontVoxels;
shared uint[SECTION_SIZE+2][SECTION_SIZE+2] sharedPackedRearVoxels;

void setSharedVoxels(int a, int b,uint front, uint rear){
    sharedPackedFrontVoxels[A+a][B+b]=front;
    sharedPackedRearVoxels[A+a][B+b]=rear;
}

uint getFrontVoxel(int a, int b){return sharedPackedFrontVoxels[A+a][B+b];}
uint getRearVoxel(int a, int b){return sharedPackedRearVoxels[A+a][B+b];}



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

#ifndef DISABLE_BLOCKLIGHT_SUN
uniform bool hasCeiling;
#endif

void saveSharedSample(int a, int b){
    ivec3 sampleZonePos = ivec3(
        gl_LocalInvocationID.x+a+(gl_WorkGroupID.x%AREA_WIDTH_SECTIONS)*SECTION_SIZE,
        gl_LocalInvocationID.y+b+(gl_WorkGroupID.x/AREA_WIDTH_SECTIONS)*SECTION_SIZE,
        zonePosZ-1
    );

    ivec3 rearVoxelPos = zoneToAreaSpace(sampleZonePos, axis);
    ivec3 frontVoxelPos = rearVoxelPos+lVec(axis);
    uint cascadeLevel = scaleToCascadeLevel(scale);

    ivec3 areaShift = getAreaShift(scale);

    bool sideOob = voxelIsSplit(frontVoxelPos,areaShift,cascadeLevel) ||
        (sampleZonePos.x<0) || (sampleZonePos.x>=AREA_SIZE) ||
        (sampleZonePos.y<0) || (sampleZonePos.y>=AREA_SIZE) ;
    bool rearOob = voxelIsSplit(rearVoxelPos,areaShift,cascadeLevel) || (sampleZonePos.z<0) || (sampleZonePos.z>=AREA_SIZE) ;

    uint sampleCascade = cascadeLevel;
    ivec3 zoneShift = areaToZoneSpace(areaShift,axis);
    uint areaMemOffset = areaOffset(cascadeLevel);
    vec3 zonePosRemnants;


    if(sideOob || rearOob){
        //TODO sort out the varios OOB cases here
        sampleZonePos = uppperCascadeZonePos(ivec3(sampleZonePos+ivec3(-a,-b,1)),zoneShift,axis,scale,zonePosRemnants);
        zonePosRemnants.z-=scale;
        sampleCascade++;

        areaMemOffset = areaOffset(sampleCascade);

        if(sideOob)
            frontVoxelPos=upperCascadeAreaPos(frontVoxelPos,areaShift);
        rearVoxelPos=upperCascadeAreaPos(rearVoxelPos,areaShift);

        areaShift=getAreaShift(scale*2);
        zoneShift=areaToZoneSpace(areaShift,axis);

        if(cascadeLevel>=(NUM_CASCADES-1)){
            setSharedVoxels(a,b,0u,0u);
    #ifdef DISABLE_BLOCKLIGHT_SUN
            const uvec4 defaultLight = uvec4(0);
    #else
            uvec4 defaultLight = ((!hasCeiling) && zonePosZ<=0) ? getSunlight(axis) : uvec4(0);
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

    uint frontVoxel = getVoxData(frontVoxelPos,sideOob?areaShift:getAreaShift(scale),sideOob?areaMemOffset:areaOffset(cascadeLevel));

    uint rearVoxel = getVoxData(rearVoxelPos,areaShift,areaMemOffset);
    setSharedVoxels(a,b,frontVoxel,rearVoxel);
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        uvec4 light = sampleLightData(sampleZonePos, zoneShift, zoneOffset(axis,layer,sampleCascade));
        if(rearOob && (unpackLightType(light)!=LIGHT_TYPE_SUN)){
            setPackedLightTravel(light,unpackLightTravel(light)+zonePosRemnants);
        }

        setSharedSample(a,b,layer,maybeBlockLight(light,rearVoxel));
    }


#ifdef FALLBACK_RADIANCE
    uvec4 r = uvec4(0);
    //TOOD recoloring radiance
    if(!bool(rearVoxel&WORLDVOX_OPAQUE)){
       r = sampleLightData(sampleZonePos, zoneShift, zoneOffset(axis,RADIANCE_LAYER,sampleCascade));
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
    barrier();

    saveSharedSample(0,0);
    ivec2 bonusPos = getBonusPosOffset();
    barrier();
    if (bonusPos!=ivec2(0)){
        saveSharedSample(bonusPos.x,bonusPos.y);
    }

    barrier(); //disable for fun party :)
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

void determineBestLightSources(){
    uint[VOX_LAYERS] bestStrengths;
    for(int layer = 0; layer<VOX_LAYERS; layer++){
        setBestLight(layer,uvec4(0));
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

            const vec3 weights = vec3(0.4,0.2,0.15);
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

                    if(sameLight(lightSrc,getBestLight(rank)))
                        break;

                    if (strength>bestStrengths[rank]){
                        uint tmpStr = bestStrengths[rank];
                        uvec4 tmpSrc = getBestLight(rank);

                        setBestLight(rank,lightSrc);
                        bestStrengths[rank]=strength;

                        lightSrc=tmpSrc;
                        strength=tmpStr;
                    }
                }
            }
        }
    }
}



//out of 9 input samples, only up to 4 can have any light flowing between the source and the output
//for all 2x2 selected sample arrays, corner closest to source at [0][0], output sample at [1][1]
//newObstructions is flipped to match this, with [2][2] being the firthest corner from source
//alignment.x means it is on the a axis,
void pickRelevantInputSamples(uvec4 bestSource, bool translucentTerrain,
    out uint[2][2][OCCLUDERS_PER_LIGHT] relevantOcclusionSamples, out uint relevance, out bvec2 alignment, out uint newObstructions
){

    vec3 lightTravel = unpackLightTravel(bestSource);
    int aSignSrc = int(sign(lightTravel.x));
    int bSignSrc = int(sign(lightTravel.y));
    alignment = bvec2(bSignSrc==0,aSignSrc==0);

    relevance=0;
    newObstructions=0;

    for(int i=0; i<2; i++){
        for (int j=0; j<2; j++){
            relevantOcclusionSamples[i][j][0]=0u;
        }
    }

    bool sampleFreshlyTranslucent = bool(unpackLightFlags(bestSource)&1u) || translucentTerrain;
//    bool sampleLeavingGlass = sampleFreshlyTranslucent && bool(localRears[1][1]&WORLDVOX_TRANSLUCENT) && !bool(localFronts[1][1]&WORLDVOX_TRANSLUCENT) ;
    uint obstructingTerrainMask = sampleFreshlyTranslucent?WORLDVOX_OPAQUE:WORLDVOX_NOT_AIR;
    bool cornerBlocked = !(alignment.x||alignment.y);

    uint front = getFrontVoxel(0,0);
    if(bool(front&WORLDVOX_TRANSLUCENT)&&!sampleFreshlyTranslucent)
        return;

#ifdef UNOCCLUDED_INTO_BLOCKS
    bool frontBlockedCompletely = bool(front&WORLDVOX_OPAQUE);
#endif

    //i=0 means a=offset, i=1 means a=0;
    for(int i=0; i<2; i++){
        int a = (i-1)*aSignSrc;
        for(int j=0; j<2; j++){
            int b = (j-1)*bSignSrc;

            uint front = getFrontVoxel(a,b);
            uint rear = getRearVoxel(a,b);

#ifdef UNOCCLUDED_INTO_BLOCKS
            if(frontBlockedCompletely){
                front&=~WORLDVOX_OPAQUE;
                rear&=~WORLDVOX_OPAQUE;
            }
#endif

            bool blockBlocked = bool((front|rear)&obstructingTerrainMask)
            ||
                ((!bool(front&WORLDVOX_TRANSLUCENT)&&translucentTerrain) && ( //only cutoff the outside when its at the front
                    (i==1 && aSignSrc!=0)||
                    (j==1 && bSignSrc!=0)
                ))
            ||
                ((!bool(rear&WORLDVOX_TRANSLUCENT)&&translucentTerrain) && (
                    (i==0&&bool(getRearVoxel(a,0)&WORLDVOX_TRANSLUCENT))||
                    (j==0&&bool(getRearVoxel(0,b)&WORLDVOX_TRANSLUCENT)))
                )
            ;

            //TODO figure out if this is necessary after handling the opposing corners case
            cornerBlocked = cornerBlocked && (i==j || bool(front&WORLDVOX_OPAQUE));

            newObstructions|= uint(blockBlocked)<<(j+j+i);

            if((alignment.x&&j==0) || (alignment.y&&i==0) || blockBlocked)
                continue;


            for(int layer = 0; layer<VOX_LAYERS; layer++){
                uvec4 relevantSample = getInputSample(a,b,layer);
                if(aSignSrc*a>0 || bSignSrc*b>0)
                    continue;

                vec3 newLightTravel = unpackLightTravel(relevantSample);
                if(unpackLightType(relevantSample)!=LIGHT_TYPE_SUN)
                    newLightTravel+= vec3(-a, -b, 1)*scale;

                setPackedLightTravel(relevantSample,newLightTravel);

                if (sameLight(relevantSample,bestSource)){
                    relevance|= 1u<<(j+j+i);
                    relevantOcclusionSamples[i][j][0] = getPackedOcclusion(relevantSample);
                    break;
                }
            }

            ivec2 effectivePos = ivec2(a,b)+ivec2(
                gl_LocalInvocationID.x+(gl_WorkGroupID.x%AREA_WIDTH_SECTIONS)*SECTION_SIZE,
                gl_LocalInvocationID.y+(gl_WorkGroupID.x/AREA_WIDTH_SECTIONS)*SECTION_SIZE
            );
            newObstructions|=uint(
                (!bool(relevance&(1u<<(j+j+i)))) &&
                    (effectivePos.x>=0 && effectivePos.x<AREA_SIZE && effectivePos.y>=0 && effectivePos.y<AREA_SIZE)
            )<<(j+j+i);
        }
    }

    newObstructions |= uint(cornerBlocked);
    relevance&=~uint(cornerBlocked);
}



//TODO after this is all done, test removing all the packing/unpacking
//also replace the bool arrays with uints
uint getTerrainOcclusion(vec3 travel, uint relevantObstructions, bvec2 alignment){
    float halfScale = 0.5*scale;
    vec2 ray = (abs(travel.xy)-halfScale)/abs(travel.z-halfScale);
    uint map = 15u^relevantObstructions;
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
void doOcclusion(uint[2][2][OCCLUDERS_PER_LIGHT] relevantOcclusionSamples, uint relevance, bvec2 alignment, uint relevantObstructions,
    inout uvec4 lightSrc
){
    bool isSun = unpackLightType(lightSrc)==LIGHT_TYPE_SUN;
    if(!bool(relevance)){
        setPackedOcclusion(lightSrc,FULL_OCCLUSION);
        return;
    }

    vec3 travel = unpackLightTravel(lightSrc);
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
            if ((!bool(relevance&(1u<<(j+j+i)))) || (i==0 && alignment.y) || (j==0 && alignment.x))
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
            if((!bool(relevance&(1u<<(j+j+i)))) || (i==0 && alignment.y) || (j==0 && alignment.x))
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
    uint relevance,newObstructions;
    bvec2 alignment;

    pickRelevantInputSamples(bestLight, translucentTerrain, relevantOcclusionSamples, relevance, alignment, newObstructions);

    doOcclusion(relevantOcclusionSamples, relevance, alignment, newObstructions, bestLight);

#if !(defined KEEP_FULLY_OCCLUDED_SAMPLES && defined DEBUG_OCCLUSION_MAP)
    if ( !bool(unpackOcclusionMap(getPackedOcclusion(bestLight)))){
        bestLight=uvec4(0);
    }
#endif
}

int doColoredTranslucent(){
    int translucentBlocksInSample = 0;

    uvec4 translucentPassage = getBestLight(0);

    ivec2 travelDirSign = ivec2(sign(unpackLightTravel(translucentPassage).xy));

    vec3 color = vec3(0);

    for (int i=0; i<2; i++){
        int a = (i-1)*travelDirSign.x;
        for (int j=0; j<2; j++){
            int b = (j-1)*travelDirSign.y;

            uint front = getFrontVoxel(a, b);
            uint rear = getRearVoxel(a, b);

            bool frontTrans = bool(front&WORLDVOX_TRANSLUCENT);
            bool rearTrans = bool(rear&WORLDVOX_TRANSLUCENT);
            rearTrans=false;
            translucentBlocksInSample += int(frontTrans) + int(rearTrans);
            if (frontTrans)
                color+=worldVoxColor(front);
            if (rearTrans)
                color+=worldVoxColor(rear);
        }
    }
    color/=translucentBlocksInSample;


    if (translucentBlocksInSample>0){
        doLightPassage(translucentPassage, true);
        if (bool(unpackOcclusionMap(getPackedOcclusion(translucentPassage)))){
            setPackedLightColor(translucentPassage, unpackLightColor(translucentPassage)*color);
            setPackedLightFlags(translucentPassage, unpackLightFlags(translucentPassage)|1u);//TODO make this not dumb

            setBestLight(VOX_LAYERS-1, translucentPassage);
        } else {
            translucentBlocksInSample=0;
        }
    }
    return translucentBlocksInSample;
}

//for one voxel face, determines the light entering that voxel face
//based on the 9 adjacent voxel faces in the previous plane & the nearby terrain voxels
void lightVoxelFace(){
    takeSamples();
    determineBestLightSources();

#ifdef COLORED_TRANSLUCENTS
    int translucentBlocksInSample = doColoredTranslucent();
#endif

    for(int layer = 0; layer<VOX_LAYERS; layer++){
        #ifdef COLORED_TRANSLUCENTS
        if( (layer==VOX_LAYERS-1) && translucentBlocksInSample>0)
            break;
        #endif

        uvec4 light = getBestLight(layer);
        uint flagsToSet = unpackLightFlags(light)&0xfeu;
        doLightPassage(light,false);
        setPackedLightFlags(light,flagsToSet);
        setBestLight(layer,light);
    }

    //could maybe be at the top, not sure how much it'd actually help though TODO test later
    ivec3 zonePos = ivec3(
        gl_LocalInvocationID.x+(gl_WorkGroupID.x%AREA_WIDTH_SECTIONS)*SECTION_SIZE,
        gl_LocalInvocationID.y+(gl_WorkGroupID.x/AREA_WIDTH_SECTIONS)*SECTION_SIZE,
        zonePosZ
    );
    uint front = getFrontVoxel(0,0);
    if (bool(front&(0xfu<<VOXEL_TYPE_SHIFT))){
        vec3 lightTravel = vec3(0);
#ifdef LIGHT_SOURCES_BLOCK_CENTERIC
        if(scale<1){
            vec3 worldPos = vec3(zoneToAreaSpace(zonePos, axis))*scale-0.5*scale+globalOrigin;
            vec3 subBlockOffset = areaToZoneSpaceRelative((worldPos-round(worldPos)),axis);
            lightTravel = subBlockOffset;
        }
        if(lightTravel.z>=-0.001)
#endif
        {
            setBestLight(VOX_LAYERS-1,packLightData(vec2(0),15u,worldVoxColor(front),lightTravel,0,(front>>VOXEL_TYPE_SHIFT)&0xfu,0));
        }
    }

    ivec3 zoneShift =  areaToZoneSpace(getAreaShift(scale),axis);
    uint cascadeLevel = scaleToCascadeLevel(scale);

    for(int layer = 0; layer<VOX_LAYERS; layer++){
        setLightData(getBestLight(layer), zonePos, zoneShift, zoneOffset(axis,layer,cascadeLevel));
    }

#ifdef FALLBACK_RADIANCE
    setLightData(radiance, zonePos, zoneShift, zoneOffset(axis,RADIANCE_LAYER,cascadeLevel));
#endif

}

void main(){
    #if LIGHTER_PASS>=LIGHTING_SYSTEM_PASSES
    if(true) return;
    #endif

    #ifdef SSBO_WORKSPACE
    workGroupOffset = ((gl_WorkGroupID.x*LIGHTER_WORK_GROUP_Y+gl_WorkGroupID.y)*LIGHTER_WORK_GROUP_Z+gl_WorkGroupID.z);
    #endif


    uint cascadeLevel = getVariableCascadeLevel(frameCounter,bool(gl_WorkGroupID.y&1u));
    if(cascadeLevel>=NUM_CASCADES) return;
#ifdef DOUBLE_PROC
    int frameBasedOffset=(frameCounter>>cascadeLevel);
#else
    int frameBasedOffset=(frameCounter>>(cascadeLevel+1));
#endif

    scale = getScale(cascadeLevel);

    frameBasedOffset = (frameBasedOffset*LIGHTING_SYSTEM_PASSES-areaToZoneSpace(getAreaShift(scale),axis).z + LIGHTER_PASS)%UPDATE_STRIDE;


#ifdef WAVES_INORDER
    for(;frameBasedOffset<AREA_SIZE;frameBasedOffset+=UPDATE_STRIDE)
#endif
    {
        zonePosZ = int((gl_WorkGroupID.z)*UPDATE_STRIDE)+frameBasedOffset;
        if(zonePosZ>=AREA_SIZE)
            return;

        lightVoxelFace();
    }
}