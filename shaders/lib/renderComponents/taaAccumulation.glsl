#include "/lib/settings.glsl"

uniform int frameCounter;
uniform vec2 scaledScreenDim;
uniform float viewWidth,viewHeight;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection, gbufferPreviousModelView;
uniform vec3 cameraPosition, previousCameraPosition;

uniform sampler2D depthtex1;
//uniform sampler2D depthtex2;

#include "/lib/util/taaHelper.glsl"
#include "/lib/renderComponents/blur.glsl"

#if VOLUMETRIC_FOG_SAMPLES == 0
    #undef TAA_FOG
#endif

#ifdef TAA_FOG
layout(location = 2) out vec4 addAccumulation;
uniform sampler2D colortex11;
uniform sampler2D colortex7;
/* RENDERTARGETS: 9,10,11*/
#else
/* RENDERTARGETS: 9,10*/
#endif

uniform sampler2D colortex6;
uniform sampler2D colortex9;
uniform sampler2D colortex10;
uniform sampler2D depthtex0;

layout(location = 0) out float depthAccumulation;
layout(location = 1) out vec3 multAccumulation;

void taaAccumulate(){
    vec2 jitteredTexcoord = texcoord-jitter();
    ivec2 jitteredTexPos = ivec2(scaledScreenDim*jitteredTexcoord);

#ifdef TAA_FOG
    #ifdef TAA_HQ_BLUR
    addAccumulation = doFogBlur(colortex7,jitteredTexcoord,1);
    #else

    const bool colortex7MipmapEnabled = true;
    addAccumulation = texture(colortex7,jitteredTexcoord,FOG_BLUR);
    #endif
    #ifdef TAA_FOG
    #endif
#endif
    multAccumulation = texelFetch(colortex6,jitteredTexPos,0).rgb;

   #if DEBUG_SPECIAL_VIEW == 201
    multAccumulation=vec3(1,0,0);
   #endif

    bool reprojectValid = false;


    depthAccumulation = texelFetch(depthtex0,ivec2(gl_FragCoord.xy),0).x;
    vec3 screenPos = vec3(texcoord,depthAccumulation);

    vec4 previousAddAccumulation = vec4(0);
    vec3 previousMultAccumulation = vec3(0);
    vec3 prevScreenPos = reproject(screenPos);

    if(prevScreenPos.x>=0 && prevScreenPos.y>=0 && prevScreenPos.x<=1 && prevScreenPos.y<=1){
        ivec2 prevScreenTexpos = ivec2(prevScreenPos.xy*vec2(viewWidth,viewHeight));
        float prevDepth = texelFetch(colortex9,prevScreenTexpos,0).x;


        const float depthSensitivity = exp2(-16);
        if(abs(screenPos.z-prevDepth)<=depthSensitivity){
            previousMultAccumulation = texelFetch(colortex10,prevScreenTexpos,0).rgb;
           #if DEBUG_SPECIAL_VIEW == 201
            previousMultAccumulation=vec3(0,1,0);
           #endif
            multAccumulation=mix(previousMultAccumulation, multAccumulation, lightSampleWeight(jitteredTexcoord));

           #ifdef TAA_FOG
            previousAddAccumulation = texelFetch(colortex11,prevScreenTexpos,0);
            addAccumulation =mix(previousAddAccumulation, addAccumulation, fogSampleWeight(jitteredTexcoord));
           #endif
        }
    }




#if DEBUG_SPECIAL_VIEW == 200
    float weight = lightSampleWeight(jitteredTexcoord);

    ivec2 jitteredTexpos = ivec2(floor((jitteredTexcoord)*scaledScreenDim));

    multAccumulation = texelFetch(colortex6,jitteredTexpos,0).rgb;
    multAccumulation.xyz=mix(multAccumulation,vec3(weight), weight>=0.95?0.5:0.2);
#elif DEBUG_SPECIAL_VIEW == 202
    float weight = lightSampleWeight(jitteredTexcoord);
    multAccumulation = vec3(lightSampleWeight(jitteredTexcoord));
#endif
}