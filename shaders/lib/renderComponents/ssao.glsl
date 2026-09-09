#include "/lib/util/conversions.glsl"

#define TWOPI 6.28318530718

float doSsao(vec2 texcoord, vec3 normal, float solidDepth, float dither){
    if(solidDepth>0.99999)
        return 1;
    #ifdef TAA
    dither=temporalNoise(dither);
    #endif

    vec4 worldPos = gbufferProjectionInverse*(vec4(texcoord,solidDepth,1)*2-1);
    worldPos/=worldPos.w;

    float radius = (SSAO_RADIUS)/depthToLinear(solidDepth);
    radius*=0.5;
    radius = min(radius*(0.01+sqrt(dither)),0.15);

    const int numAngles = 2*SSAO_QUALITY+1;

    float sum = 0;

    normal = transpose(mat3(gbufferModelViewInverse))*normal;

    float angleDither = fract(23*dither);

    for(int a = 0; a<numAngles;a++){
        float angle = fract(float(a)/numAngles-angleDither)*TWOPI;
        vec2 offsetTexcoord = texcoord + vec2(cos(angle),sin(angle))*radius;

        vec4 pos = (vec4(offsetTexcoord,texture(depthtex2,offsetTexcoord).x,1)*2-1);
        pos = gbufferProjectionInverse*pos;
        pos.xyz/=pos.w;
        pos-=worldPos;

        float attenuation = length(pos.xyz);
        attenuation = clamp((SSAO_RADIUS*2.0)/length(pos.xyz),1.0-SSAO_LEAK_REDUCTION,1.0);

        float wallAngle = asin(clamp(dot(normalize(pos.xyz),normal)*attenuation,0,1));
        sum -= cos(2*wallAngle);
    }



    //0 = fully lit, 1 = fully occluded
    float ssao = 0.25*PI*(1+sum/numAngles);

//    return ssao>0.01?0:1;
    ssao*=SSAO_STRENGTH;
    return clamp(1-ssao,0.2,1);
}