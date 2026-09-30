//reasons
//0: no hits / step limit
//1: hit edge of screen
//2: hit something, but depth too different
//4: hit solid terrain
vec3 screenspaceRaycast(int stepsPerBounce, float maxCastLen,
    vec3 initialPos, vec3 viewDir, float ditherValue, bool fadeAtEdges,
    out uint hitReason
){
    hitReason=0;
    viewDir*=maxCastLen/(stepsPerBounce*length(viewDir.xy));
    vec3 newPos;
    float texDepth;

    for(int i=0;i<stepsPerBounce && hitReason==0;i++){
        newPos = initialPos+(i+ditherValue)*viewDir;
        float distFromEdge = min(viewDir.x>0?1-newPos.x:newPos.x,viewDir.y>0?1-newPos.y:newPos.y);

        if(distFromEdge<=(fadeAtEdges?ditherValue*0.1:0) || newPos.z<=0.4 || newPos.z>=1){
            hitReason=1;
        }else{
            texDepth = texelFetch(colortex5,ivec2(newPos.xy*textureSize(colortex5,0)),0).x;
            if(texDepth<=newPos.z+1e-4)
                hitReason=4;
        }
    }

    if(bool(floatBitsToUint(texDepth)&1u)) //hand
        hitReason=2;

    if(hitReason==4){
        viewDir*=0.5;
        newPos-=viewDir;

        for(int i=0;i<min(stepsPerBounce,8);i++){
            texDepth = texelFetch(colortex5,ivec2(newPos.xy*textureSize(colortex5,0)),0).x;
            viewDir*=0.5;
            newPos+=(texDepth>=newPos.z)?viewDir:-viewDir;
        }
    }

    if((hitReason==4) && (abs(depthToLinear(texDepth)/depthToLinear(newPos.z)-1)>0.1)){
        //TODO Some kinda problem here
        hitReason=2;
    }

    return newPos;
}