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


vec4 doFogBlur(sampler2D texToBlur, vec2 pos, int level){
    #define FOG_BLUR_WIDTH 1.5
    return doBlur(texToBlur, pos,(level*FOG_BLUR_WIDTH)/vec2(viewWidth,viewHeight),1,1,1);
}

vec4 doBloom(sampler2D texToBlur, vec2 pos, int level){
    float bloomLevelWidth = level*BLOOM_WIDTH;
    return doBlur(texToBlur, pos,(bloomLevelWidth)/vec2(viewWidth,viewHeight),2/BLOOM_INTENSITY,0.5,0.25);
}

vec4 cheapBlur(sampler2D texToBlur, vec2 pos, float strength){
    pos = mix(pos,round(pos*scaledScreenDim+0.5)/scaledScreenDim,strength);
    return texture(texToBlur,pos);
}