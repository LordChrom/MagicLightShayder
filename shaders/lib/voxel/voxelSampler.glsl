
layout (rgba32ui) uniform readonly restrict uimage3D lightVox;
layout (rgba8ui) uniform readonly restrict uimage3D worldVox;

#include "/lib/settings.glsl"
#include "/lib/voxel/voxelHelper.glsl"

vec3 voxelSample(vec3 worldPos, vec3 normal){
    worldPos+=vec3(0,0,-0.1); //TODO figure this out, probably something stupid

    worldPos+=normal*0.001;
    ivec3 sectionPos = worldPosToSection(worldPos,1);
    lightVoxData lightSrc = unpackLightData(imageLoad(lightVox, sectionPos));

    float lightStrength = lightSrc.emission/15.0;

    vec3 subVoxelOffset = subVoxelOffset(worldPos,1);
    vec3 displacement = lightSrc.lightTravel + subVoxelOffset;

    lightStrength*=step(0,displacement.z);

    float lengthSquared = dot(displacement,displacement);

    lightStrength/=max(lengthSquared,0.01);


    float lightDotN = -dot(displacement,normal);

    bool receivesLight = lightDotN>=0 && lightSrc.emission>0;
    receivesLight = receivesLight && isLit(displacement,lightSrc);


    vec3 outColor = vec3(0.07);

    if(receivesLight){
        lightStrength=max(lightStrength,0.03); //mostly just for testing
        outColor += lightSrc.color*(0.1+0.9*min(lightStrength,1));
    }

    //Debug Coloring
    //green = fully lit,
    //bright red = fully unlit (should never happen)
    //blue = partially lit
    #ifdef DEBUG_OCCLUSION_MAP
    if(lightSrc.emission>0 && true){
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


    }
    #endif

    return outColor;
}