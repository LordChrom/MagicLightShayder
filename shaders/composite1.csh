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

void main(){
    ivec2 texpos = ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy);
    float d2 = texelFetch(depthtex2,texpos,0).x;
    float d0 = texelFetch(depthtex0,texpos,0).x;
    float d5 = texelFetch(colortex5,texpos,0).x;
    float d1 = texelFetch(depthtex1,texpos,0).x;
    vec2 solidDepthOut = vec2(d2,d0);

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
        solidDepthOut.x = min(solidDepthOut.x,vxDepths.x);
    if(vxNotSky.y)
        solidDepthOut.y = min(solidDepthOut.y,vxDepths.y);
    #endif

    #ifdef DISTANT_HORIZONS
    vec2 dhDepths;
    dhDepths.x = texelFetch(dhDepthTex1,texpos,0).x;
    dhDepths.y = texelFetch(dhDepthTex0,texpos,0).x;
    bvec2 dhNotSky = bvec2(dhDepths.x<1.0 && solidDepthOut.x>=1.0,dhDepths.y<1.0 && solidDepthOut.y>=1.0);
    if(dhNotSky.x||dhNotSky.y){
        dhDepths = dhDepths*2.0-1.0;
        dhDepths = 1.0/(dhDepths*dhProjectionInverse[2].w+ dhProjectionInverse[3].w);
        dhDepths = depthsToBuf(dhDepths);
    }
    if(dhNotSky.x)
        solidDepthOut.x = min(solidDepthOut.x,dhDepths.x);
    if(dhNotSky.y)
        solidDepthOut.y = min(solidDepthOut.y,dhDepths.y);
    #endif

    if(d5>0){
        bool isEndGateway = bool(floatBitsToUint(d5)&1u);
        vec3 solidAlbedo;
        if(isEndGateway)
            solidAlbedo = texelFetch(colortex1,texpos,0).rgb;

        solidDepthOut.x=d5;
        if(d5<=d0){
            imageStore(colorimg3,texpos,vec4(0));
            imageStore(colorimg4,texpos,vec4(0));
        }

        if(isEndGateway)
            imageStore(colorimg1,texpos,vec4(solidAlbedo,0));
    }

    //least significant bit of the mantissa stores depth. The actual depth info represented there is essentially meaningless, and it doesnt affect anything not specifically checking it
    solidDepthOut.x=uintBitsToFloat(floatBitsToUint(solidDepthOut.x)&~1u);
    if(d2!=d1){
        solidDepthOut.x=fma(d0,1.0/MC_HAND_DEPTH,(0.5-0.5/MC_HAND_DEPTH));
        solidDepthOut.x=uintBitsToFloat(floatBitsToUint(solidDepthOut.x)|1u);
    }
    imageStore(colorimg5,texpos,vec4(solidDepthOut,0,0));
}