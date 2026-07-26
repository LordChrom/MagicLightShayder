#if POM_MODE==2
    const float perfectRatio = 0.375;
    const int pomSamplesPix = int(round(POM_SAMPLES*perfectRatio));
    const int pomSamplesSparse = POM_SAMPLES-pomSamplesPix;
#else
    const int pomSamplesSparse = POM_SAMPLES;
    const int pomSamplesPix = POM_SAMPLES;
#endif

const float pomDepth = 0.25*POM_DEPTH_STRENGTH;
#define POM_WRAP_THRESHOLD 0.5

#if POM_ROUNDING_RAD!=-1
    #define POM_ROUNDED_EDGES
#endif

bool shouldWrap = false;
#ifdef POM_NORMALS
ivec2 pomEdgeDif=ivec2(0);
#else
    #undef POM_ROUNDED_EDGES
#endif


#ifdef POM_NORMALS
vec3 pomNormal=vec3(0,0,1);
#endif

void pomEdge(inout vec2 tc, float rayDepth){
    #ifdef POM_DISCARD
    if(tc.x<0 || tc.y<0 || tc.x>=texsize.x || tc.y>=texsize.y)
    discard;
    #endif

    tc = shouldWrap?
        tc= fract(tc/texsize)*texsize:
        tc= clamp(tc,vec2(0),texsize-1e-5);
}

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

        float pixDif = length(ivec2(lastTc)-texpos);
        if(pixDif>1 && pixDif<10){
            tc.x=(15*tc.x+lastTc.x)/16.0;
            rayDepth = (tc.x-initialTc.x)/differential.x;
        }
        #endif

        vec2 prePomTc = tc;
        pomEdge(tc,rayDepth);
        lastTc-=tc-prePomTc;
        float texdepth = float(1.0-texelFetch(normals,baseTexpos+ivec2(tc),0).a)*pomDepth;
        shouldWrap=texdepth>=pomDepth*POM_WRAP_THRESHOLD;

        #ifdef POM_NORMALS
        if(rayDepth>texdepth+tiny){
            pomEdgeDif = ivec2(tc)-ivec2(lastTc);
            break;
        }
        #endif

        vec2 depthTillPxEdge = (1-fract(tc*sign(differential)))/abs(differential);
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
        pomEdge(tc,rayDepth);
        #endif
        float depth = float(1.0-texelFetch(normals,(baseTexpos+ivec2(tc)),0).a)*pomDepth;
        shouldWrap=depth>=pomDepth*POM_WRAP_THRESHOLD;

        if(rayDepth+1e-4>=depth){
            break;
        }
    }
    return tc;
}

vec2 doPom(vec2 tc){
    if(dot(differential,differential)<1e-4)
        return tc;
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

    ivec2 retTexpos = ivec2(ret)+baseTexpos;

    #if (defined POM_WRITE_DEPTH) || (defined POM_ROUNDED_EDGES)
    float texDepth = float(1.0-texelFetch(normals,retTexpos,0).a)*pomDepth;
    #endif

    #ifdef POM_ROUNDED_EDGES

    float texMaxSize = max(texsize.x,texsize.y);
    if(pomEdgeDif.xy!=ivec2(0)){
        pomNormal.xy=(fract(ret)-0.5)*2;
        pomNormal.z=max((1-(rayDepth-texDepth)*2*texMaxSize),0);
    }else{
        pomNormal.xy=(fract(initialTc+differential*texDepth)-0.5)*2;
        float m = max(abs(pomNormal.x),abs(pomNormal.y));
        pomNormal.z=1;
    }

    float pomRoundingRatio = min((float(POM_ROUNDING_RAD)/50.0)*texMaxSize,1.0);

    pomNormal=sign(pomNormal)*max(abs(pomNormal)-(1-(pomRoundingRatio)),0)/pomRoundingRatio;

    #if 1
    if(float(1.0-texelFetch(normals,ivec2(retTexpos.x+int(sign(pomNormal.x)),retTexpos.y),0).a)*pomDepth<=texDepth)
        pomNormal.x=0;

    if(float(1.0-texelFetch(normals,ivec2(retTexpos.x,retTexpos.y+int(sign(pomNormal.y))),0).a)*pomDepth<=texDepth)
        pomNormal.y=0;
    #endif

    #endif

    #ifdef POM_WRITE_DEPTH
    rayDepth = texDepth;
    #endif

    #ifdef POM_NORMALS
    if(length(pomEdgeDif)>1)
        pomEdgeDif=ivec2(0);
    #ifdef POM_ROUNDED_EDGES
    pomNormal = normalize(pomNormal);

    #else
    pomEdgeDif=ivec2(sign(differential))*-abs(pomEdgeDif);
    pomNormal = vec3(
        pomEdgeDif,float(pomEdgeDif==ivec2(0))
    );
    #endif

    #endif

    return (0.5+vec2(retTexpos))/atlasSize;

}