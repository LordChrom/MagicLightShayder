#include "/lib/settings.glsl"
#include "/lib/util/conversions.glsl"


vec4 multifetch(sampler2D texToBlur, vec2 texCoord, vec2 screenDisplacement, float centerDepth, bool depthAware, out int weight){
    weight=0;
    vec4 ret;
    const float mul = exp(- (FOG_BLUR_EDGE_REJECTION));
    float maxDepthDif = clamp(centerDepth*centerDepth*mul,0.1,1000);

    for(int swiz=0; swiz<=1;swiz++){
        vec2 offset = (bool(swiz)?screenDisplacement:vec2(screenDisplacement.y,-screenDisplacement.x))/scaledScreenDim;
        for(int sign=-1; sign<=1;sign+=2){
            vec2 coord = texCoord+sign*offset;
            if(depthAware){
                float depth = depthToLinear(texture(depthtex1, coord).x);
                if (abs(depth-centerDepth)>maxDepthDif){
                    #ifdef DEBUG_FOG_BLUR_EDGES
                        ret.r++;
                    #endif
                    continue;
                }
            }

            weight++;
            ret+=texture(texToBlur,coord);
        }
    }

    return ret;
}

vec4 doBlur(sampler2D texToBlur, vec2 pos, float pxStep, float weightCenter, float weightEdges, float weightCorners, bool depthAware){
    int we,wc;
    float centerDepth = depthToLinear(texture(depthtex1,pos).x);
    vec4 edges = multifetch(texToBlur,pos,vec2(pxStep,0),centerDepth,depthAware,we)*weightEdges;
    vec4 corners = multifetch(texToBlur,pos,vec2(pxStep),centerDepth,depthAware,wc)*weightCorners;
    vec4 center = texture(texToBlur,pos);
    weightEdges*=we;
    weightCorners*=wc;

    return (edges + corners + weightCenter*center)/(weightEdges+weightCorners +weightCenter);
}


vec4 doFogBlur(sampler2D texToBlur, vec2 pos, int level){
#define FOG_BLUR_WIDTH 1.5
#if FOG_BLUR_EDGE_REJECTION == -1
    bool depthAware = false;
#else
    bool depthAware = true;
#endif
    return doBlur(texToBlur, pos,(level*FOG_BLUR_WIDTH),1,0.75,0.5,depthAware);
}

vec4 doBloom(sampler2D texToBlur, vec2 pos, int level){
    float bloomLevelWidth = level*BLOOM_WIDTH;
    return doBlur(texToBlur, pos,(bloomLevelWidth),2/BLOOM_INTENSITY,0.5,0.25,false);
}

vec4 cheapBlur(sampler2D texToBlur, vec2 pos, float strength){
    pos = mix(pos,round(pos*scaledScreenDim+0.5)/scaledScreenDim,strength);
    return texture(texToBlur,pos);
}