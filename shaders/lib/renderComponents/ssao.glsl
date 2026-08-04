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
    float radius = (SSAO_RADIUS*0.3)/solidDepth;
    radius = min(radius,0.15);

    const int numDirections = ((2*SSAO_QUALITY))&~1;
    float[numDirections] directions;
    for(int i=0;i<numDirections;i++)
        directions[i]=0;


    float angleDither = fract(23*dither);
    const int anglesPerLevel = 2;
    for(int r = 1; r<=SSAO_QUALITY; r++)
    {
        float tempRadius = radius*(r-dither)/SSAO_QUALITY;
        int angles = (anglesPerLevel*r-1)|1;

        for(int a = 0; a<angles;a++){
            float angle = (a+angleDither)*(TWOPI/angles);
            vec2 offsetPos = texcoord + vec2(cos(angle),sin(angle))*tempRadius;

            vec4 pos = gbufferProjectionInverse*(vec4(offsetPos,texture(depthtex2,offsetPos).x,1)*2-1);
            pos.xyz=mat3(gbufferModelViewInverse)*(pos.xyz/pos.w)+gbufferModelViewInverse[3].xyz;;
            pos.xyz-=worldPos.xyz;
            float wallAngle = asin(clamp(dot(pos.xyz,normal),0,1)/min(length(pos.xyz),3));
            int index = int(floor(angle*numDirections/TWOPI));
            directions[index]=max(directions[index],wallAngle);
        }
    }

    float sum = numDirections;
    for(int i=0;i<numDirections>>1;i++){
        float L = directions[i];
        float R = directions[i+(numDirections>>1)];
        float innerIntegral = -cos(2*L)-cos(2*R);
        sum+=innerIntegral;
    }
    sum*=0.25;

    float ssao = 1-sum*PI/numDirections;
//    ssao*=ssao;
    ssao=1-(1-ssao)*SSAO_STRENGTH;
    return clamp(ssao,0.2,1);
}