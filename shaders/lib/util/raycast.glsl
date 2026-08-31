//reasons
//0: no hits
//1: hit edge of screen
//2: hit something, but depth too different
//4: hit solid terrain
vec3 screenspaceRaycast(
    sampler2D depthtex, int stepsPerBounce, float maxCastLen,
    vec3 initialPos, vec3 viewDir, float ditherValue,
    out uint hitReason
){
    hitReason=0;
    viewDir*=maxCastLen/(REFLECTION_QUALITY*length(viewDir.xy));
    vec3 newPos;
    float texDepth;

    for(int i=0;i<stepsPerBounce;i++){
        newPos = initialPos+(i+ditherValue)*viewDir;
        float distFromEdge =min(min(newPos.x,newPos.y),1-max(newPos.x,newPos.y));
        if(distFromEdge<ditherValue*0.1 || newPos.z<=0.4 || newPos.z>=1){
            hitReason=1;
            break;
        }

        //TODO check both depthtexes, for reflections of terrain visible thru glass
        texDepth = texture(depthtex,newPos.xy).x;
        if(texDepth<=newPos.z){
            hitReason=4;
            break;
        }
    }

    if(hitReason==4){
        viewDir*=0.5;
        newPos-=viewDir;

        for(int i=0;i<min(stepsPerBounce,8);i++){
            texDepth = texture(depthtex,newPos.xy).x;
            viewDir*=0.5;
            newPos+=(texDepth>=newPos.z)?viewDir:-viewDir;
        }
    }

    if((hitReason==4) && (abs(depthToLinear(texDepth)/depthToLinear(newPos.z)-1)>0.1)){
        hitReason=2;
    }

    return newPos;
}