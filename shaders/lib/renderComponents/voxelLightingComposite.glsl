#include "/lib/settings.glsl"

#include "/lib/voxel/voxelSampler.glsl"

#include "/lib/util/dither.glsl"

uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

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
#endif

#if VOLUMETRIC_FOG_SAMPLES > 0
uniform vec3 fogColor;
#endif


layout(location = 2) out vec3 funnyDebug;

vec3 voxelLighting;
vec4 voxelFog;

void doVoxelLighting(vec2 sampleTexCoord,vec2 screenDims) {
    ivec2 texpos = ivec2(round(vec2(sampleTexCoord)*screenDims*LIGHTING_RENDERSCALE-0.07));
    ivec2 sourceTexpos = ivec2(round(vec2(sampleTexCoord)*screenDims-0.07));

    float ditherValue = dither(texpos);
    float ditherValue2 = fract(ditherValue*7+0.3);

    float solidDepth = texelFetch(depthtex2,sourceTexpos,0).x;
    vec4 normalAndMore = texelFetch(colortex2,sourceTexpos,0);
    float depth = texelFetch(depthtex0,sourceTexpos,0).x;

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

    bool voxelLit = isVoxelInBounds(worldPos+normal*0.1) && !isSky;
    if(voxelLit)
        voxelLighting = voxelSample(worldPos,normal,subsurface)+emissive;
    else
        voxelLighting = vec3(0);

#if VOLUMETRIC_FOG_SAMPLES > 0
    voxelFog = vec4(0,0,0,1);

    if(length(worldPosRelative)>MAX_FOG_DEPTH || isSky){
        worldPosRelative*=MAX_FOG_DEPTH/length(worldPosRelative);
    }

    float hitDistance = length(worldPosRelative);
    float previousSampleDist = hitDistance;

    const float fogSampleLen = 1.0/VOLUMETRIC_FOG_SAMPLES;
    const float fogDensityMult = FOG_THICKNESS*log(0.5)/FOG_HALF_LIFE;

    for(int i=0; i<VOLUMETRIC_FOG_SAMPLES; i++){
        //TODO better fog amount calc, and fix the banding, maybe smarter spacing
        float weight = 1-(i+ditherValue)*fogSampleLen;
        vec3 fogSamplePos = cameraPosition +worldPosRelative*weight;
        if(!isVoxelInBounds(fogSamplePos))continue;

        float thisSampleDist = (weight)*hitDistance;
        float fogExperienced = exp(fogDensityMult * (previousSampleDist-thisSampleDist));
        previousSampleDist=thisSampleDist;



        vec4 newSample = vec4(voxelSampleFog(fogSamplePos,ditherValue2),0);
        vec3 fogCol = max(fogColor,0.01);
        fogCol/=length(fogCol);
        newSample.rgb=mix(newSample.rgb,fogCol*length(newSample.rgb),FOG_BIOME_TINT_STRENGTH);
        voxelFog = voxelFog*fogExperienced + newSample*(1-fogExperienced);
    }
    voxelFog*=exp(fogDensityMult * previousSampleDist);
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
#elif DEBUG_SPECIAL_VIEW == 100
    funnyDebug = vec3(clamp(0.05*sqrt(length(worldPosRelative)),0,1),float(isHand)*0.1,float(isSky)*0.5);
#elif DEBUG_SPECIAL_VIEW == 101
    funnyDebug = vec3(ditherValue);
#elif DEBUG_SPECIAL_VIEW == 102
    funnyDebug = vec3((texpos.x^texpos.y)&4,(texpos.x^texpos.y)&2,(texpos.x^texpos.y)&1);
#endif
}