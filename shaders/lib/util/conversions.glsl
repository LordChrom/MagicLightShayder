float depthToLinear(float sampleDepth){
    sampleDepth = sampleDepth*2-1;

    vec2 awa = (gbufferProjectionInverse*vec4(0.5,0.5,sampleDepth,1)).yw;
    return awa.x/awa.y;
}