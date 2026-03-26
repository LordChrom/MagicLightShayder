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
    vec4 edges = multifetch(texToBlur,pos,vec2(pxStep.x,0));
    vec4 corners = multifetch(texToBlur,pos,pxStep);
    vec4 center = texture(texToBlur,pos);

    return (weightEdges*edges + weightCorners*corners + weightCenter*center)/(4*weightEdges+4*weightCorners +weightCenter);
}