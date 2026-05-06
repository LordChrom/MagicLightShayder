float depthToLinear(float sampleDepth){
    sampleDepth = sampleDepth*2-1;

    return  (gbufferProjectionInverse[1].y + gbufferProjectionInverse[2].y*sampleDepth)/ (gbufferProjectionInverse[3].w + gbufferProjectionInverse[2].w*sampleDepth);

//    return  (gbufferProjectionInverse[0].y+gbufferProjectionInverse[1].y+gbufferProjectionInverse[3].y + gbufferProjectionInverse[2].y*sampleDepth)/
//    (gbufferProjectionInverse[0].w+gbufferProjectionInverse[1].w+gbufferProjectionInverse[3].w + gbufferProjectionInverse[2].w*sampleDepth);
}