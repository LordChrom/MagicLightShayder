#include "/lib/util/conversions.glsl"

#define TWOPI 6.28318530718

float doClassicSsao(vec2 texcoord, vec3 normal, float solidDepth, float dither){
    vec2 normalDir = (gbufferModelView*vec4(normal.xyz, 0)).xy;
    normalDir=normalize(normalDir);
#ifdef TAA
    dither=temporalNoise(dither);
#endif
    float totalWeight = 0;
    float total = 0;

    solidDepth = depthToLinear(solidDepth);
    float radius = (SSAO_RADIUS*0.3)/solidDepth;
    radius = min(radius,0.15);


    const int anglesPerLevel = 2;
    for(int r = 1; r<=SSAO_QUALITY; r++){
        float tempRadius = (r-dither)/(SSAO_QUALITY);
        int angles = (anglesPerLevel*r-1)|1;

        for(int a = 0; a<angles;a++){
            float angle = (a+dither)*(TWOPI/angles);
            vec2 offset = vec2(cos(angle),sin(angle))*tempRadius;
            float d = dot(normalize(offset),normalDir);
            offset = d>-0?offset:-offset;
            float weight = abs(d);
            weight/=(tempRadius+0.2);

            offset = offset*radius + texcoord;

            float sampledDepth = depthToLinear(texture(depthtex2,offset).x);

            sampledDepth+=0.01*dot(offset,offset);

            if(abs(sampledDepth-solidDepth)<0.001)
                continue;

#ifdef SSAO_DELBEED
            weight*=clamp((sampledDepth-solidDepth)+SSAO_RADIUS,0,1);
#endif

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

float doGtao(vec2 texcoord, vec3 normal, float solidDepth, float dither){
    if(solidDepth>0.99999)
        return 1;
    #ifdef TAA
    dither=temporalNoise(dither);
    #endif

    vec4 worldPos = gbufferProjectionInverse*(vec4(texcoord,texture(depthtex2,texcoord).x,1)*2-1);
    worldPos=gbufferModelViewInverse*vec4(worldPos.xyz/worldPos.w,1);

    float gamma = 0;
    solidDepth = depthToLinear(solidDepth);
    float radius = (SSAO_RADIUS*0.3)/solidDepth;
    radius = min(radius,0.15);

    const int numDirections = ((3*SSAO_QUALITY)+1)&~1;
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
            vec2 offset = vec2(cos(angle),sin(angle))*tempRadius;

            offset += texcoord;
            vec4 pos = gbufferProjectionInverse*(vec4(offset,texture(depthtex2,offset).x,1)*2-1);
            pos=gbufferModelViewInverse*vec4(pos.xyz/pos.w,1);
            pos-=worldPos;
            float wallAngle = asin(max(0,dot(normalize(pos.xyz),normal)));
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
    ssao*=ssao;
    ssao=1-(1-ssao)*SSAO_STRENGTH;
    return clamp(ssao,0.2,1);
}

//#define doSsao doClassicSsao
#define doSsao doGtao