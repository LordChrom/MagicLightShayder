#include "/lib/util/conversions.glsl"


float doSsao(vec2 texcoord, vec2 normalDir, float solidDepth, float dither){
    float totalWeight = 0;
    float total = 0;

    solidDepth = depthToLinear(solidDepth);
    float radius = (SSAO_RADIUS*0.3)/solidDepth;
    radius = min(radius,0.15);


    const int anglesPerLevel = 2;
    for(int r = 1; r<=SSAO_QUALITY; r++){
        float tempRadius = (r-dither)/(SSAO_QUALITY);
        int angles = (anglesPerLevel*r)|1;

        for(int a = 0; a<angles;a++){
            float angle = (a+dither)*(6.28318530718/angles);
            vec2 offset = vec2(cos(angle),sin(angle))*tempRadius;
            float d = dot(normalize(offset),normalDir);
            offset = d>-0?offset:-offset;
            float weight = abs(d);

            offset = offset*radius + texcoord;

            if(offset.x>1.0 || offset.y>1.0 || offset.x<0 || offset.y<0)
                continue;
            float sampledDepth = depthToLinear(texture(depthtex2,offset).x);

            if(abs(sampledDepth-solidDepth)<0.001)
                continue;

            totalWeight+=weight;
            if(sampledDepth>solidDepth)
                total+=weight;
        }
    }

    if(totalWeight==0)
        return 1;
    float ssao = float(total)/float(totalWeight);
    ssao*=ssao;
    ssao=1-(1-ssao)*SSAO_STRENGTH;
    return clamp(ssao,0.2,1);
}