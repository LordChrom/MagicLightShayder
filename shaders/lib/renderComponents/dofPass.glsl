#version 430 compatibility
#include "/lib/settings.glsl"
#define LEVEL (DOF_PASSES-(PASS)-1)
const int d = 1<<LEVEL;
const int DOF_SAMPLE_RAD = DOF_RAD>>(DOF_PASSES-1);

uniform float viewWidth, viewHeight;

// cost is  O(n^2) rad, O((4^n)/(5-n)) quality


#if PASS == -1
    uniform sampler2D depthtex1, depthtex2;
    uniform float centerDepthSmooth;
    uniform mat4 gbufferProjectionInverse;

    #include "/lib/util/conversions.glsl"

    /* RENDERTARGETS: 12 */
    layout(location=0) out vec2 CoCbuff;

    float calcRadius(ivec2 texpos){
        if(texelFetch(depthtex1,texpos,0).x!=texelFetch(depthtex2,texpos,0).x){
            return 0;
        }
        float depth = depthToLinear(texelFetch(depthtex2,texpos,0).x);
        float depthTarget = depthToLinear(centerDepthSmooth);

        const float focalLength = DOF_FOCAL_LENGTH*1e-3;

        float rad = abs(depth-depthTarget)/depth * (focalLength)/max(0.1,depthTarget-focalLength);

        rad = clamp(abs(rad),0,1);
        rad*=viewHeight;
        return clamp(rad,0,DOF_RAD);
    }
#else
    uniform sampler2D colortex0, colortex12;

    #if LEVEL>0
        /* RENDERTARGETS: 0,12 */
        layout(location=1) out vec2 CoCbuff;
    #else
        /* RENDERTARGETS: 0 */
        vec2 CoCbuff;
    #endif
    layout(location=0) out vec3 colorOut;
#endif



in vec2 texcoord;



float weightAtOffset(float rad,float len, int d){
    if(len==0)
        return 1;

    if(d>1){ //keeps things approximately uniform
        float lenDif = len+len-DOF_SAMPLE_RAD;
        if(len>rad || lenDif<0)
            return 0;
        return clamp(0.0001*lenDif*lenDif+0.01*(rad-len),1e-3,1e2);
    }
    return clamp(d*(rad-len)/(rad+3), 0, 1);
}



void main() {
    ivec2 texpos = ivec2(floor(texcoord*vec2(viewWidth,viewHeight)));
    float nextTotalWeight = 0;

#if PASS>=0
    ivec2 offsetTexpos;
    colorOut=vec3(0);
    CoCbuff.y = texelFetch(colortex12,texpos,0).y;

    #if DOF_ANTIBLEED != -1
        float centerRadInv = 1.0/(max(0.1,CoCbuff.y)*DOF_ANTIBLEED);
        const float antibleedBias = 1+1.0/DOF_ANTIBLEED;
    #endif

    #define MIN_Y -DOF_SAMPLE_RAD
#else
    CoCbuff.y=calcRadius(texpos);
    #define MIN_Y 1
#endif
    float maxrad = CoCbuff.y/d;
    #if DOF_ANTIBLEED != -1
        maxrad*=DOF_ANTIBLEED;
    #else
        maxrad*=4;
    #endif
    maxrad = min(DOF_SAMPLE_RAD,maxrad);
    maxrad*=maxrad;

    for(int y=MIN_Y; y<=DOF_SAMPLE_RAD; y++){
       #if LEVEL>0
        if(y>=1){
            for(int x=0;x<=y;x++){
                float len = length(ivec2(x,y));
                if(len>DOF_SAMPLE_RAD) continue;
                len*=d;
                float weight = weightAtOffset(CoCbuff.y,len*0.5,d>>1);
                nextTotalWeight+=(x==0 || x==y)?weight:(weight+weight);
            }
        }
       #endif

       #if PASS>=0

        offsetTexpos.y=texpos.y+(y<<LEVEL);
        if(offsetTexpos.y<0)
            continue;
        if(offsetTexpos.y>viewHeight)
            continue;

        int xrange = int(floor(sqrt(maxrad-y*y)));
        for(int x=-xrange; x<=xrange; x++){
            float len = length(ivec2(x,y)<<LEVEL);
            offsetTexpos.x=texpos.x+(x<<LEVEL);

            vec2 blurMeta = texelFetch(colortex12,offsetTexpos,0).xy;

            float weight = weightAtOffset(blurMeta.y,len,d);

        #if DOF_ANTIBLEED != -1
            weight*=clamp(antibleedBias-blurMeta.y*centerRadInv,0,1);
        #endif
            if(weight<=1e-3)continue;

            colorOut += texelFetch(colortex0,offsetTexpos,0).rgb*(weight/blurMeta.x);
        }
       #endif
    }

    CoCbuff.x = nextTotalWeight*4+1;
}