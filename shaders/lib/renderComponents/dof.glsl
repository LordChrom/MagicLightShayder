uniform mat4 gbufferProjectionInverse;
#include "/lib/util/conversions.glsl"

#define PI 3.1419526535897932


uniform sampler2D colortex0;
uniform sampler2D depthtex0;


//approximation taken from wikipedia;
float erfCheap(float x){
    float xsq=x*x;
    const float a = 0.147;
    float axsq = a*xsq;
    return sign(x)*sqrt(1-exp(-xsq*(4/PI+axsq)/(1+axsq)));
}

float erf(float x){
    return erfCheap(x);
}

float normDist(float x, float stdev){
    const float invRootTwoPi = inversesqrt(2*PI);
    float c = invRootTwoPi/stdev;
    float a = abs(x/stdev);
    float ret = c;
    c *= exp(-0.5*a*a);
    return c;
}

float normDistIntegral(float x1, float x2, float stdev){
    float s = (1/sqrt(2))/stdev;
    x1*=s;
    x2*=s;

    return 0.5*(erf(x2)-erf(x1));
}

float getBlurWeight(float depth, float depthTarget, float angle, float passwidth){
    const float focalLength = 0.23;
    float depthDif = abs(depth-depthTarget);

    if(depthTarget<10){
        depthDif=max(0.1,depthDif-depthTarget*0.5);
        depthTarget=5+0.5*depthTarget;
    }

    float stdev = depthDif/depth * (focalLength)/max(0.1,depthTarget-focalLength);
    stdev*=5;
    float weight = normDistIntegral(angle-passwidth,angle+passwidth,stdev);

    return weight;
}

uniform float centerDepthSmooth;

vec3 dofBlur(ivec2 texpos, int d){
    float dofDepth = depthToLinear(centerDepthSmooth);
    vec3 ret = vec3(0);
    float dAngle = (90.0/viewHeight)*d*0.333; //TODO make better

    float dE = dAngle;
    float dC = dE*sqrt(2);
    ivec2 offsetTexpos;

    const float fudgeAmount = 0.3;
    for(int x=-d; x<=d; x+=d){
        offsetTexpos.x=texpos.x+x;
        float fudgeX = 1-(x==0?0:fudgeAmount);
        for(int y=-d; y<=d; y+=d){
            float fudge = fudgeX-(y==0?0:fudgeAmount);

            offsetTexpos.y=texpos.y+y;
            float depth = texelFetch(depthtex0,offsetTexpos,0).x;
            depth = distFromCamera(vec3(texcoord,depth));
            vec3 color = texelFetch(colortex0,offsetTexpos,0).rgb;
            float w = getBlurWeight(depth,dofDepth, bool(x|y)?((bool(x)&&bool(y))?dC : dE):0, dAngle*0.5);
            w*=fudge;
            ret += w*color;

        }
    }
    return ret;
}
