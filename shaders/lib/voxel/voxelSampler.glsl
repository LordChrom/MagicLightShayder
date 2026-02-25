

layout (rgba8ui) uniform readonly restrict uimage3D worldVox;

#define SAMPLES_LIGHT_FACE

#include "/lib/voxel/voxelHelper.glsl"

#if false //dummy definition because my intellij's best glsl plugin doesnt know includes exist
struct lightVoxData{vec2 occlusionRay;bvec4 occlusionMap;vec3 color;uint emission;vec3 lightTravel;float columnation;};
#endif

vec3 getDirectedLight(ivec4 sectionPos, vec3 subVoxelOffset, vec3 normal, uint axis, uint layer, float scale){
    if(axis>>1==0){
        subVoxelOffset=subVoxelOffset.yzx;
        normal = normal.yzx;
    }
    if(axis>>1==1){
        subVoxelOffset=subVoxelOffset.zxy;
        normal = normal.zxy;
    }

    if((axis&1u)==0){
        subVoxelOffset.z*=-1;
        normal.z*=-1;
    }

    lightVoxData lightSrc = getLightData(sectionPos,axis,layer);

    vec3 displacement = lightSrc.lightTravel + subVoxelOffset;
    float lengthSquared = dot(displacement,displacement);

    float columnation = lightSrc.columnation;
    lengthSquared = lengthSquared*(1-columnation)+columnation;

    float lightStrength = displacement.z>0 ? lightSrc.emission : 0;
    lightStrength*=0.5/(max(lengthSquared,0.001));

    float lightDotN = -dot(normalize(displacement),normal);

    bool emissiveVoxel = displacement.z<=scale*0.51;
    if(emissiveVoxel && lightDotN<0)
        lightDotN=1;

    lightDotN=max(lightDotN,0);

    bool receivesLight = lightDotN>=0 && lightSrc.emission>0;
    receivesLight = receivesLight && isLit(displacement,lightSrc);


    vec3 outColor = vec3(0);

    if(receivesLight){
        const float minLight = 0.01;
        #ifndef DEBUG_OCCLUSION_MAP
        lightStrength*=lightDotN;
        #endif


        #ifdef PRIDE_LIGHTING

        float len = sqrt(lengthSquared);

        if(length(lightSrc.color-(vec3(8,7,4)/8))<0.1){

            if(2<=len && len<=2.5){
                lightSrc.color=vec3(1);
            }else if(1.5<=len && len<=3){
                lightSrc.color=vec3(1,0.5,0.8);
            }else{
                lightSrc.color=vec3(0.3,0.3,1);
                if(len>3)
                    lightStrength*=2;
            }
        }else if(length(lightSrc.color-(vec3(9,8,4)/8))<0.15){
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

//        lightStrength=min(lightStrength,0); //mostly just for testing
        outColor += lightSrc.color*(minLight+(1-minLight)*min(lightStrength,1));

    }

    //Debug Coloring
    //green = fully lit,
    //bright red = fully unlit (should never happen)
    //blue = partially lit
    #ifdef DEBUG_OCCLUSION_MAP
    if(lightSrc.emission>0){
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
        outColor.g*=1.5;

        bvec2 mapHalf = lightSrc.occlusionMap.yw;
        if(debugQuadrant.x>0)
        mapHalf=lightSrc.occlusionMap.xz;
        bool mapSpot = mapHalf.y;
        if(debugQuadrant.y>0)
        mapSpot = mapHalf.x;

        if(mapSum<4){
            if(!mapSpot){
                outColor.b*=2;
            }
            bvec4 edges = getOcclusionEdges(lightSrc.occlusionMap);
            if(
            (debugQuadrant.x>0 && edges.x) ||
            (debugQuadrant.x<0 && edges.z) ||
            (debugQuadrant.y>0 && edges.y) ||
            (debugQuadrant.y<0 && edges.w)
            ){
                outColor.r*=2;
            }
        }

        vec2 slopeDif = abs(lightSrc.occlusionRay-abs(displacement.xy/displacement.z));

        float outlineWidth = DEBUG_OUTLINE_WIDTH/displacement.z;
        if(slopeDif.x<outlineWidth || slopeDif.y<outlineWidth){
            outColor.rgb=vec3(0.3);
            outlineWidth*=0.5;
            if(slopeDif.x<outlineWidth || slopeDif.y<outlineWidth){
                outColor.rgb=vec3(0);
            }

        }
    }
    #endif
    return outColor;
}


vec3 voxelSample(vec3 worldPos, vec3 normal){
//    worldPos+=vec3(0,0,-0.1); //TODO figure this out, probably something stupid

//    worldPos+=normal*0.001;
    float scale = 1;
    ivec4 sectionPos = worldPosToSection(worldPos,scale);
    vec3 subVoxelOffset = subVoxelOffset(worldPos,scale);

    vec3 color = vec3(0.2);
    for(int layer = 0; layer<VOX_LAYERS; layer++){

    #if DEBUG_AXIS>=0
        uint axis = debugAxisNum;
    #else
        for (int axis=0;axis<6;axis++)
    #endif
            color+=getDirectedLight(sectionPos, subVoxelOffset, normal, axis, layer, scale);

    }
    return max(color,0.06);
}