#define SAMPLES_LIGHT_FACE

#include "/lib/voxel/voxelHelper.glsl"
#include "/lib/util/flicker.glsl"
#include "/lib/util/misc.glsl"


float normalFactor(vec3 normal, vec3 displacement, uint axis, float subsurface){
    normal = areaToZoneSpaceRelative(normal,axis);

    float lightDotN =-dot(normalize(displacement),normal);
    subsurface*=0.4;
    lightDotN=clamp(max(lightDotN*(1-subsurface),0)+subsurface,0,1);
#if EVERYTHING_FACING_SRC==1
    if(lightDotN>0)
        return 1;
#elif EVERYTHING_FACING_SRC==2
    return 1;
#else
    return max(0,lightDotN);
#endif
}


const float b = 1/float(MAX_LIGHT_STRENGTH*MAX_LIGHT_STRENGTH);
const float sunStr = 1/float(MAX_LIGHT_STRENGTH)*inversesqrt(b);

float baseLightStrength(uint type, vec3 displacement, ivec3 blockPos, vec3 travel, uint axis){
    if(type==LIGHT_TYPE_SUN) return sunStr;

    blockPos-=zoneToAreaSpaceRelative(ivec3(round(travel)),axis);

    #ifdef EVERYTHING_IS_THE_SUN
    if(type>0) type=1;
    #endif

    float lightStrength=BLOCK_LIGHT_STRENGTH;

    if(type==3u) lightStrength *= pulsate();
    if(type==4u) lightStrength *= flicker(blockPos);

    float lengthSquared = dot(displacement,displacement);
    float columnation = MIN_COLUMNATION;
    lengthSquared = lengthSquared*(1-columnation)+columnation;
    return lightStrength*inversesqrt(lengthSquared*lengthSquared*(1-columnation)+b);
}


void doPenumbralOcclusion(inout float lightStrength, vec3 displacement, vec3 travel, uint packedOcclusionData){
    vec2 ray = unpackOcclusionRay(packedOcclusionData);
    uint map = unpackOcclusionMap(packedOcclusionData);


    float highSlope = max(abs(displacement.x),abs(displacement.y))/max(1e-9,displacement.z);
    float sharpener = (max(abs(travel.x),abs(travel.y))!=travel.z)? 1e9:1.0;
    float occHitDist = unpackOcclusionHitDist(packedOcclusionData);

    lightStrength*=clamp(0.5+(1-highSlope)*(sharpener/PENUMBRA_WIDTH),0,1);
    lightStrength*=penumbralLightTest(displacement,ray,map,occHitDist);
}
void doSharpOcclusion(inout float lightStrength, vec3 displacement, vec3 travel, uint packedOcclusionData){
    vec2 ray = unpackOcclusionRay(packedOcclusionData);
    uint map = unpackOcclusionMap(packedOcclusionData);

    lightStrength=max(abs(displacement.x),abs(displacement.y))<=displacement.z?lightStrength:0;
    lightStrength=isLit(displacement,ray,map) ? lightStrength:0;
}

void doSharpOcclusionPixelLocked(inout float lightStrength, vec3 displacement, vec3 travel, uint packedOcclusionData){
    vec2 ray = unpackOcclusionRay(packedOcclusionData);
    uint map = unpackOcclusionMap(packedOcclusionData);

    float highDisp = max(abs(displacement.x),abs(displacement.y));
    lightStrength=highDisp<=displacement.z?lightStrength*(highDisp<displacement.z?1:0.5):0;

    lightStrength=isLit(displacement,ray,map) ? lightStrength:0;
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


void doBonusEffects(inout vec3 color, uvec4 packedLightSrc, vec3 displacement, vec3 normal, uint axis){
    uint type = unpackLightType(packedLightSrc);

#ifdef PRIDE_LIGHTING
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
    color=vec3(0.3);
#endif
#ifdef DEBUG_OCCLUSION_MAP
    vec3 travel = unpackLightTravel(packedLightSrc);
    vec3 subVoxelOffset = displacement-travel;
    uint map = unpackOcclusionMap(packedLightSrc.w);

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
    vec2 ray = unpackOcclusionRay(packedLightSrc.w);

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
    float occHitDist = unpackOcclusionHitDist(packedLightSrc.w);
    if(occHitDist!=0){
        float wavey = occHitDist*0.5+1;
        color*=normalize(0.6+0.4*vec3(sin(wavey), sin(wavey+PI*2.0/3), sin(wavey+PI*4.0/3)));
}
#endif

#if DEBUG_SHOW_UPDATES >= 0
    float intensity = DEBUG_UPDATES_INTENSITY;
    #if DEBUG_SHOW_UPDATES==0
    float norm = bool(axis&4u)?normal.z:(bool(axis&2u)?normal.y:normal.x);
    if(abs(norm)>0.9)
        intensity*=0.1;
    #endif
    uint frameIndicator = (frameCounter&0x3fu);
    uint frameIndicatorLight = (unpackLightFlags(packedLightSrc)>>2)&0x3fu;
    vec3 axisColor = ivec3(areaToZoneSpaceMats[axis][2]);
    if ((axis&1u)==0)
        axisColor=abs(axisColor)*0.3+0.1;
    if (frameIndicator==frameIndicatorLight)
        color.rgb+=intensity*(axisColor);
#endif
}



vec3 getDirectedLight(uvec4 packedLightSrc, uint axis, float subsurface, ivec3 blockPos, vec3 normal, vec3 subVoxelOffset, bool isForFog){
    uint type = unpackLightType(packedLightSrc);
    if(type==0)return vec3(0);

    vec3 travel = unpackLightTravel(packedLightSrc);

    subVoxelOffset = areaToZoneSpaceRelative(subVoxelOffset,axis);
    vec3 displacement = travel + subVoxelOffset;

    float lightStrength;

    if(isForFog){
        lightStrength =(type==LIGHT_TYPE_SUN)?FOG_BRIGHTNESS_SUN:FOG_BRIGHTNESS_BLOCK;
        doFogOcclusion(lightStrength,displacement,travel,packedLightSrc.w);
    }else {
        lightStrength =normalFactor(normal, displacement, axis, subsurface);
        doTerrainOcclusion(lightStrength,displacement,travel,packedLightSrc.w);
    }

    //TODO okay so ive tested and its like a 1% improvement but it seems stupid so im leaving it off
//    if(lightStrength<=0)return vec3(0);


    lightStrength*= baseLightStrength(type,displacement,blockPos, travel, axis);

    vec3 color = unpackLightColor(packedLightSrc) * lightStrength;

    doBonusEffects(color,packedLightSrc,displacement, normal, axis);

    return color;
}

vec3 getDirectedLight(uint cascadeLevel, uint layer, uint axis, float subsurface, ivec3 zoneShift, ivec3 zonePos, ivec3 blockPos, vec3 normal, vec3 subVoxelOffset, bool isForFog){
    uint zoneMemOffset = zoneOffset(axis, layer,cascadeLevel);
    uvec4 packedLightSrc = sampleLightData(zonePos, zoneShift, zoneMemOffset);
    return getDirectedLight(packedLightSrc,axis,subsurface,blockPos,normal,subVoxelOffset,isForFog);
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
    #ifdef DEBUG_SPLIT_VOXELS
        if(voxelIsSplit(areaPos,areaShift,cascadeLevel))
            color=vec3(0.5,0,0);
    #endif
    }
#endif

    if(!isVoxelInBounds(worldPos))
        return color*0.15;

#if DEBUG_AXIS>=0
    uint axis = DEBUG_AXIS;
#else
    for (uint axis=0;axis<6;axis++)
#endif
    {
        ivec3 zoneShift = areaToZoneSpace(areaShift, axis);
        ivec3 zonePos = areaToZoneSpace(areaPos, axis);
        for(uint layer = 0; layer<VOX_LAYERS; layer++)
            color+=getDirectedLight(cascadeLevel,layer,axis,subsurface,zoneShift,zonePos,blockPos,normal,subVoxelOffset,false);
    }

    return color + MIN_LIGHT_AMOUNT*clamp(1-(color.x+color.y+color.z),0,1);
}


vec3 voxelSampleFog(vec3 worldPos, float fogNoise, float ditherValue){
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
        ivec3 zoneShift = areaToZoneSpace(areaShift, axis);
        ivec3 zonePos = areaToZoneSpace(areaPos, axis);
        for(int layer = 0; layer<lightsInLoop; layer++){
            color+=getDirectedLight(cascadeLevel,layer,axis,1.0,zoneShift,zonePos,blockPos,vec3(0),subVoxelOffset,true);
        }
#ifdef FOG_RANDOM_LESSER_SOURCE
        color+=getDirectedLight(cascadeLevel,randLayer,axis,1.0,zoneShift,zonePos,blockPos,vec3(0),subVoxelOffset,true);
#endif
    }
    return color;
}