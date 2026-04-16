#define SAMPLES_LIGHT_FACE

#include "/lib/voxel/voxelHelper.glsl"
#include "/lib/util/flicker.glsl"
#include "/lib/util/misc.glsl"


vec3 getDirectedLight(uvec4 packedLightSrc, ivec3 blockPos, vec3 subVoxelOffset, vec3 normal, uint axis, float scale, float subsurface, bool isForFog){
    vec3 travel = unpackLightTravel(packedLightSrc);
    blockPos-=zoneToAreaSpaceRelative(ivec3(round(travel)),axis);

    subVoxelOffset = bool(axis&6u)?subVoxelOffset:subVoxelOffset.yzx;
    normal = bool(axis&6u)?normal:normal.yzx;

    subVoxelOffset = (axis&6u)==2u?subVoxelOffset.zxy:subVoxelOffset;
    normal = (axis&6u)==2u?normal.zxy:normal;

    subVoxelOffset.z=bool(axis&1u)?subVoxelOffset.z:-subVoxelOffset.z;
    normal.z=bool(axis&1u)?normal.z:-normal.z;


    vec3 displacement = travel + subVoxelOffset;
    float lengthSquared = dot(displacement,displacement);
    float columnation = MIN_COLUMNATION;
    lengthSquared = lengthSquared*(1-columnation)+columnation;

    float lightStrength=BLOCK_LIGHT_STRENGTH;

    uint type = unpackLightType(packedLightSrc);
#ifdef EVERYTHING_IS_THE_SUN
    if(type>0)
        type=1;
#endif
    switch(type){
        case 1: //sunlight
            const float sunStr = 1/float(MAX_LIGHT_STRENGTH);
            lightStrength = sunStr;
            columnation=1;
            break;
        case 2: //steady blocklight
            lightStrength = BLOCK_LIGHT_STRENGTH;
            break;
        case 3: //pulsating light
            lightStrength = BLOCK_LIGHT_STRENGTH * pulsate();
            break;
        case 4: //fire flickering light
            lightStrength = BLOCK_LIGHT_STRENGTH * flicker(blockPos);
            break;
    }

    if(isForFog)
        lightStrength*=(type==LIGHT_TYPE_SUN)?FOG_BRIGHTNESS_SUN:FOG_BRIGHTNESS_BLOCK;


    const float b = 1/float(MAX_LIGHT_STRENGTH*MAX_LIGHT_STRENGTH);

    lightStrength*=inversesqrt(lengthSquared*lengthSquared*(1-columnation)+b);


    if( displacement.z>0)
        lightStrength==0;

    float lightDotN = isForFog?1.0:-dot(normalize(displacement),normal);

//    if(lightDotN<=0)
//        lightDotN=subsurface*1+0*max(1.0,0.5*(1+sqrt(-lightDotN)));
    subsurface*=0.4;
    lightDotN=clamp(max(lightDotN*(1-subsurface),0)+subsurface,0,1);


#if EVERYTHING_FACING_SRC==1
    if(lightDotN>0)
        lightDotN=1;
#elif EVERYTHING_FACING_SRC==2
    lightDotN=1;
#endif


    vec3 color = unpackLightColor(packedLightSrc);
#ifdef PRIDE_LIGHTING
    float len = sqrt(lengthSquared);
    vec3 normalColor = normalize(color);
    if(length(normalColor-normalize(vec3(8,7,4)))<0.1){

        if(2<=len && len<=2.5){
            color=vec3(1);
        }else if(1.5<=len && len<=3){
            color=vec3(1,0.5,0.8);
        }else{
            color=vec3(0.3,0.3,1);
            if(len>3)
                lightStrength*=2;
        }
    }else if(length(normalColor-normalize(vec3(8,5,2)))<0.15){
        switch(int(floor(len*2-1))){
            case 0:
                color=vec3(1,0,0);
                break;
            case 1:
                color=vec3(1,0.5,0);
                break;
            case 2:
                color=vec3(1,1,0);
                break;
            case 3:
                color=vec3(0,1,0);
                break;
            case 4:
                color=vec3(0,0,1);
                break;
            default:
                color=vec3(1.3,0,1.3);

        }
    }
#endif

#ifdef DEBUG_DECOLOR
    #ifdef DEBUG_OCCLUSION_MAP
    color=vec3(0.3);
    #endif
#endif


float highSlope = round(1024*max(abs(displacement.x),abs(displacement.y))/max(1e-9,displacement.z))/1024;

vec2 ray = unpackOcclusionRay(packedLightSrc.w);
uint map = unpackOcclusionMap(packedLightSrc.w);
#ifdef PENUMBRAS_ENABLED
    #ifdef FOG_PENUMBRAS
    bool doPenumbra = true;
    #else
    bool doPenumbra = !isForFog;
    #endif

    if(doPenumbra)
    {
        float sharpener = (max(abs(travel.x),abs(travel.y))!=travel.z)? 1e9:1.0;
        float occHitDist = unpackOcclusionHitDist(packedLightSrc.w);

        lightStrength*=clamp(0.5+(1-highSlope)*(sharpener/PENUMBRA_WIDTH),0,1);
        lightStrength*=penumbralLightTest(displacement,ray,map,occHitDist);
    }
    else
#endif
    {
        lightStrength*=0.5*(int(highSlope<=1)+int(highSlope<1));
        lightStrength=isLit(displacement,ray,map) ? lightStrength:0;
    }


    color *= (lightStrength*(max(lightDotN,0)));

#ifdef DEBUG_OCCLUSION_MAP
    //Debug Coloring
    //green = fully lit,
    //bright red = fully unlit (should never happen)
    //blue = partially lit
    if(bool(type)){
        vec2 debugQuadrant = subVoxelOffset.xy;

    #ifdef UNFLIP_DEBUG_MAPS
        if(travel.x<0)
            debugQuadrant.x*=-1;
        if(travel.y<0)
            debugQuadrant.y*=-1;
    #endif

        int mapSum = bitCount(map);
        if(mapSum==0)
            color.r=1;
        if(mapSum==4)
            color.g+=0.05;

        bool mapSpot = bool(map & (debugQuadrant.x>0?10u:5u) & (debugQuadrant.y>0?12u:3u));

        if(mapSum<4){
            if(!mapSpot){
                color.b+=0.2;
            }
            uint edges = getOcclusionEdges(map);
            if(
                bool(edges & ((debugQuadrant.x>0?8u:2u) | (debugQuadrant.y>0?4u:1u)))
            ){
                color.r+=0.2;
            }
        }
    }
#endif
#ifdef DEBUG_OCCLUSION_RAYS
    if(bool(type)){
        vec2 slopeDif = abs(ray-abs(displacement.xy/displacement.z));

        float outlineWidth = DEBUG_OUTLINE_WIDTH/displacement.z;

    #ifdef DEBUG_LIGHT_TRAVEL
        vec2 slopeDifSigns = sign(ray*sign(displacement.xy)-(displacement.xy/displacement.z));
        float len = length(displacement);
        if(slopeDifSigns.x*slopeDifSigns.y>0)
            outlineWidth*=1+ (1+sin(2*len)) + 0.3*(1+sin(30*len));
        else{
            outlineWidth*=1+displacement.z;
        }
    #endif

        if(slopeDif.x<outlineWidth || slopeDif.y<outlineWidth){
            color.rgb=vec3(0.6);
            float occHitDist = unpackOcclusionHitDist(packedLightSrc.w);
            if(occHitDist!=0){
                float wavey = occHitDist*0.5+1;
                color*=normalize(0.6+0.4*vec3(sin(wavey), sin(wavey+PI*2.0/3), sin(wavey+PI*4.0/3)));
            }

            outlineWidth*=0.5;
            if(slopeDif.x<outlineWidth || slopeDif.y<outlineWidth){
                color.rgb=vec3(0);
            }

        }
    }
#endif

#ifdef DEBUG_OCCLUSION_HIT_DIST
    float occHitDist = unpackOcclusionHitDist(packedLightSrc.w);
    if(occHitDist!=0){
        float wavey = occHitDist*0.5+1;
        color*=normalize(0.6+0.4*vec3(sin(wavey), sin(wavey+PI*2.0/3), sin(wavey+PI*4.0/3)));
    }
#endif

#if DEBUG_SHOW_UPDATES >= 0
    #if DEBUG_SHOW_UPDATES==0
    if(abs(normal.z)<0.9)
    #endif
    {
        uint frameIndicator = (frameCounter&0x3fu);
        uint frameIndicatorLight = (unpackLightFlags(packedLightSrc)>>2)&0x3fu;
        vec3 axisColor = ivec3(areaToZoneSpaceMats[axis][2]);
        if ((axis&1u)==0)
            axisColor=abs(axisColor)*0.3+0.1;
        if (frameIndicator==frameIndicatorLight)
            color.rgb+=DEBUG_UPDATES_INTENSITY*(axisColor);
    }
#endif

    return color;
}


vec3 getDirectedLight(uint cascadeLevel, uint layer, uint axis, float scale, float subsurface, ivec3 areaShift, ivec3 areaPos, ivec3 blockPos, vec3 normal, vec3 subVoxelOffset, bool isForFog){
    ivec3 zoneShift = areaToZoneSpace(areaShift, axis);
    ivec3 zonePos = areaToZoneSpace(areaPos, axis);
    uint zoneMemOffset = zoneOffset(axis, layer,cascadeLevel);
    uvec4 packedSrc = sampleLightData(zonePos, zoneShift, zoneMemOffset);
    return getDirectedLight(packedSrc, blockPos, subVoxelOffset, normal, axis, scale,subsurface, isForFog);
}

vec3 voxelSample(vec3 worldPos, vec3 normal, float subsurface){
#if PIXEL_LOCK >0
    worldPos = pixelLock(worldPos+0.01*normal,1.0/PIXEL_LOCK);
#endif
    uint cascadeLevel = getCascadeLevel(worldPos+normal*0.1);
    float scale = getScale(cascadeLevel);
    vec3 voxelCenter = (floor(worldPos/scale+normalize(normal)*(scale/20))+0.5) * scale;

    ivec3 areaPos = worldPosToArea(voxelCenter,scale).xyz;
    vec3 subVoxelOffset = worldPos-voxelCenter;
    ivec3 blockPos = ivec3(floor(voxelCenter));
    ivec3 areaShift = getAreaShift(scale);


    vec3 color = vec3(0);

#if DEBUG_GRID_OUTLINE >0
    vec3 edgeNearness = abs(subVoxelOffset*2/scale)+(DEBUG_GRID_OUTLINE/(64*scale));
    if((int(edgeNearness.x>=1)+int(edgeNearness.y>=1)+int(edgeNearness.z>=1))>=2){
        color = vec3(0.4);
    }
#endif

    if(!isVoxelInBounds(worldPos))
        return color*0.15;

#if DEBUG_AXIS>=0
    uint axis = DEBUG_AXIS;
#else
    for (uint axis=0;axis<6;axis++)
#endif
    for(uint layer = 0; layer<VOX_LAYERS; layer++)
    {
        color+=getDirectedLight(cascadeLevel,layer,axis,scale,subsurface,areaShift,areaPos,blockPos,normal,subVoxelOffset,false);
    }

    return color + MIN_LIGHT_AMOUNT*clamp(1-(color.x+color.y+color.z),0,1);
}


vec3 voxelSampleFog(vec3 worldPos, float fogNoise){
    //TODO add a computationally cheap option and an option that weights based on how much of the fog line thru the voxel is lit
    uint cascadeLevel = getCascadeLevel(worldPos);
    float scale = getScale(cascadeLevel);
    vec3 voxelCenter = (floor(worldPos/scale)+0.5) * scale;

    ivec3 areaPos = worldPosToArea(voxelCenter,scale).xyz;
    vec3 subVoxelOffset = worldPos-voxelCenter;
    ivec3 blockPos = ivec3(floor(voxelCenter));
    ivec3 areaShift = getAreaShift(scale);


    vec3 color = vec3(0);

#ifdef FOG_RANDOM_LESSER_SOURCE
    const int lightsInLoop = min(LIGHTS_PER_FOG_SAMPLE-1,VOX_LAYERS);
    uint randLayer = int(floor(float(VOX_LAYERS-lightsInLoop)*fract(fogNoise)))+lightsInLoop;
#else
    const int lightsInLoop = min(LIGHTS_PER_FOG_SAMPLE,VOX_LAYERS);
#endif

#if DEBUG_AXIS>=0
    uint axis = DEBUG_AXIS;
#else
    for (uint axis=0;axis<6;axis++)
#endif
    {
        for(int layer = 0; layer<lightsInLoop; layer++){
            color+=getDirectedLight(cascadeLevel,layer,axis,scale,1.0,areaShift,areaPos,blockPos,vec3(0),subVoxelOffset,true);
        }
#ifdef FOG_RANDOM_LESSER_SOURCE
            color+=getDirectedLight(cascadeLevel,randLayer,axis,scale,1.0,areaShift,areaPos,blockPos,vec3(0),subVoxelOffset,true);
#endif
    }
    return color;
}