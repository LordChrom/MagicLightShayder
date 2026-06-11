uniform vec3 depthConvConsts;

//uniform mat4 gbufferProjectionInverse;
float depthToLinear(float sampleDepth){
    sampleDepth = sampleDepth*2-1;

    return  depthConvConsts.x/ (depthConvConsts.y + depthConvConsts.z*sampleDepth);
//    return  (gbufferProjectionInverse[1].y)/ (gbufferProjectionInverse[3].w + gbufferProjectionInverse[2].w*sampleDepth);
//    return  (gbufferProjectionInverse[0].y+gbufferProjectionInverse[1].y+gbufferProjectionInverse[3].y + gbufferProjectionInverse[2].y*sampleDepth)/
//    (gbufferProjectionInverse[0].w+gbufferProjectionInverse[1].w+gbufferProjectionInverse[3].w + gbufferProjectionInverse[2].w*sampleDepth);
}

float depthToBuf(float worldDepth){
        float sampleDepth =  (depthConvConsts.x/worldDepth-depthConvConsts.y)/depthConvConsts.z;

//    float sampleDepth = ((gbufferProjectionInverse[1].y)/worldDepth-gbufferProjectionInverse[3].w)/gbufferProjectionInverse[2].w;
    return (sampleDepth+1)*0.5;
}