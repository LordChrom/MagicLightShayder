#include "/lib/settings.glsl"
uniform int frameCounter;
uniform vec2 scaledScreenDim;
uniform float viewWidth,viewHeight;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection, gbufferPreviousModelView;
uniform vec3 cameraPosition, previousCameraPosition;

uniform sampler2D depthtex1;
uniform sampler2D depthtex2;

#include "/lib/util/taaHelper.glsl"
#include "/lib/renderComponents/blur.glsl"

#if VOLUMETRIC_FOG_SAMPLES == 0
    #undef TAA_FOG
#endif

#ifdef TAA_FOG
layout(location = 1) out vec4 addAccumulation;
uniform sampler2D colortex11;
uniform sampler2D colortex7;
/* RENDERTARGETS: 10,11*/
#else
/* RENDERTARGETS: 10*/
#endif

uniform sampler2D colortex6;
uniform sampler2D colortex10;
uniform sampler2D depthtex0;
#ifdef TAA_BETTER_REJECTION
uniform sampler2D colortex2;
#endif

layout(location = 0) out vec4 multAccumulation;

void taaAccumulate(){
    vec2 screenDim = vec2(viewWidth,viewHeight);

    vec2 jitteredTexcoord = texcoord-jitter();

#ifdef TAA_FOG
    vec4 addContribution = cheapBlur(colortex7,jitteredTexcoord,1);
#endif
    vec3 multContribution = cheapBlur(colortex6,jitteredTexcoord,LIGHTING_RENDERSCALE).rgb;

    bool reprojectValid = false;
    vec3 screenPos = vec3(texcoord,0);
#ifdef TAA_BETTER_REJECTION

    float normalsAndMoreA = texelFetch(colortex2,ivec2(floor(screenDim*texcoord)),0).a;
    bool isHand = 0.4<normalsAndMoreA && normalsAndMoreA<0.6;

    float depth;
    if(normalsAndMoreA>0.4)
        depth = screenPos.z = texture(depthtex0,screenPos.xy,0).x;
    else
        depth = screenPos.z = texture(depthtex2,screenPos.xy,0).x;

#else
    float depth = screenPos.z = texture(depthtex0,screenPos.xy,0).x;
    bool isHand = depth<0.56;
#endif


    vec4 previousMultAccumulation = vec4(0);
#ifdef TAA_FOG
    vec4 previousAddAccumulation = vec4(0);
#endif
    vec3 prevScreenPos = reproject(screenPos);

    if(prevScreenPos.x>=0 && prevScreenPos.y>=0 && prevScreenPos.x<=1 && prevScreenPos.y<=1){
        previousMultAccumulation = texture(colortex10,prevScreenPos.xy);
#ifdef TAA_FOG
        previousAddAccumulation = texture(colortex11,prevScreenPos.xy);
#endif
        prevScreenPos.z = previousMultAccumulation.a;
        float len = length(screenPos);
        float prevLen = length(prevScreenPos);

        reprojectValid = (!isHand) && (abs(len-prevLen)/len<0.01);
    }

    float weight = reprojectValid?lightSampleWeight(jitteredTexcoord):1;
    multAccumulation=vec4(mix(previousMultAccumulation.xyz,multContribution,weight),isHand?100:depth);
#ifdef TAA_FOG
    float fogWeight = reprojectValid?fogSampleWeight(jitteredTexcoord):1;
    addAccumulation =mix(previousAddAccumulation, addContribution,fogWeight);
#endif


#if DEBUG_SPECIAL_VIEW == 200
    ivec2 jitteredTexpos = ivec2(floor((jitteredTexcoord)*scaledScreenDim));

    multContribution = texelFetch(colortex6,jitteredTexpos,0).rgb;
    multAccumulation.xyz=mix(multContribution,vec3(weight),
        weight>=0.95?0.5:0.2);
#elif DEBUG_SPECIAL_VIEW == 201
    multAccumulation.xyz=mix(multAccumulation.xyz,vec3(0,0.3*float(reprojectValid),0),0.1);
#endif
}