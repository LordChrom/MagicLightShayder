#version 430 compatibility

#define SIZE 16
const vec2 workGroupsRender = vec2(1.0,1.0);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba8) uniform writeonly restrict image2D colorimg1;
layout (rgba8) uniform writeonly restrict image2D colorimg3;
layout (rgba8) uniform writeonly restrict image2D colorimg4;
layout (rg32f) uniform writeonly restrict image2D colorimg5;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;
uniform sampler2D colortex1;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;

#ifdef VOXY
uniform sampler2D vxDepthTexOpaque,vxDepthTexTrans;
uniform mat4 vxProjInv;
#include "/lib/util/conversions.glsl"
#endif

#ifdef DISTANT_HORIZONS
uniform mat4 dhProjectionInverse;
uniform sampler2D dhDepthTex0;
uniform sampler2D dhDepthTex1;
#include "/lib/util/conversions.glsl"
#endif

const float almostOne = 0.9999996;
void main(){
    ivec2 texpos = ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy);
    float d2 = texelFetch(depthtex2,texpos,0).x;
    float d0 = texelFetch(depthtex0,texpos,0).x;
    vec2 dt5 = texelFetch(colortex5,texpos,0).xy;
    float d1 = texelFetch(depthtex1,texpos,0).x;
    vec4 transColor = texelFetch(colortex3,texpos,0);

    vec2 depthsOut = vec2(d2,d0);

#ifdef VOXY
    vec2 vxDepths;
    vxDepths.x = texelFetch(vxDepthTexOpaque,texpos,0).x;
    vxDepths.y = texelFetch(vxDepthTexTrans, texpos,0).x;
    bvec2 vxNotSky = bvec2(vxDepths.x<1.0,vxDepths.y<1.0);
    if(vxNotSky.x||vxNotSky.y){
        vxDepths = vxDepths*2.0-1.0;
        vxDepths = 1.0/(vxDepths*vxProjInv[2].w+ vxProjInv[3].w);
        vxDepths = depthsToBuf(vxDepths);
    }
    if(vxNotSky.x)
        depthsOut.x = min(depthsOut.x,min(vxDepths.x,almostOne));
    if(vxNotSky.y)
        depthsOut.y = min(depthsOut.y,min(vxDepths.y,almostOne));
#endif
#ifdef DISTANT_HORIZONS
    vec2 dhDepths;
    dhDepths.x = texelFetch(dhDepthTex1,texpos,0).x;
    dhDepths.y = texelFetch(dhDepthTex0,texpos,0).x;
    bvec2 dhNotSky = bvec2(dhDepths.x<1.0,dhDepths.y<1.0);
    if(dhNotSky.x||dhNotSky.y){
        dhDepths = dhDepths*2.0-1.0;
        dhDepths = 1.0/(dhDepths*dhProjectionInverse[2].w+ dhProjectionInverse[3].w);
        dhDepths = depthsToBuf(dhDepths);
    }
    if(dhNotSky.x && depthsOut.x>=1.0)
        depthsOut.x = min(depthsOut.x,min(dhDepths.x,almostOne));
    if(dhNotSky.y && depthsOut.y>=1.0)
        depthsOut.y = min(depthsOut.y,min(dhDepths.y,almostOne));
#endif


    float transNormalA = 0.0;
    vec3 solidAlbedo;
    bool transWrites = false; //:(

    dt5.x/=1-dt5.y;//corrects for the x getting multiplied by alpha of subsequent translucents

    if(dt5.x>0){
        transNormalA = texelFetch(colortex4,texpos,0).a;
        solidAlbedo = texelFetch(colortex1,texpos,0).rgb;
        depthsOut.x=dt5.x;
    }
    if(depthsOut.x<=depthsOut.y && (
        dt5.x>0.0
        #ifdef DISTANT_HORIZONS
        ||dhNotSky.y
        #endif
    )){ //solid trans in front, erase the evidence
        transWrites = true; // :)
        transColor = vec4(0);
        imageStore(colorimg4,texpos,vec4(0));
    }else if(d0<depthsOut.x){  //really translucent trans in front, save correct alpha value
        transWrites = true; // :)
        transColor.a=dt5.y;
    }


    //least significant bit of the mantissa stores depth. The actual depth info represented there is essentially meaningless, and it doesnt affect anything not specifically checking it
    depthsOut.x=uintBitsToFloat(floatBitsToUint(depthsOut.x)&~1u);

    //TODO translucent hand stuff
    if(d2!=d1)
    {
        depthsOut.x=fma(d0,1.0/MC_HAND_DEPTH,(0.5-0.5/MC_HAND_DEPTH));
        depthsOut.x=uintBitsToFloat(floatBitsToUint(depthsOut.x)|1u);
    }
    imageStore(colorimg5,texpos,vec4(depthsOut,0,0));

    if(transNormalA>=0.999) //end gateway
        imageStore(colorimg1,texpos,vec4(solidAlbedo,0));

    if(transWrites) //:)
        imageStore(colorimg3,texpos,transColor);
}