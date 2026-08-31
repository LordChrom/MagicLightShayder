#include "/lib/util/conversions.glsl"

#define TWOPI 6.28318530718

float doSsao(vec2 texcoord, vec3 normal, float solidDepth, float dither){
    if(solidDepth>0.99999)
        return 1;
    #ifdef TAA
    dither=temporalNoise(dither);
    #endif

    vec4 worldPos = gbufferProjectionInverse*(vec4(texcoord,solidDepth,1)*2-1);
    worldPos=gbufferModelViewInverse*vec4(worldPos.xyz/worldPos.w,1);

    float gamma = 0;
    solidDepth = depthToLinear(solidDepth);
    float radius = (SSAO_RADIUS*0.6)/solidDepth;
    radius = min(radius,0.15);

    const int numAgnles = 2*SSAO_QUALITY+1;
    const int numDirections = numAgnles;

    float sum = 0;


    float angleDither = fract(23*dither);
    {
        float tempRadius = radius*(dither);

        for(int a = 0; a<numAgnles;a++){
            float angle = fract(float(a)/numAgnles-angleDither)*TWOPI;
            vec2 offsetPos = texcoord + vec2(cos(angle),sin(angle))*tempRadius;

            vec4 pos = gbufferProjectionInverse*(vec4(offsetPos,texture(depthtex2,offsetPos).x,1)*2-1);
            pos.xyz=mat3(gbufferModelViewInverse)*(pos.xyz/pos.w)+gbufferModelViewInverse[3].xyz;;
            pos.xyz-=worldPos.xyz;
            float wallAngle = asin(clamp(dot(pos.xyz,normal),0,1)/min(length(pos.xyz),3));
            sum -= cos(2*wallAngle);
        }
    }


    //0 = fully lit, 1 = fully occluded
    float ssao = 0.25*PI*(1+sum/numAgnles);
    ssao*=SSAO_STRENGTH;
    return clamp(1-ssao,0.2,1);
}