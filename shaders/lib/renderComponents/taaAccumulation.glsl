#include "/lib/settings.glsl"
uniform int frameCounter;
uniform vec2 scaledScreenDim;
uniform float viewWidth,viewHeight;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection, gbufferPreviousModelView;
uniform vec3 cameraPosition, previousCameraPosition;

#include "/lib/util/taaHelper.glsl"
#include "/lib/renderComponents/blur.glsl"


uniform sampler2D colortex2;
uniform sampler2D colortex6;
uniform sampler2D colortex7;
uniform sampler2D colortex10;
uniform sampler2D colortex11;

uniform sampler2D depthtex0;

/* RENDERTARGETS: 10,11*/

layout(location = 0) out vec4 multAccumulation;
layout(location = 1) out vec4 addAccumulation;

void taaAccumulate(){
    vec2 screenDim = vec2(viewWidth,viewHeight);

    vec2 jitteredTexcoord = texcoord-jitter();

    vec4 addContribution = cheapBlur(colortex7,jitteredTexcoord,1);
    vec3 multContribution = cheapBlur(colortex6,jitteredTexcoord,LIGHTING_RENDERSCALE).rgb;

    bool reprojectValid = false;
    vec3 screenPos = vec3(texcoord,0);
    float depth = screenPos.z = texture(depthtex0,screenPos.xy,0).x;

    float normalsAndMoreA = texture(colortex2,texcoord).a;
    bool isHand = normalsAndMoreA>0.4 && normalsAndMoreA<0.6;


    vec4 previousMultAccumulation = vec4(0);
    vec4 previousAddAccumulation = vec4(0);
    vec3 prevScreenPos = reproject(screenPos);

    if(prevScreenPos.x>=0 && prevScreenPos.y>=0 && prevScreenPos.x<=1 && prevScreenPos.y<=1){
        previousMultAccumulation = texture(colortex10,prevScreenPos.xy);
        previousAddAccumulation = texture(colortex11,prevScreenPos.xy);

        prevScreenPos.z = previousMultAccumulation.a;
        float len = length(screenPos);
        float prevLen = length(prevScreenPos);

        reprojectValid = (!isHand) && (abs(len-prevLen)/len<0.01);
    }

    float weight = reprojectValid?lightSampleWeight(jitteredTexcoord):1;
    multAccumulation=vec4(mix(previousMultAccumulation.xyz,multContribution,weight),isHand?100:depth);
    addAccumulation =mix(previousAddAccumulation, addContribution,weight);


#if DEBUG_SPECIAL_VIEW == 200
    ivec2 jitteredTexpos = ivec2(floor((jitteredTexcoord)*scaledScreenDim));

    multContribution = texelFetch(colortex6,jitteredTexpos,0).rgb;
    multAccumulation.xyz=mix(multContribution,vec3(weight),
        weight>=0.95?0.5:0.2);
#elif DEBUG_SPECIAL_VIEW == 201
    multAccumulation.xyz=mix(multAccumulation.xyz,vec3(0,0.3*float(reprojectValid),0),0.1);
#endif
}