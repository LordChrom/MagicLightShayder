#define SAMPLES_LIGHT_FACE
#if SUBSURFACE_MODE==2
    #define SAMPLES_VOX
    float subsurfaceLightDepth = 0; //x is thickness
#endif
bool isCrossBlockModel = false;
uint axis;
vec3 voxelCenter;

#include "/lib/voxel/voxelHelper.glsl"
#include "/lib/util/flicker.glsl"
#include "/lib/util/misc.glsl"

float normalFactor(vec3 normal, vec3 displacement, float subsurface){
    float lightDotN =-dot(normalize(displacement),normal);
   #if SUBSURFACE_MODE == 0
    subsurface*=0.4;
    lightDotN=max(lightDotN*(1-subsurface),0)+subsurface;
   #endif
#if EVERYTHING_FACING_SRC==1
    if(lightDotN>0)
        return 1;
#elif EVERYTHING_FACING_SRC==2
    return 1;
#endif
    return clamp(lightDotN,0,1);
}



float baseLightStrength(uint type, vec3 displacement, vec3 travel){
    const float b = 1/float(MAX_LIGHT_STRENGTH*MAX_LIGHT_STRENGTH);

    #ifdef EVERYTHING_IS_THE_SUN
        if(true) return 1;
    #elif !defined DISABLE_BLOCKLIGHT_SUN
        if(type==LIGHT_TYPE_SUN) return 1;
    #endif

    float lengthSquared = dot(displacement,displacement);
    float lightStrength = BLOCK_LIGHT_STRENGTH*inversesqrt(lengthSquared*lengthSquared*(1-MIN_COLUMNATION)+b);

    #ifdef BLOCKLIGHT_ANIMATION
    if(type==3u) lightStrength *= pulsate();
    if(type==4u) lightStrength *= flicker(ivec3(floor(voxelCenter))-zoneToAreaSpaceRelative(ivec3(round(travel)),axis));
    #endif

    return lightStrength;
}

float doPenumbralOcclusion(vec3 displacement, vec3 travel, uint packedOcclusionData){
    float width =(PENUMBRA_WIDTH)*((displacement.z/unpackOcclusionHitDist(packedOcclusionData))-1);
    vec2 m = clamp((abs(displacement.xy/displacement.z)-unpackOcclusionRay(packedOcclusionData))/width+0.5,0,1);

    uint map = unpackOcclusionMap(packedOcclusionData);

    vec2 mixX = mix(
        vec2(1u&(map>>0u),1u&(map>>2u)),
        vec2(1u&(map>>1u),1u&(map>>3u)),
    m.x);
    float strength = mix(mixX.x,mixX.y,m.y);


    float highSlope = max(abs(displacement.x),abs(displacement.y))/max(1e-9,displacement.z);
    float sharpener = (max(abs(travel.x),abs(travel.y))!=travel.z)? 1e9:1.0;

    return strength * clamp(0.5+(1-highSlope)*(sharpener/PENUMBRA_WIDTH),0,1);
}
float doSharpOcclusion(vec3 displacement, vec3 travel, uint packedOcclusionData){
    float stren=(max(abs(displacement.x),abs(displacement.y))<=displacement.z)?1:0;
    return isLit(displacement,unpackOcclusionRay(packedOcclusionData),unpackOcclusionMap(packedOcclusionData)) ? stren:0;
}

float doSharpOcclusionPixelLocked(vec3 displacement, vec3 travel, uint packedOcclusionData){
    float highDisp = max(abs(displacement.x),abs(displacement.y));
    float stren=highDisp<=displacement.z?(highDisp<displacement.z?1:0.5):0;

    return isLit(displacement,unpackOcclusionRay(packedOcclusionData),unpackOcclusionMap(packedOcclusionData)) ? stren:0;
}

float doSunOcclusion(vec3 displacement, vec3 travel, uint packedOcclusionData){
    vec2 ray = unpackOcclusionRay(packedOcclusionData);

    return float(bool(unpackOcclusionMap(packedOcclusionData) &
            (displacement.x>ray.x?10u:5u) &
            (displacement.y>ray.y?12u:3u)
    ));
}

#if (defined PENUMBRAS_ENABLED) && (defined FOG_PENUMBRAS)
    #define doFogOcclusion doPenumbralOcclusion
#else
    #define doFogOcclusion doSharpOcclusion
#endif

#ifdef PENUMBRAS_ENABLED
    #define doTerrainOcclusion doPenumbralOcclusion
#elif PIXEL_LOCK==-1
    #define doTerrainOcclusion doSharpOcclusion
#else
    #define doTerrainOcclusion doSharpOcclusionPixelLocked
#endif


void doBonusEffects(inout vec3 color, uvec4 packedLightSrc, vec3 displacement, vec3 normal, float scale){
    uint type = unpackLightType(packedLightSrc);
    bool isSun = type==LIGHT_TYPE_SUN;
    vec3 travel = unpackLightTravel(packedLightSrc);
    uint map = unpackOcclusionMap(packedLightSrc.z);

#ifdef PRIDE_LIGHTING
    #define BONUS_EFFECTS_NEEDED
    float len = length(displacement);
    vec3 normalColor = normalize(color);
    float colorStr = length(color);
    if(length(normalColor-normalize(vec3(8,7,4)))<0.1){
        if(2<=len && len<=2.5){
            color=vec3(1);
        }else if(1.5<=len && len<=3){
            color=vec3(1,0.5,0.8);
        }else{
            color=vec3(0.3,0.3,1);
            if(len>3)
                colorStr*=2;
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
    color*=colorStr;
#endif

#ifdef DEBUG_DECOLOR
    #define BONUS_EFFECTS_NEEDED
    color=vec3(0.3);
#endif
#ifdef DEBUG_OCCLUSION_MAP
    #define BONUS_EFFECTS_NEEDED
    vec3 subVoxelOffset = displacement;
    if(isSun)
        subVoxelOffset-=0.5*scale;
    else
        subVoxelOffset-=travel;

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
    #define BONUS_EFFECTS_NEEDED
    vec2 ray = unpackOcclusionRay(getPackedOcclusion(packedLightSrc));

    if(bool(type)){
        vec2 slopeDif = abs(ray-abs(displacement.xy/displacement.z));
        float outlineWidth = DEBUG_OUTLINE_WIDTH/displacement.z;

        if(type==LIGHT_TYPE_SUN){
            slopeDif=abs(ray-displacement.xy)/travel.z;
            if(map==15u)
                outlineWidth*=0;
        }


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
            float occHitDist = unpackOcclusionHitDist(getPackedOcclusion(packedLightSrc));
            if(occHitDist>0){
                float wavey = occHitDist*0.5+1;
                color*=normalize(0.6+0.4*vec3(sin(wavey), sin(wavey+PI*2.0/3), sin(wavey+PI*4.0/3)));
                if(isnan(color.x)||isnan(color.y)||isnan(color.z)) color=vec3(0);
            }


            outlineWidth*=0.5;
            if(slopeDif.x<outlineWidth || slopeDif.y<outlineWidth){
                color.rgb=vec3(0.01);
            }

        }
    }
#endif
#ifdef DEBUG_OCCLUSION_HIT_DIST
    #define BONUS_EFFECTS_NEEDED
    float occHitDist = unpackOcclusionHitDist(getPackedOcclusion(packedLightSrc));
    if(occHitDist!=0){
        float wavey = occHitDist*0.5+1;
        color*=normalize(0.6+0.4*vec3(sin(wavey), sin(wavey+PI*2.0/3), sin(wavey+PI*4.0/3)));
}
#endif

#if DEBUG_SHOW_UPDATES >= 0
    #define BONUS_EFFECTS_NEEDED
    float intensity = DEBUG_UPDATES_INTENSITY;
    #if DEBUG_SHOW_UPDATES==0
    if(abs(normal.z)>0.9)
        intensity*=0.1;
    #endif
    uint frameIndicator = (frameCounter&0x3fu);
    uint frameIndicatorLight = (unpackLightFlags(packedLightSrc)>>2)&0x3fu;
    vec3 axisColor = lVec(axis);
    if ((axis&1u)==0)
        axisColor=abs(axisColor)*0.3+0.1;
    if (frameIndicator==frameIndicatorLight)
        color.rgb+=intensity*(axisColor);
#endif
}




vec3 getDirectedLight(uint cascadeLevel, uint layer, float subsurface, ivec3 zoneShift, ivec3 zonePos,
    vec3 normal, vec3 subVoxelOffset, bool isForFog, float scale
){
    uvec4 packedLightSrc = sampleLightData(zonePos, zoneShift, zoneOffset(axis, layer,cascadeLevel));
    uint type = unpackLightType(packedLightSrc);
    if(type==0)return vec3(0);

    vec3 travel = unpackLightTravel(packedLightSrc);

    vec3 displacement = travel + subVoxelOffset;

    #ifndef DISABLE_BLOCKLIGHT_SUN

    if(type==LIGHT_TYPE_SUN){
        subVoxelOffset.xy*=sign(travel.xy);
        subVoxelOffset+=0.5*scale;
        displacement.xy=subVoxelOffset.xy-abs(travel.xy)*(subVoxelOffset.z/travel.z);
        displacement.z=7;
    }
    #endif

    float lightStrength = baseLightStrength(type,displacement, travel);
    float baseStrength = lightStrength;
    if(isForFog){
        lightStrength *=
        #ifndef DISABLE_BLOCKLIGHT_SUN
        (type==LIGHT_TYPE_SUN)?FOG_BRIGHTNESS_SUN:
        #endif
        FOG_BRIGHTNESS_BLOCK;
    }else{
        lightStrength*=normalFactor(normal, displacement, subsurface);
    }

    #ifndef DISABLE_BLOCKLIGHT_SUN
    if(type==LIGHT_TYPE_SUN)
        lightStrength *= doSunOcclusion(displacement,travel,getPackedOcclusion(packedLightSrc));
    else
    #endif
    {
        if(isForFog)
            lightStrength*=doFogOcclusion(displacement,travel,getPackedOcclusion(packedLightSrc));
        else
            lightStrength*=doTerrainOcclusion(displacement,travel,getPackedOcclusion(packedLightSrc));
    }

   #if SUBSURFACE_MODE == 2
    if(subsurface>0 && !isForFog){
        float subsurfaceStrength = 0;

        vec3 svo2 = abs(subVoxelOffset);
        if(isCrossBlockModel){ //TODO distinguish between flat cross vs blocky models better
            subsurfaceStrength=subsurface;
        }else{
            float lightDirz = normalize(displacement).z;

            float lightDepth=subsurfaceLightDepth;

            //for block touching light source
            float lightManhattDistXY = abs(travel.x)+abs(travel.y);
            if(travel.z<=1.01*scale && dot(travel,normal)>0.5
                && lightManhattDistXY>0.99*scale && lightManhattDistXY<1.01*scale
            ){
                lightDepth=abs(dot(displacement.xy,travel.xy))-scale*0.5;
                lightDirz=1;
            }
            subsurfaceStrength = lightDirz*exp(-3*lightDepth/max(0.01,lightDirz*subsurface));
        }

        subsurfaceStrength=max(0,subsurfaceStrength*baseStrength);
        //TODO revisit this when I have a proper tonemap
        lightStrength=sqrt(lightStrength*lightStrength+subsurfaceStrength*subsurfaceStrength);
    }
   #endif


    vec3 color = unpackLightColor(packedLightSrc) * lightStrength;

    #ifdef BONUS_EFFECTS_NEEDED
    doBonusEffects(color,packedLightSrc,displacement, normal, scale);
    #endif

    return color;
}

const float radSlope = tan(22.5*PI/180);
vec3 sampleDirectedRadiance(uint cascadeLevel, float subsurface, ivec3 zoneShift, ivec3 zonePos, vec3 normal, vec3 subVoxelOffset){
    uint zoneMemOffset = zoneOffset(axis, VOX_LAYERS,cascadeLevel);
    uvec4 packedRadiance = sampleLightData(zonePos, zoneShift, zoneMemOffset);
    vec3 ret = vec3(0);

    subVoxelOffset/=getScale(cascadeLevel);
    vec3 testNorm = normalize(vec3(radSlope,radSlope,1));
    for(int i=0; i<4; i++){
        int a = 2*(i&1)-1;
        int b = (i&2)-1;
        vec3 dir = normalize(vec3(a,b,2))+subVoxelOffset*0.1;
        float normalFactor =-dot(dir,normal);
        vec3 col = unpackUnorm4x8(packedRadiance[i]).rgb;


        normalFactor=max(0,normalFactor);
        col*=normalFactor;
        ret+=col;
    }
    return ret;
}


vec3 voxelSample(vec3 worldPos, vec3 normal, float subsurface, float ditherValue){
#if PIXEL_LOCK >0
    worldPos = pixelLock(worldPos+0.01*normal,1.0/PIXEL_LOCK);
#endif
    uint cascadeLevel = getCascadeLevel(worldPos+normal*0.1);
    float scale = getScale(cascadeLevel);

#if !(AREA_TRANSITION_DIST==-1)
    vec3 tmp = abs(worldPos-cameraPosition);
    float areaBorderNearness = max(max(tmp.x,tmp.y),tmp.z)/((AREA_SIZE-1)*0.5*scale);
    areaBorderNearness = clamp((areaBorderNearness-AREA_TRANSITION_DIST)/(1-AREA_TRANSITION_DIST),0,1);

    if(cascadeLevel<NUM_CASCADES-1 && areaBorderNearness+ditherValue>1)
        cascadeLevel++;
    scale = getScale(cascadeLevel);
#endif

    voxelCenter = (floor(worldPos/scale+normal*(scale/20))+0.5) * scale;

    ivec3 areaPos = worldPosToArea(voxelCenter,scale).xyz;
    vec3 subVoxelOffset = worldPos-voxelCenter;
    ivec3 areaShift = getAreaShift(scale);


    vec3 color = vec3(0);

#if SUBSURFACE_MODE==2
    vec3 hitBlockCenter = (floor(worldPos/scale-normal*(scale/20))+0.5) * scale;
    vec3 subSurfaceOffset = clamp(worldPos-hitBlockCenter,-0.5*scale,0.5*scale);
    ivec3 hitBlockAreaPos = worldPosToArea(hitBlockCenter,scale).xyz;
    float distFromFace = abs(0.5-max(max(abs(subVoxelOffset.x),abs(subVoxelOffset.y)),abs(subVoxelOffset.z))/scale);
    isCrossBlockModel = (dot(abs(normal.xz),vec2(0.70711))>=0.95) && (distFromFace>1.0/256);
#endif

#if DEBUG_GRID_OUTLINE >0
    vec3 edgeNearness = abs(subVoxelOffset*2/scale)+(DEBUG_GRID_OUTLINE/(64*scale));
    if((int(edgeNearness.x>=1)+int(edgeNearness.y>=1)+int(edgeNearness.z>=1))>=2){
        color = vec3(0.4);
    #ifdef DEBUG_SPLIT_VOXELS
        if(voxelIsSplit(areaPos,areaShift,cascadeLevel))
            color=vec3(0.5,0,0);
    #endif
    }
#endif

    if(!isVoxelInBounds(worldPos))
        return color*0.15;

#if DEBUG_AXIS>=0
    axis = DEBUG_AXIS;
#else
    for (axis=0;axis<6;axis++)
#endif
    {
       #if SUBSURFACE_MODE==2
        if(subsurface>0){
            ivec3 lVec = lVec(axis);
            ivec3 newPos = clamp(hitBlockAreaPos-lVec,0,AREA_SIZE-1);
            uint hitBlockPotentialBlocker = getVoxData(newPos, areaShift, areaOffset(cascadeLevel));
            float terrainBeforeBlock =(bool(hitBlockPotentialBlocker&WORLDVOX_OPAQUE))?scale:0;
            float depthIntoBlock = dot(subSurfaceOffset,lVec)+0.5*scale;
            subsurfaceLightDepth = depthIntoBlock+terrainBeforeBlock;
        }
       #endif
        vec3 zoneNorm = areaToZoneSpaceRelative(normal,axis);
        ivec3 zoneShift = areaToZoneSpace(areaShift, axis);
        ivec3 zonePos = areaToZoneSpace(areaPos, axis);
        vec3 zoneSubVoxelOffset = areaToZoneSpaceRelative(worldPos-voxelCenter,axis);


    #ifndef DEBUG_RADIANCE_ONLY
        for(uint layer = 0; layer<VOX_LAYERS; layer++)
            color+=getDirectedLight(cascadeLevel,layer,subsurface,zoneShift,zonePos,zoneNorm,zoneSubVoxelOffset,false,scale);
    #endif

        #ifdef FALLBACK_RADIANCE
        color+=sampleDirectedRadiance(cascadeLevel,subsurface,zoneShift,zonePos,zoneNorm,zoneSubVoxelOffset);
        #endif
    }

    return color;
}


vec3 voxelSampleFog(vec3 worldPos, float ditherValue){
    //TODO add a computationally cheap option and an option that weights based on how much of the fog line thru the voxel is lit
    uint cascadeLevel = getCascadeLevel(worldPos);
    float scale = getScale(cascadeLevel);

#if !(AREA_TRANSITION_DIST==-1)
    vec3 tmp = abs(worldPos-cameraPosition);
    float areaBorderNearness = max(max(tmp.x,tmp.y),tmp.z)/((AREA_SIZE-1)*0.5*scale);
    areaBorderNearness = clamp((areaBorderNearness-AREA_TRANSITION_DIST)/(1-AREA_TRANSITION_DIST),0,1);

    if(cascadeLevel<NUM_CASCADES-1 && areaBorderNearness+ditherValue>1)
        cascadeLevel++;
    scale = getScale(cascadeLevel);
#endif

    voxelCenter = (floor(worldPos/scale)+0.5) * scale;

    ivec3 areaPos = worldPosToArea(voxelCenter,scale).xyz;
    ivec3 areaShift = getAreaShift(scale);


    vec3 color = vec3(0);

#ifdef FOG_RANDOM_LESSER_SOURCE
    const int lightsInLoop = min(LIGHTS_PER_FOG_SAMPLE-1,VOX_LAYERS);
    uint randLayer = int(floor(float(VOX_LAYERS-lightsInLoop)*fract(37*fogNoise)))+lightsInLoop;
#else
    const int lightsInLoop = min(LIGHTS_PER_FOG_SAMPLE,VOX_LAYERS);
#endif

#if DEBUG_AXIS>=0
    axis = DEBUG_AXIS;
#else
    for (axis=0;axis<6;axis++)
#endif
    {
        ivec3 zoneShift = areaToZoneSpace(areaShift, axis);
        ivec3 zonePos = areaToZoneSpace(areaPos, axis);
        vec3 zoneSubVoxelOffset = areaToZoneSpaceRelative(worldPos-voxelCenter,axis);

        for(int layer = 0; layer<lightsInLoop; layer++){
            color+=getDirectedLight(cascadeLevel,layer,1.0,zoneShift,zonePos,vec3(0),zoneSubVoxelOffset,true,scale);
        }
#ifdef FOG_RANDOM_LESSER_SOURCE
        color+=getDirectedLight(cascadeLevel,randLayer,1.0,zoneShift,zonePos,vec3(0),zoneSubVoxelOffset,true,scale);
#endif
    }
    return color;
}