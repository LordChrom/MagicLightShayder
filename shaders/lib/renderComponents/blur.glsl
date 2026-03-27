#include "/lib/settings.glsl"



vec4 multifetch(sampler2D texToBlur, vec2 texCoord, vec2 screenDisplacement){
    vec4 t1,t2,t3,t4;
    t1 = texture(texToBlur,texCoord+screenDisplacement);
    t2 = texture(texToBlur,texCoord-screenDisplacement);
    t3 = texture(texToBlur,texCoord+vec2(-screenDisplacement.y,screenDisplacement.x));
    t4 = texture(texToBlur,texCoord+vec2(screenDisplacement.y,-screenDisplacement.x));
    return t1+t2+t3+t4;
}

vec4 doBlur(sampler2D texToBlur, vec2 pos, vec2 pxStep, float weightCenter, float weightEdges, float weightCorners){
    pxStep/=LIGHTING_RENDERSCALE;
    vec4 edges = multifetch(texToBlur,pos,vec2(pxStep.x,0));
    vec4 corners = multifetch(texToBlur,pos,pxStep);
    vec4 center = texture(texToBlur,pos);

    return (weightEdges*edges + weightCorners*corners + weightCenter*center)/(4*weightEdges+4*weightCorners +weightCenter);
}

vec4 multifetchSnapped(sampler2D texToBlur, ivec2 texCoord, ivec2 step){
    vec4 t1,t2,t3,t4;
    t1 = texelFetch(texToBlur,texCoord+step,0);
    t2 = texelFetch(texToBlur,texCoord-step,0);
    t3 = texelFetch(texToBlur,texCoord+ivec2(-step.y,step.x),0);
    t4 = texelFetch(texToBlur,texCoord+ivec2(step.y,-step.x),0);
    return t1+t2+t3+t4;
}


vec4 doBlurSnapped(sampler2D texToBlur, ivec2 texPos, int step, float weightCenter, float weightEdges, float weightCorners){

    vec4 edges = multifetchSnapped(texToBlur,texPos,ivec2(step,0));
    vec4 corners = multifetchSnapped(texToBlur,texPos,ivec2(step,step));
    vec4 center = texelFetch(texToBlur,texPos,0);

    return (weightEdges*edges + weightCorners*corners + weightCenter*center)/(4*weightEdges+4*weightCorners +weightCenter);
}

vec4 doFogBlur(sampler2D texToBlur, vec2 pos, vec2 screenDim, int level){
//#define FOG_BLUR_SNAPPED
#define FOG_BLUR_WIDTH 1.5

#ifdef FOG_BLUR_SNAPPED
    ivec2 texPos = ivec2(round(pos*screenDim*LIGHTING_RENDERSCALE-0.07));
    return doBlurSnapped(texToBlur, texPos,level,1,0.5,0.25);
#else
    return doBlur(texToBlur, pos,(level*FOG_BLUR_WIDTH)/screenDim,1,1,1);
#endif
}

vec4 doBloom(sampler2D texToBlur, vec2 pos, vec2 screenDim, int level){
//#define BLOOM_SNAPPED

#ifdef BLOOM_SNAPPED
    ivec2 texPos = ivec2(round(pos*screenDim*LIGHTING_RENDERSCALE-0.07));
    return doBlurSnapped(texToBlur, texPos,level,2/BLOOM_INTENSITY,0.5,0.25);
#else
    return doBlur(texToBlur, pos,(level*BLOOM_WIDTH)/screenDim,2/BLOOM_INTENSITY,0.5,0.25);
#endif
}
