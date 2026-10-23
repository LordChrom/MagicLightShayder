#include "/lib/settings.glsl"
#include "/lib/util/uniforms/frameCounter"

uniform vec2 scaledScreenDim;
uniform float viewWidth,viewHeight;
uniform float frameTime;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection, gbufferPreviousModelView;
uniform vec3 cameraPosition, previousCameraPosition;

uniform sampler2D colortex5;

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

layout(location = 0) out vec3 depthAndClampRange;
layout(location = 1) out vec4 multAccumulation;

uniform float frameTimeCounter;
void taaAccumulate(){
    float depth = texelFetch(colortex5,ivec2(gl_FragCoord.xy),0).x;
    vec2 jitteredTexcoord = texcoord;
    jitteredTexcoord-=unscaledJitter()/scaledScreenDim;
    multAccumulation = texelFetch(colortex6,ivec2(scaledScreenDim*jitteredTexcoord),0);

#ifdef TAA_FOG
    #ifdef TAA_HQ_BLUR
    addAccumulation = doFogBlur(colortex7,jitteredTexcoord,1);
    #else

    const bool colortex7MipmapEnabled = true;
    addAccumulation = texture(colortex7,jitteredTexcoord,FOG_BLUR);
    #endif
#endif

   #if DEBUG_SPECIAL_VIEW == 201
    multAccumulation=vec4(1,0,0,0);
   #endif

    bool reprojectValid = false;


    vec3 screenPos = vec3(texcoord,depth);

    vec4 previousAddAccumulation = vec4(0);
    vec4 previousMultAccumulation = vec4(0);
    vec3 prevScreenPos = reproject(screenPos);

    vec3 prevDepthAndBrightness = vec3(0);
    float brightness = max(max(multAccumulation.r, multAccumulation.g), multAccumulation.b);

    if(prevScreenPos.x>0 && prevScreenPos.y>0 && prevScreenPos.x<1 && prevScreenPos.y<1){
        prevDepthAndBrightness = texture(colortex9,prevScreenPos.xy).xyz;
        float var = fwidth(prevDepthAndBrightness.x);

        float speed = length(cameraPosition-previousCameraPosition);
        float speedFactor = clamp(TAA_MOTION_REJECTION*speed,1,2048);
        speedFactor=var>exp2(-14)?speedFactor:1;
        float depthSensitivity = exp2(-14)/speedFactor;
        if(abs(prevScreenPos.z-prevDepthAndBrightness.x)/prevDepthAndBrightness.x<=depthSensitivity){
            previousMultAccumulation = texture(colortex10, prevScreenPos.xy);

           #if DEBUG_SPECIAL_VIEW == 201
            previousMultAccumulation.rgb=vec3(0,1,0.35);
           #endif

            vec2 pixelShiftiness = (fract(prevScreenPos.xy*textureSize(colortex5,0))-0.5);
            pixelShiftiness = abs(2*pixelShiftiness);



            float decay = 0.1/frameTime;
            prevDepthAndBrightness.y=min(brightness,prevDepthAndBrightness.y+decay);
            prevDepthAndBrightness.z=max(brightness,prevDepthAndBrightness.z-decay);

            float prevBrightness = max(max(previousMultAccumulation.r,previousMultAccumulation.g), previousMultAccumulation.b);


            float historyReduction = 0;

            historyReduction = max(historyReduction,(prevBrightness-prevDepthAndBrightness.z-0.01)*0.4);
            historyReduction = max(historyReduction,(prevDepthAndBrightness.y-prevBrightness)*0.4);

            previousMultAccumulation.a/=historyReduction*TAA_RESPONSIVENESS+1;


            previousMultAccumulation.a*=clamp(1-(TAA_ANTI_SMEAR)*max(pixelShiftiness.x,pixelShiftiness.y),0,1);

            float weight = lightSampleWeight(jitteredTexcoord);

            multAccumulation.a=weight+previousMultAccumulation.a;
            float mixRatio = clamp(weight/multAccumulation.a,TAA_MIN_ACCUMULATION_RATE,TAA_MAX_ACCUMULATION_RATE);
            multAccumulation.rgb=mix(previousMultAccumulation.rgb, multAccumulation.rgb, mixRatio);

           #ifdef TAA_FOG
            mixRatio=1-((1-mixRatio)*(1-speed*3));
            mixRatio=clamp(mixRatio,0,1);
            previousAddAccumulation = texture(colortex11,prevScreenPos.xy);
            mixRatio*=fogSampleWeight(jitteredTexcoord);

            addAccumulation =mix(previousAddAccumulation, addAccumulation, mixRatio);
           #endif
        }
    }

//    prevDepthAndBrightness.y-=prevDepthAndBrightness.z*prevDepthAndBrightness.z*0.0001;
//    prevDepthAndBrightness.y-=0.004;
//    prevDepthAndBrightness.y = max(prevDepthAndBrightness.y,brightness);


    if(isnan(multAccumulation.x+multAccumulation.y+multAccumulation.z+multAccumulation.w))
        multAccumulation=vec4(0.0 );
    #ifdef TAA_FOG
    if(isnan(addAccumulation.x+addAccumulation.y+addAccumulation.z+addAccumulation.w))
        addAccumulation=vec4(0.0);
    #endif

#if DEBUG_SPECIAL_VIEW == 200
    float weight = lightSampleWeight(jitteredTexcoord);

    ivec2 jitteredTexpos = ivec2(floor((jitteredTexcoord)*scaledScreenDim));

    multAccumulation = texelFetch(colortex6,jitteredTexpos,0);
    multAccumulation = mix(multAccumulation,vec4(weight), weight>=0.95?0.5:0.2);
#elif DEBUG_SPECIAL_VIEW == 202
    float weight = lightSampleWeight(jitteredTexcoord);
    multAccumulation = vec4(lightSampleWeight(jitteredTexcoord));
#endif
    depthAndClampRange=vec3(depth,prevDepthAndBrightness.y,prevDepthAndBrightness.z);
}