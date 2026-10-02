//reasons
//0: no hits / step limit
//1: hit edge of screen
//2: hit something, but depth too different
//4: hit solid terrain
vec3 screenspaceRaycast(int stepsPerBounce, float maxCastLen,
    vec3 pos, vec3 viewDir, float ditherValue, bool fadeAtEdges,
    out uint hitReason
){
    hitReason=0;
    viewDir*=maxCastLen/(stepsPerBounce*length(viewDir.xy));
    float texDepth = 0f;

    pos+=(ditherValue-1)*viewDir;
    int i;
    for(i=0;i<stepsPerBounce && hitReason==0;i++){
        pos+=viewDir;
        texDepth = texelFetch(colortex5,ivec2(pos.xy*textureSize(colortex5,0)),0).x;

        float distFromEdge = min(viewDir.x>0?1-pos.x:pos.x,viewDir.y>0?1-pos.y:pos.y);

        if(distFromEdge<=(fadeAtEdges?ditherValue*0.1:0) || pos.z<=0.4 || pos.z>=1){
            hitReason=1;
        }else if(texDepth<=pos.z){
            hitReason=4;
        }
    }

    if(bool(floatBitsToUint(texDepth)&1u)) //hand
        hitReason=2;

    if(hitReason==4){
        if(i==1) //if the first step is a hit, this prevents the back marching from going behind the ray source
            viewDir*=ditherValue;

        viewDir*=0.5;
        pos-=viewDir;

        for(int i=0;i<8;i++){
            texDepth = texelFetch(colortex5,ivec2(pos.xy*textureSize(colortex5,0)),0).x;
            viewDir*=0.5;
            pos+=(texDepth>=pos.z)?viewDir:-viewDir;
        }

        if(
            bool(floatBitsToUint(texDepth)&1u) ||
            abs(depthToLinear(texDepth)/depthToLinear(pos.z)-1)>0.05
        ){
            hitReason=2;
        }
    }

    return pos;
}