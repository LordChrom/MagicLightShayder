const int numSsaoAngles = 2*SSAO_QUALITY+1;
#include "/lib/util/conversions.glsl"

#define SSAO_MIP 2
#define TWOPI 6.28318530718

float doSsao(vec2 texcoord, vec3 normal, float dither){
    normal = transpose(mat3(gbufferModelViewInverse))*normal;
    float solidDepth=texelFetch(colortex5,ivec2(texcoord*textureSize(colortex5,0)),0).x;

    #ifdef TAA
    dither=temporalNoise(dither);
    #endif

    if(solidDepth>0.99999
        || bool(floatBitsToUint(solidDepth)&1u)
    )
        return 1.0;
    vec4 worldPos = gbufferProjectionInverse*(vec4(texcoord,solidDepth,1)*2-1);
    worldPos/=worldPos.w;

    float radius = (SSAO_RADIUS)/depthToLinear(solidDepth);
    radius*=0.5;
    radius = min(radius*(0.01+sqrt(dither)),0.10);

    float sum = 0;

    dither = recycleNoise(dither);

    for(int a = 0; a<numSsaoAngles;a++){
        float angle = fract(float(a)/numSsaoAngles-dither)*TWOPI;
        vec4 pos;
        pos.xy = texcoord + vec2(cos(angle),sin(angle))*radius;
        pos.z = textureLod(colortex5,pos.xy,SSAO_MIP).x;

        pos = gbufferProjectionInverse*vec4(pos.xyz*2.0-1.0,1.0);
        pos.xyz=pos.xyz/pos.w-worldPos.xyz;

        float attenuation = clamp((SSAO_RADIUS*2.0)/length(pos.xyz),1.0-SSAO_LEAK_REDUCTION,1.0);

        float wallAngleSin = max(dot(normalize(pos.xyz),normal)*attenuation,0);
        sum += wallAngleSin*wallAngleSin;
    }


    //0 = fully lit, 1 = fully occluded
    float ssao = sum*(0.5*PI/numSsaoAngles);

    //    return ssao>0.01?0:1;
    ssao*=SSAO_STRENGTH;
    return clamp(1-ssao,0.2,1);
}