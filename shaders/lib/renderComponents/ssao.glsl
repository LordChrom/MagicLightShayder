const int numSsaoAngles = 2*SSAO_QUALITY+1;
#include "/lib/util/conversions.glsl"

#define TWOPI 6.28318530718

float doSsao(vec3 normal, float dither){
    normal = transpose(mat3(gbufferModelViewInverse))*normal;
    float solidDepth=texelFetch(colortex5,ivec2(texcoord*textureSize(colortex5,0)),0).x;

    #ifdef TAA
    dither=temporalNoise(dither);
    #endif

    uint isHand = floatBitsToUint(solidDepth)&1u;
    if(solidDepth>0.99999)
        return 1.0;
    vec4 worldPos = gbufferProjectionInverse*(vec4(texcoord,solidDepth,1)*2-1);
    worldPos/=worldPos.w;

    float radius = (SSAO_RADIUS)/depthToLinear(solidDepth);
    radius*=0.5;
    radius = radius*sqrt(dither*0.9+0.1);

    float sum = 0;

    dither = recycleNoise(dither);

    ivec2 texsize = textureSize(colortex5,0);
    for(int a = 0; a<numSsaoAngles;a++){
        float angle = fract(float(a)/numSsaoAngles-dither)*TWOPI;
        vec2 posxy = texcoord + vec2(cos(angle),sin(angle))*radius;
        if(abs(posxy.x-0.5)>0.5 || abs(posxy.y-0.5)>0.5) continue;

        float depth = texelFetch(colortex5,ivec2(posxy*texsize),0).x;
        vec4 pos = mat2x4(gbufferProjectionInverse)*(posxy*2.0-1.0)+gbufferProjectionInverse[3];

        if(bool((floatBitsToUint(depth)&1u)^isHand)) continue;
        pos += gbufferProjectionInverse[2]*(depth*2.0-1.0);
        pos.xyz=pos.xyz/pos.w-worldPos.xyz;

        float len = length(pos.xyz);
        float attenuation = clamp(SSAO_RADIUS*2-len+1.0,0,1.0);

        float wallAngleSin = max(dot(normalize(pos.xyz),normal)*attenuation,0);
        sum += wallAngleSin*wallAngleSin;
    }


    //0 = fully lit, 1 = fully occluded
    float ssao = sum*(0.5*PI/numSsaoAngles);

    #if SSAO_FILTERING>0
    const float f= 1.8284; //sqrt(8)-1
    ssao =f*ssao+subgroupShuffle(ssao,gl_SubgroupInvocationID^1u);
    ssao =f*ssao+subgroupShuffle(ssao,gl_SubgroupInvocationID^2u);

    #if SSAO_FILTERING>0
    ssao =f*ssao+subgroupShuffle(ssao,gl_SubgroupInvocationID^5u);
    ssao =f*ssao+subgroupShuffle(ssao,gl_SubgroupInvocationID^10u);
    ssao /=64f;
    #else
    ssao /=8f;
    #endif
    #endif

    ssao*=SSAO_STRENGTH;
    return clamp(1-ssao,0.2,1);
}