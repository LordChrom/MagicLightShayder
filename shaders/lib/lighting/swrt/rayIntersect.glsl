float depthTillChange(float value, float differential){
    return (1-fract(value*sign(differential)))/abs(differential);

}

float minDepthTillChange(vec3 value, vec3 differential){
    value = 1-fract(value*sign(differential));
    value/=abs(differential);
    return min(min(value.x,value.y),value.z);
}
const float nudge = 0.0001;

bool rayHitsShapedBlock(vec3 samplePos, vec3 dir, float d, uint shape){
    samplePos=fract(samplePos);
    vec3 postPos = samplePos+dir*d;
    uint shapeCat = shape>>4;

    uint slabCheckAxis=2u;
    float slabCheckDepth = 0f;

    if(shapeCat<=2u){
        slabCheckDepth=8f;
        slabCheckAxis|=shapeCat;
    }else if (shapeCat==3u){
        slabCheckAxis=shape&0xfu;
        slabCheckDepth=3f;
    }else if (shapeCat==4u){
        slabCheckDepth=shape&0xfu;
    }

    vec2 axisCoords = vec2(samplePos[slabCheckAxis>>1],postPos[slabCheckAxis>>1]);
    if(bool(slabCheckAxis&1u))
        axisCoords=1f-axisCoords;
    if(min(axisCoords.x,axisCoords.y)*16f<slabCheckDepth)
        return true;

    if(shapeCat<=2u){
        vec3 halfwayChange = samplePos + dir*(minDepthTillChange(samplePos*2,dir)*0.5+nudge);
        uint corners = 1u << (uint(halfwayChange.x<0.5)+2*uint(halfwayChange.z<0.5));
        corners |= 1u << (uint(samplePos.x<0.5)+2*uint(samplePos.z<0.5));
        corners |= 1u << (uint(postPos.x<0.5)+2*uint(postPos.z<0.5));

        if(bool(shape&corners))
            return true;
    }

    return false;
}

float traceRay(vec3 worldPos, vec3 worldDirToLight, uint maxSteps,
    out uint translucency
){
    translucency = 0u;
    worldPos+=(VOXELIZATION_SIZE>>1)-unitShift;

    ivec3 finalBlock = ivec3(floor(worldPos+worldDirToLight));
    uint finalVoxel = getBaseVoxData(finalBlock,unitShift);

    float maxTraceDepth = length(worldDirToLight);
    worldDirToLight=normalize(worldDirToLight);

    float depth = nudge;
    for(int i=0;i<maxSteps && depth<maxTraceDepth;i++){
        vec3 samplePosition = worldPos+depth*worldDirToLight;
        ivec3 areaPos = ivec3(floor(samplePosition));
        uint voxel = getBaseVoxData(areaPos,unitShift);
        float nextDepthDif = minDepthTillChange(samplePosition,worldDirToLight)+nudge;

        areaPos-=finalBlock;
        int dist = abs(areaPos.x)+abs(areaPos.y)+abs(areaPos.z);

        if(dist==0)
            break;

        if(dist==1 && voxel==finalVoxel)
            break;

        if(bool(voxel&WORLDVOX_OPAQUE))
            return depth;

        #ifdef SWRT_SHAPED_BLOCKS
        //TODO better coherence on this, do it in batches
        uint shape = blockShape(voxel);
        if(shape>=16u){
            if(rayHitsShapedBlock(samplePosition,worldDirToLight,nextDepthDif,shape))
                return depth;
        }
        #endif

        #if SWRT_TRANSLUCENCY>0
        if(blockIsTranslucent(voxel))
            translucency = (translucency<<6) | blockLightID(voxel);
        #endif

        depth+=nextDepthDif;
    }

    return -1;
}

float traceRay(vec3 worldPos, vec3 worldDirToLight, uint maxSteps){
    uint h;
    return traceRay(worldPos,worldDirToLight,maxSteps,h);
}