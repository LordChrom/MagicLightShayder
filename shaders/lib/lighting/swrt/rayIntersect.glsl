float depthTillChange(float value, float differential){
    return (1-fract(value*sign(differential)))/abs(differential);

}

float minDepthTillChange(vec3 value, vec3 differential){
    value = 1-fract(value*sign(differential));
    value/=abs(differential);
    return min(min(value.x,value.y),value.z);
}

float traceRay(vec3 worldPos, vec3 worldDirToLight, ivec3 unitShift, uint maxSteps){
    worldPos+=(VOXELIZATION_SIZE>>1)-unitShift;

    ivec3 finalBlock = ivec3(floor(worldPos+worldDirToLight));

    float maxTraceDepth = length(worldDirToLight);
    worldDirToLight=normalize(worldDirToLight);

    const float nudge = 0.0001;

    float depth = nudge;
    for(int i=0;i<maxSteps && depth<maxTraceDepth;i++){
        vec3 samplePosition = worldPos+depth*worldDirToLight;
        ivec3 areaPos = ivec3(floor(samplePosition));
        uint voxel = getBaseVoxData(areaPos,unitShift);
        float nextDepthDif = minDepthTillChange(samplePosition,worldDirToLight)+nudge;

        if(areaPos==finalBlock)
        break;

        if(bool(voxel&WORLDVOX_OPAQUE))
        return depth;

        depth+=nextDepthDif;
    }

    return -1;
}