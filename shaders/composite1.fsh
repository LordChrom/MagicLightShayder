#version 430 compatibility

in vec2 texcoord;

/* RENDERTARGETS: 5,3,4 */
layout(location = 0) out float solidDepthOut;
layout(location = 1) out vec4 translucentAlbedo;
layout(location = 2) out vec4 translucentNormals;

uniform sampler2D depthtex0;
uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

uniform sampler2D colortex3;
uniform sampler2D colortex4;

uniform sampler2D colortex5;

void main(){
    ivec2 texpos = ivec2(gl_FragCoord.xy);
    float d0 = texelFetch(depthtex0,texpos,0).x;
    float d5 = texelFetch(colortex5,texpos,0).x;
    float d1 = texelFetch(depthtex1,texpos,0).x;
    float d2 = texelFetch(depthtex2,texpos,0).x;
    translucentAlbedo = texelFetch(colortex3,texpos,0);
    translucentNormals = texelFetch(colortex4,texpos,0);


    solidDepthOut = d2;
    if(d5>0){
        solidDepthOut=d5;
        if(d5<=d0){
            translucentAlbedo=vec4(0);
            translucentNormals=vec4(0);
        }
    }

    //least significant bit of the mantissa stores depth. The actual depth info represented there is essentially meaningless, and it doesnt affect anything not specifically checking it
    solidDepthOut=uintBitsToFloat(floatBitsToUint(solidDepthOut)&~1u);
    if(d2!=d1){
        solidDepthOut=fma(d0,1.0/MC_HAND_DEPTH,(0.5-0.5/MC_HAND_DEPTH));
        solidDepthOut=uintBitsToFloat(floatBitsToUint(solidDepthOut)|1u);
    }
}