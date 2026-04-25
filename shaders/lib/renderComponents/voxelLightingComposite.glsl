#include "/lib/settings.glsl"

uniform float viewWidth, viewHeight;
uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform mat4 gbufferPreviousProjection,  gbufferPreviousModelView;
uniform vec3 cameraPosition, previousCameraPosition;
uniform vec2 scaledScreenDim;

#include "/lib/voxel/voxelSampler.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/taaHelper.glsl"

uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;

#ifdef SSAO
uniform mat4 gbufferModelView;
#include "/lib/renderComponents/ssao.glsl"
#endif

#if MATERIALS_TYPE >= 0
uniform usampler2D colortex3;
uniform usampler2D colortex4;
#endif

#if DEBUG_SPECIAL_VIEW == 0
uniform sampler2D colortex0;
#elif DEBUG_SPECIAL_VIEW == 1
uniform sampler2D colortex1;
#elif DEBUG_SPECIAL_VIEW == 5
uniform sampler2D colortex5;
#elif (DEBUG_SPECIAL_VIEW == 10)  || (DEBUG_SPECIAL_VIEW == 200)
uniform sampler2D colortex10;
#elif DEBUG_SPECIAL_VIEW == 11
uniform sampler2D colortex11;
#endif

#if VOLUMETRIC_FOG_SAMPLES > 0
uniform vec3 fogColor;
#endif


layout(location = 2) out vec3 funnyDebug;

vec3 voxelLighting;
vec4 voxelFog;

void doVoxelLighting(vec2 sampleTexCoord,vec2 screenDims) {
    ivec2 texpos = ivec2(floor(vec2(sampleTexCoord)*scaledScreenDim-0.01));
    float ditherValue = dither(texpos);

#ifdef TAA
    sampleTexCoord+=jitter();
#endif
    ivec2 sourceTexpos = ivec2(floor(vec2(sampleTexCoord)*screenDims-0.01));




#if 1
    float solidDepth = texelFetch(depthtex2,sourceTexpos,0).x;
    vec4 normalAndMore = texelFetch(colortex2,sourceTexpos,0);
    float depth = texelFetch(depthtex0,sourceTexpos,0).x;
#else
    float solidDepth = texture(depthtex2,sampleTexCoord).x;
    vec4 normalAndMore = texture(colortex2,sampleTexCoord);
    float depth = texture(depthtex0,sampleTexCoord).x;
#endif

    vec3 normal = normalize(normalAndMore.xyz*2-1);

    bool isHand = normalAndMore.a>0.4 && normalAndMore.a<0.6;
    vec3 ndcPos = vec3(vec3(sampleTexCoord,solidDepth)*2-1);
    if(isHand){
        ndcPos.z=depth/MC_HAND_DEPTH;
    }

    float subsurface = 0;
    float emissive = 0;
#if MATERIALS_TYPE >= 0
    //TODO transparent materials info
    uvec4 matInfo = uvec4(0);

    if(!isHand){
        matInfo = texelFetch(colortex4 ,sourceTexpos ,0);
        if((matInfo.a==255) || matInfo==uvec4(0))
            matInfo = texelFetch(colortex3, sourceTexpos, 0);
    }

    subsurface = clamp(float(matInfo.b-64)/190.0, 0.0,1.0);
    if(matInfo.a!=255)
        emissive = (matInfo.a/254.0); //TODO maybe selective based on lightness of pixels
#endif

    vec4 viewPos = gbufferProjectionInverse*vec4(ndcPos,1);
    viewPos/=viewPos.w;

    vec3 worldPosRelative = (gbufferModelViewInverse*viewPos).xyz;
    vec3 worldPos = worldPosRelative+cameraPosition;

    bool isSky = depth==1;

    voxelLighting = vec3(0);
    if(!isSky)
        voxelLighting = mix(voxelSample(worldPos,normal,subsurface,ditherValue),vec3(EMISSIVE_BRIGHTNESS),emissive);

    #ifdef SSAO
    float ssao;
    if(emissive==0 && !isHand && !isSky){
        vec2 worldNormalDir = (gbufferModelView*vec4(normal, 0)).xy;
//        worldNormalDir=normalize(worldNormalDir);
        ssao = doSsao(sampleTexCoord, worldNormalDir, solidDepth, ditherValue);
        voxelLighting*=ssao;
    }
    #endif

#if VOLUMETRIC_FOG_SAMPLES > 0
    const float maxFogDepth = min(MAX_FOG_DEPTH,MIN_SCALE*0.5*AREA_SIZE*(1<<NUM_CASCADES));
    const float fogSampleLen = 1.0/VOLUMETRIC_FOG_SAMPLES;
    const float fogDensityMult = FOG_THICKNESS*log(0.5)/FOG_HALF_LIFE;

    if(length(worldPosRelative)>maxFogDepth || isSky){
        worldPosRelative*=maxFogDepth/length(worldPosRelative);
    }


    #ifdef FOG_TEMPORAL_NOISE
    ditherValue = temporalNoise(ditherValue);
    #endif
    float ditherValue2 = fract(ditherValue*-13+1.3);

    voxelFog = vec4(0,0,0,1);
    float hitDistance = length(worldPosRelative);
    float previousExp = exp(fogDensityMult*hitDistance);


    for(int i=0; i<VOLUMETRIC_FOG_SAMPLES; i++){
        //TODO better fog amount calc, and fix the banding, maybe smarter spacing
        float weight = 1-(float(i)+ditherValue)*fogSampleLen;
        vec3 fogSamplePos = cameraPosition +worldPosRelative*weight;
        vec3 newSample = voxelSampleFog(fogSamplePos,ditherValue2*0,ditherValue);

        float fogExp = (i==VOLUMETRIC_FOG_SAMPLES-1)? 1 : exp(fogDensityMult*hitDistance*weight);

        voxelFog *= previousExp/fogExp;
        voxelFog.rgb += newSample*(fogExp-previousExp);
        previousExp=fogExp;
    }

    vec3 fogCol = max(fogColor,0.01);
    fogCol=fogCol*(FOG_BIOME_TINT_STRENGTH/length(fogCol)) + (1-FOG_BIOME_TINT_STRENGTH);
    voxelFog.rgb*=fogCol.rgb;



#endif



#if DEBUG_SPECIAL_VIEW == 0
    funnyDebug=texture(colortex0,sampleTexCoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 1
    funnyDebug=texture(colortex1,sampleTexCoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 2
    float debugCheckerScale = 7;
    bool checker = bool((int(texpos.x/debugCheckerScale)^int(texpos.y/debugCheckerScale))&1);
    vec3 mult = checker?vec3(1):sign(normal)*0.2+0.8;
    funnyDebug = abs(normal)*mult;
#elif DEBUG_SPECIAL_VIEW == 3
    uvec4 mat = texture(colortex3,sampleTexCoord);
    float funnyEmissive = (mat.a==255)?0.0:(mat.a/254.0);
        funnyDebug=funnyEmissive+mat.rgb*((1.0-funnyEmissive)/255.0);
//        funnyDebug=funnyEmissive*mat.rgb*(1.0/255.0);
#elif DEBUG_SPECIAL_VIEW == 4
    uvec4 mat = texture(colortex4,sampleTexCoord);
    funnyDebug=mat.rgb*(1.0/255.0);
    if(mat.a>0 && mat.a<255)
        funnyDebug=0.5+0.5*funnyDebug;
#elif DEBUG_SPECIAL_VIEW == 5
    funnyDebug=texture(colortex5,sampleTexCoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 6
    funnyDebug = voxelLighting.xyz;
#elif DEBUG_SPECIAL_VIEW == 7
    funnyDebug = voxelFog.xyz;
#elif (DEBUG_SPECIAL_VIEW == 10) || (DEBUG_SPECIAL_VIEW == 200)
    funnyDebug = texture(colortex10,sampleTexCoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 11
    funnyDebug = texture(colortex11,sampleTexCoord).rgb;
#elif DEBUG_SPECIAL_VIEW == 100
    funnyDebug = vec3(clamp(0.05*sqrt(length(worldPosRelative)),0,1),float(isHand)*0.1,float(isSky)*0.5);
#elif DEBUG_SPECIAL_VIEW == 101
    funnyDebug = vec3(ditherValue);
#elif DEBUG_SPECIAL_VIEW == 102
    funnyDebug = vec3((texpos.x^texpos.y)&4,(texpos.x^texpos.y)&2,(texpos.x^texpos.y)&1);
#elif (DEBUG_SPECIAL_VIEW == 103) && (defined SSAO)
    funnyDebug = vec3(ssao);
#endif
}