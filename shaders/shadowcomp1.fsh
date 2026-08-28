#version 430 compatibility
#include "/lib/settings.glsl"

in vec2 texcoord;

uniform sampler2D shadowtex0;
layout(location=0) out float depth;

vec2 getLevelCenter(int level){
    return (vec2(level/3,level%3)+0.5)/3.0;
}
float getLevelScale(int level){
    return float(1<<level);
}
uniform int frameCounter;

void main(){
    #ifdef CASCADED_SHADOWS
    ivec2 cascadePos = ivec2(texcoord*3);
    int level = cascadePos.y+3*cascadePos.x;
    if(level>MAX_SHADOW_CASCADE)
        discard;
    #endif

    depth=texture(shadowtex0,texcoord,0).x;

    #ifdef CASCADED_SHADOWS
    vec2 relativeTC = (texcoord-getLevelCenter(level));

    float distFromCenter =  max(abs(relativeTC.x),abs(relativeTC.y));

    if(level > 0 && ((distFromCenter > 0.25/3.0) || (level==MAX_SHADOW_CASCADE))){
        //at the outer edges, sample from lower level
        vec4 samples = textureGather(shadowtex0,relativeTC*0.5+getLevelCenter(level-1));
        int numSamples = int(samples.x<1.0)+int(samples.y<1.0)+int(samples.z<1.0)+int(samples.w<1.0);
        samples=fract(samples);


        if(numSamples>0){
            float newDepth = ((samples.x+samples.y)+(samples.z+samples.w))/numSamples;
            if(newDepth<=depth)
                depth=newDepth;
        }

    }else if(level<MAX_SHADOW_CASCADE && distFromCenter<=0.25/3.0){
        //at the inner edges, sample from higher level
        float newDepth = texture(shadowtex0,clamp(relativeTC*2,-0.48/3.0,0.48/3.0)+getLevelCenter(level+1)).x;
        depth=min(depth,newDepth);
    }
    #endif
}