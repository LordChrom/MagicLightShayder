const float pomDepth = 0.25*POM_DEPTH_STRENGTH;
#ifdef POM_NORMALS
ivec2 pomEdgeDif=ivec2(0);
#endif

void pomEdge(inout vec2 tc){
    #ifdef POM_DISCARD
    if(tc.x<0 || tc.y<0 || tc.x>=texsize.x || tc.y>=texsize.y)
    discard;
    #endif

    #ifdef POM_WRAP
    tc= fract(tc/texsize)*texsize;
    #else
    tc= clamp(tc,vec2(0),texsize-1e-5);
    #endif
}

uniform int frameCounter;
#define POM_PERFECT_EDGES

vec2 doPixPom(vec2 initialTc){
    float tiny = exp2(-22)*max(texsize.x,texsize.y);
    vec2 tc = initialTc;

    for(int i = 0; i<pomSamplesPix; i++){
        #if defined POM_PERFECT_EDGES || defined POM_NORMALS
        vec2 lastTc = tc;
        if(i==0)
            lastTc +=differential*rayDepth;
        #endif

        rayDepth+=tiny;
        tc =initialTc+differential*rayDepth;

        ivec2 texpos = ivec2(tc);
        #ifdef POM_PERFECT_EDGES
        if(length(ivec2(lastTc)-texpos)>1){
            tc.x=(15*tc.x+lastTc.x)/16.0;
            rayDepth = (tc.x-initialTc.x)/differential.x;
        }
        #endif

        pomEdge(tc);
        float texdepth = float(1.0-texelFetch(normals,baseTexpos+ivec2(tc),0).a)*pomDepth;
        vec2 depthTillPxEdge = (1-fract(tc*sign(differential)))/abs(differential);

        #ifdef POM_NORMALS
        if(rayDepth>texdepth+tiny){
            pomEdgeDif = ivec2(tc)-ivec2(lastTc);
            break;
        }
        #endif

        rayDepth+=min(depthTillPxEdge.x,depthTillPxEdge.y);
        if(rayDepth> texdepth){
            break;
        }

    }
    return tc;
}
vec2 doSparsePom(vec2 initialTc){
    vec2 tc;
    for(int i = 0; i<pomSamplesSparse; i++){
        rayDepth = i*(pomDepth/pomSamplesSparse);
        tc =initialTc+differential*rayDepth;
        #if POM_MODE==2
        vec2 c = clamp(tc,vec2(0),texsize);
        if(c!=tc){
            tc=c;
            break;
        }
        #else
        pomEdge(tc);
        #endif
        float depth = float(1.0-texelFetch(normals,(baseTexpos+ivec2(tc)),0).a)*pomDepth;

        if(rayDepth+1e-4>=depth){
            break;
        }
    }
    return tc;
}

vec2 doPom(vec2 tc){
    vec2 initialTc = tc*atlasSize-baseTexpos;
    vec2 ret;

    #if POM_MODE==0
    ret = doSparsePom(initialTc);
    #elif POM_MODE==1
    ret= doPixPom(initialTc);
    #else
    doSparsePom(initialTc);
    float maxDepthDif = ((pomSamplesPix-2)/(ceil(abs(differential.x))+ceil(abs(differential.y))));
    rayDepth=max(0,rayDepth-maxDepthDif);

    ret= doPixPom(initialTc);
    #endif

    #ifdef POM_WRITE_DEPTH
    rayDepth = float(1.0-texelFetch(normals,(baseTexpos+ivec2(ret)),0).a)*pomDepth;
    #endif
    return (baseTexpos+(0.5+floor(ret)))/atlasSize;

}
uniform mat4 gbufferProjectionInverse;
#include "/lib/util/conversions.glsl"