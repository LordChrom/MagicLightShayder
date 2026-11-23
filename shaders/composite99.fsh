#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/util/conversions.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/blend.glsl"

uniform float frameTimeCounter;
uniform mat4 gbufferModelViewInverse, gbufferProjectionInverse;
uniform vec2 scaledScreenDim;
uniform vec3 cameraPosition;

uniform sampler2D shadowtex0;
uniform sampler2D shadowcolor0;

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex2;
uniform sampler2D colortex3;
uniform sampler2D colortex4;
uniform sampler2D colortex5;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform usampler2D colortex8;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform sampler2D colortex13;
uniform sampler2D colortex14;
uniform sampler2D colortex15;
uniform sampler2D colortex16;
uniform sampler2D colortex17;
uniform sampler2D colortex18;
uniform sampler2D colortex19;

#if DEBUG_SPECIAL_VIEW==107
#define SWRT_INCLUDE_TRACE
#endif

const uint swrtMaxSteps = SWRT_SIZE;
#include "/lib/lighting/swrt/swrtSampler.glsl"

/* RENDERTARGETS: 0 */
layout(location = 0) out vec3 outColor;

float visiblifyDepth(float scrnDepth){
    if(scrnDepth<=0)
        return 0;
    scrnDepth = 0.1*(log2(depthToLinear(scrnDepth)+0.5));
    return clamp(scrnDepth,0,1);
}

void main() {
    ivec2 outputSize = textureSize(colortex0,0);
    ivec2 texpos = ivec2(gl_FragCoord);

    texpos = (texpos)/DEBUG_ZOOM+(outputSize/2-outputSize/(2*DEBUG_ZOOM));

    vec2 texcoord = (vec2(texpos)+0.5)/outputSize;
    vec3 worldDir = normalize(mat3(gbufferModelViewInverse)*(
        gbufferProjectionInverse[3].xyz+(mat2x3(gbufferProjectionInverse)*(texcoord*2-1))
    ));

#if DEBUG_SPECIAL_VIEW == 0
    outColor=texture(colortex0,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 1
    outColor=texture(colortex1,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 2
    outColor=texture(colortex2,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 3
    vec4 transColor = texture(colortex3,texcoord);
    outColor = mix(vec3(texcoord,1),vec3(1),0.5);
    outColor = mixInTranslucent(outColor,transColor);
#elif DEBUG_SPECIAL_VIEW == 4
    outColor= texture(colortex4,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 5
    vec2 depths = texture(colortex5,texcoord).xy;
    if(depths.y>=depths.x && depths.y<1)
        depths.y=0;

    outColor = vec3(
        depths.y>=1?0:2*visiblifyDepth(depths.y),
        depths.x>=1?0:visiblifyDepth(depths.x),
        depths.y>=1
    );

    if(bool(floatBitsToUint(depths.x)&1u)){ //is hand
//        outColor.rg*=10;
//        outColor.b=0.4;
    }

#elif DEBUG_SPECIAL_VIEW == 6
    outColor=texture(colortex6,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 7
    outColor=texture(colortex7,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 8
    uvec4 mat = texture(colortex8,texcoord);
    float funnyEmissive = (mat.a==255)?0.0:(mat.a/254.0);
    outColor=funnyEmissive+mat.rgb*((1.0-funnyEmissive)/255.0);
    //        outColor=funnyEmissive*mat.rgb*(1.0/255.0);
#elif DEBUG_SPECIAL_VIEW == 9
    vec2 theInfo = texture(colortex9,texcoord).rg;
//    float depth = .x;
//    outColor = vec3(visiblifyDepth(depth));
    outColor =theInfo.yyy;
#elif (DEBUG_SPECIAL_VIEW == 10) || (DEBUG_SPECIAL_VIEW >= 200 && DEBUG_SPECIAL_VIEW <= 202)
    outColor = texture(colortex10,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 11
    outColor = texture(colortex11,texcoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 100

#elif DEBUG_SPECIAL_VIEW == 101
    outColor = vec3(bayer128(texpos));
#elif DEBUG_SPECIAL_VIEW == 102
    outColor = vec3((texpos.x^texpos.y)&4,(texpos.x^texpos.y)&2,(texpos.x^texpos.y)&1);
#elif DEBUG_SPECIAL_VIEW == 107
    worldDir/=max(max(abs(worldDir.x),abs(worldDir.y)),abs(worldDir.z));
    worldDir*=VOXELSIZE_HALF-4;
    float depth = traceRay(cameraPosition,worldDir);

    if(depth<0)
    outColor=vec3(0.1,0.1,0.8);
    else{
        ivec3 areaPos = ivec3(floor(swrt_hitpos.xyz));
        outColor = vec3((log2(depth)+0.7f)*0.7/log2(SWRT_SIZE));

        #ifdef SWRT_TEXTURED
        vec4 texResult = swrtTextureSample();
        if(texResult.a<0.875){
            outColor.r=1;
        }else{
            outColor = texResult.rgb;
        }
        #endif


    }

    #if SWRT_TRANSLUCENCY>0
    outColor.rgb*=unpackSwrtTranslucency();
    #endif
#elif DEBUG_SPECIAL_VIEW == 108
    #if SWRT_LIGHTS_PER_BLOCK<=4
    const int gridSize = 2;
    #elif SWRT_LIGHTS_PER_BLOCK<=9
    const int gridSize = 3;
    #else
    const int gridSize = 4;
    #endif

    ivec2 texpos2 = texpos%(outputSize/gridSize);
    int index = ((texpos.x*gridSize)/outputSize.x)+ gridSize*((gridSize-1)-(texpos.y*gridSize)/outputSize.y);

    if(index<SWRT_LIGHTS_PER_BLOCK){
        texpos2.x=texpos2.x*SWRT_LIGHTS_PER_BLOCK + index;
        outColor = texelFetch(swrtRayHitSampler,texpos2,0).rgb;
    }else{
        outColor=vec3(0.1);
    }
#elif DEBUG_SPECIAL_VIEW == 203
    outColor=vec3(texture(shadowtex0,vec2(1-texcoord.y,texcoord.x)).rgb);
#elif DEBUG_SPECIAL_VIEW == 204
    outColor=vec3(texture(shadowcolor0,vec2(1-texcoord.y,texcoord.x)).r*2-0.8);
#else
    outColor = texelFetch(colortex19,texpos,0).xyz;
#endif


    float debugCheckerScale = 7;
    bool checker = bool((int(texpos.x/debugCheckerScale)^int(texpos.y/debugCheckerScale))&1);
    vec3 mult = checker?vec3(1):sign(outColor.xyz)*0.2+0.8;
    outColor=mult*abs(outColor);

#if DEBUG_ZOOM >=4
//    if(bool(6&texpos.x) && bool(6&texpos.y))
    if(bool(2&(texpos.x^texpos.y)))
        outColor+=(float(1&(texpos.x^texpos.y))-0.5)/32f;
#endif

    if(isnan(outColor.x+outColor.y+outColor.z)){
        outColor = (fract(frameTimeCounter*3)<0.5)?vec3(1,0,0):vec3(0,0,0);
    }
}