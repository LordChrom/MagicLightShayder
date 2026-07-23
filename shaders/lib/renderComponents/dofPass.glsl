#version 430 compatibility
#include "/lib/settings.glsl"
#define LEVEL (OLDDOF_PASSES-(PASS)-1)
const int d = 1<<LEVEL;
const int OLDDOF_SAMPLE_RAD = OLDDOF_RAD>>(OLDDOF_PASSES-1);

uniform float viewHeight;

// cost is  O(n^2) rad, O((4^n)/(5-n)) quality


#if PASS == -1
    uniform sampler2D depthtex1, depthtex2;
    uniform float centerDepthSmooth;

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
        return clamp(rad,0,OLDDOF_RAD)*sign(depth-depthTarget);
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
    rad=abs(rad);
    if(len==0)
        return 1;

    float fuzzyUniform = clamp(4*d*(rad-len)/(rad+OLDDOF_RAD), 0, 1);
    if(d<=1 || (d>1&&len>rad))
        return fuzzyUniform;
    float lenDif = len+len-OLDDOF_SAMPLE_RAD;

    return fuzzyUniform*max(0.00000001,exp2(-2.4e-4*OLDDOF_PASSES*(rad-len)*lenDif)*1e0/d);
}

void main() {
    ivec2 texpos = ivec2(gl_FragCoord.xy);
    float nextTotalWeight = 0;

#if PASS>=0
    ivec2 offsetTexpos;
    colorOut=vec3(0);
    CoCbuff.y = texelFetch(colortex12,texpos,0).y;

    #define MIN_Y -OLDDOF_SAMPLE_RAD
#else
    CoCbuff.y=calcRadius(texpos);
    #define MIN_Y 1
#endif
    float maxrad = OLDDOF_SAMPLE_RAD;
    maxrad*=maxrad;

    float antibleedMult =  8e-2/(abs(CoCbuff.y)/d+1);
    float unobstructedSamples=0;
    float takenSamples=0;
    for(int y=MIN_Y; y<=OLDDOF_SAMPLE_RAD; y++){
       #if LEVEL>0
        if(y>=1){
            for(int x=0;x<=y;x++){
                float len = length(ivec2(x,y));
                if(len>OLDDOF_SAMPLE_RAD) continue;
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


            float antibleedMult2 = 8e-2/(abs(blurMeta.y)/d+1);

            const float antibleedAdd = 1.1;
            if(blurMeta.y>0)
                weight*=clamp(antibleedMult*(CoCbuff.y-blurMeta.y)+antibleedAdd,0,1);

            if(CoCbuff.y>0){
                takenSamples+=1;
                unobstructedSamples+=clamp(antibleedMult2*(blurMeta.y-CoCbuff.y)+antibleedAdd, 0, 1);
            }
            if(weight<=0)continue;


            colorOut += texelFetch(colortex0,offsetTexpos,0).rgb*(weight/blurMeta.x);
        }
       #endif
    }
    #if PASS>=0
    if(CoCbuff.y>0){
        colorOut*=takenSamples/unobstructedSamples;
    }
    #endif

    CoCbuff.x = nextTotalWeight*4+1;
}