


#define SAMPLES_LIGHT_FACE

#include "/lib/voxel/voxelHelper.glsl"
#include "/lib/util/flicker.glsl"

#if false //dummy definition because my intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;vec3 lightTravel;float occlusionHitDistance;uint type;uint flags;};
#endif

vec3 getDirectedLight(uvec4 packedLightSrc, ivec3 blockPos, vec3 subVoxelOffset, vec3 normal, uint axis, float scale, float minNoL){
    lightVoxData lightSrc = unpackLightData(packedLightSrc);
    vec3 lightTravelWorld = lightSrc.lightTravel;

    if((axis&1u)==0)
    lightTravelWorld.z=-lightTravelWorld.z;

    if(axis>>1==0){
        subVoxelOffset=subVoxelOffset.yzx;
        normal = normal.yzx;
        lightTravelWorld = lightTravelWorld.zxy;
    }
    if(axis>>1==1){
        subVoxelOffset=subVoxelOffset.zxy;
        normal = normal.zxy;
        lightTravelWorld = lightTravelWorld.yzx;
    }

    if((axis&1u)==0){
        subVoxelOffset.z=-subVoxelOffset.z;
        normal.z=-normal.z;
    }

    blockPos-=ivec3(round(lightTravelWorld));


    vec3 displacement = lightSrc.lightTravel + subVoxelOffset;
    float lengthSquared = dot(displacement,displacement);
    float columnation = MIN_COLUMNATION;
    lengthSquared = lengthSquared*(1-columnation)+columnation;

    float lightStrength=0;

#ifdef EVERYTHING_IS_THE_SUN
    if(lightSrc.type>0)
        lightSrc.type=1;
#endif
    switch(lightSrc.type){
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


    const float b = 1/float(MAX_LIGHT_STRENGTH*MAX_LIGHT_STRENGTH);

    lightStrength*=inversesqrt(lengthSquared*lengthSquared*(1-columnation)+b);


    if( displacement.z>0)
        lightStrength==0;

    float lightDotN = -dot(normalize(displacement),normal);

    bool emissiveVoxel = displacement.z<=scale*0.51;
    if(emissiveVoxel && lightDotN<0)
        lightDotN=1;

    lightDotN=max(lightDotN,minNoL);



#if EVERYTHING_FACING_SRC==1
    if(lightDotN>0)
        lightDotN=1;
#elif EVERYTHING_FACING_SRC==2
    lightDotN=1;
#endif


#ifdef PRIDE_LIGHTING
    float len = sqrt(lengthSquared);
    vec3 normalColor = normalize(lightSrc.color);
    if(length(normalColor-normalize(vec3(8,7,4)))<0.1){

        if(2<=len && len<=2.5){
            lightSrc.color=vec3(1);
        }else if(1.5<=len && len<=3){
            lightSrc.color=vec3(1,0.5,0.8);
        }else{
            lightSrc.color=vec3(0.3,0.3,1);
            if(len>3)
                lightStrength*=2;
        }
    }else if(length(normalColor-normalize(vec3(8,5,2)))<0.15){
        switch(int(floor(len*2-1))){
            case 0:
                lightSrc.color=vec3(1,0,0);
                break;
            case 1:
                lightSrc.color=vec3(1,0.5,0);
                break;
            case 2:
                lightSrc.color=vec3(1,1,0);
                break;
            case 3:
                lightSrc.color=vec3(0,1,0);
                break;
            case 4:
                lightSrc.color=vec3(0,0,1);
                break;
            default:
                lightSrc.color=vec3(1.3,0,1.3);

        }
    }
#endif

#ifdef DEBUG_DECOLOR
    #ifdef DEBUG_OCCLUSION_MAP
    lightSrc.color=vec3(0.3);
    #endif
#endif

#ifdef PENUMBRAS_ENABLED
    //TODO make it so light occluded at 45deg also has penumbra fuzzing past the 45deg boundary
    if((abs(displacement.x)>displacement.z) || (abs(displacement.y)>displacement.z))
        lightStrength=0;
    lightStrength*=penumbralLightTest(displacement,lightSrc);
#else
    if((abs(displacement.x)>displacement.z) || (abs(displacement.y)>displacement.z))
        lightStrength=0;

    lightStrength=isLit(displacement,lightSrc) ? lightStrength:0;
#endif

    vec3 outColor = lightSrc.color*(lightStrength*lightDotN);

#ifdef DEBUG_OCCLUSION_MAP
    //Debug Coloring
    //green = fully lit,
    //bright red = fully unlit (should never happen)
    //blue = partially lit
    if(bool(lightSrc.type)){
        vec2 debugQuadrant = subVoxelOffset.xy;

    #ifdef UNFLIP_DEBUG_MAPS
        if(lightSrc.lightTravel.x<0)
            debugQuadrant.x*=-1;
        if(lightSrc.lightTravel.y<0)
            debugQuadrant.y*=-1;
    #endif

        ivec4 intMap = ivec4(lightSrc.occlusionMap);
        int mapSum = intMap.x+intMap.y+intMap.z+intMap.w;
        if(mapSum==0)
            outColor.r=1;
        if(mapSum==4)
            outColor.g+=0.05;

        bvec2 mapHalf = lightSrc.occlusionMap.yw;
        if(debugQuadrant.x>0)
            mapHalf=lightSrc.occlusionMap.xz;
        bool mapSpot = mapHalf.y;
        if(debugQuadrant.y>0)
            mapSpot = mapHalf.x;

        if(mapSum<4){
            if(!mapSpot){
                outColor.b+=0.2;
            }
            bvec4 edges = getOcclusionEdges(lightSrc.occlusionMap);
            if(
            (debugQuadrant.x>0 && edges.x) ||
            (debugQuadrant.x<0 && edges.z) ||
            (debugQuadrant.y>0 && edges.y) ||
            (debugQuadrant.y<0 && edges.w)
            ){
                outColor.r+=0.2;
            }
        }

        vec2 slopeDif = abs(lightSrc.occlusionRay-abs(displacement.xy/displacement.z));

        float outlineWidth = DEBUG_OUTLINE_WIDTH/displacement.z;
        if(slopeDif.x<outlineWidth || slopeDif.y<outlineWidth){
            outColor.rgb=vec3(0.6);
            outlineWidth*=0.5;
            if(slopeDif.x<outlineWidth || slopeDif.y<outlineWidth){
                outColor.rgb=vec3(0);
            }

        }

    }
#endif

#if DEBUG_SHOW_UPDATES >= 0
    #if DEBUG_SHOW_UPDATES==0
    if((axis>>1)!=1)
    #endif
    {
        uint frameIndicator = (frameCounter&0x3fu);
        uint frameIndicatorLight = (lightSrc.flags>>2)&0x3fu;
        vec3 axisColor = ivec3(areaToZoneSpaceMats[axis][2]);
        if ((axis&1u)==0)
            axisColor=abs(axisColor)*0.3+0.1;
        if (frameIndicator==frameIndicatorLight)
            outColor.rgb+=DEBUG_UPDATES_INTENSITY*(axisColor);
    }
#endif

#if DEBUG_GRID_OUTLINE >0
    vec3 edgeNearness = abs(subVoxelOffset*2/scale)+(DEBUG_GRID_OUTLINE/(64*scale));
    if((int(edgeNearness.x>=1)+int(edgeNearness.y>=1)+int(edgeNearness.z>=1))>=2){
        outColor.rgb=max(outColor.rgb*1.5,vec3(0.03));
    }
#endif
    return outColor;
}


vec3 voxelSample(vec3 worldPos, vec3 normal, bool fog){
    float scale = getScale(worldPos);

    vec3 voxelCenter = (floor(worldPos/scale+normal*(scale/64))+0.5) * scale;

    ivec4 areaPos = worldPosToArea(voxelCenter,scale);
    vec3 subVoxelOffset = worldPos-voxelCenter;
    ivec3 blockPos = ivec3(floor(voxelCenter));
    ivec3 areaShift = getAreaShift(scale);

    float minNoL = fog? 1:0;

    vec3 color = vec3(0);
    for(int layer = 0; layer<VOX_LAYERS; layer++){

#if DEBUG_AXIS>=0
        uint axis = debugAxisNum;
#else
        for (int axis=5;axis>=0;axis--)
#endif
        {
            ivec3 zoneShift = areaToZoneSpace(areaShift, axis);
            ivec3 zonePos = areaToZoneSpace(areaPos.xyz, axis);
            uint zoneMemOffset = zoneOffset(axis, layer);
            uvec4 packedSrc = sampleLightData(zonePos, zoneShift, zoneMemOffset);

            color+=getDirectedLight(packedSrc, blockPos, subVoxelOffset, normal, axis, scale,minNoL);
        }
        if(fog)
            break;
    }
    return color + MIN_LIGHT_AMOUNT*clamp(1-(color.x+color.y+color.z),0,1);
}

vec3 voxelSample(vec3 worldPos, vec3 normal){
    return voxelSample(worldPos,normal,false);
}

vec3 voxelSampleFog(vec3 worldPos){
    //TODO add a computationally cheap option and an option that weights based on how much of the fog line thru the voxel is lit
    return voxelSample(worldPos,vec3(0),true);
}