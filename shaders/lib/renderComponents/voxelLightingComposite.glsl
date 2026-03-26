#include "/lib/voxel/voxelSampler.glsl"
#include "/lib/util/dither.glsl"

uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;



layout(location = 2) out vec3 funnyDebug;

vec4 voxelLighting;
vec4 voxelFog;

void doVoxelLighting(vec2 sampleTexCoord, ivec2 inTexpos, ivec2 outTexpos) {
    float ditherValue = dither(outTexpos);

    float solidDepth = texelFetch(depthtex2,inTexpos,0).x;
    vec4 normalAndMore = texelFetch(colortex4,inTexpos,0);
    float depth = texelFetch(depthtex0,inTexpos,0).x;

    vec3 ndcPos = vec3(vec3(sampleTexCoord,solidDepth)*2-1);

    vec3 normal = normalize(normalAndMore.xyz*2-1);

    if(normalAndMore.a>0.5) //currently, normal.a only stores if it is or isnt the hand
    ndcPos.z/=MC_HAND_DEPTH;

    vec4 viewPos = gbufferProjectionInverse*vec4(ndcPos,1);
    viewPos/=viewPos.w;

    vec3 worldPosRelative = (gbufferModelViewInverse*viewPos).xyz;
    vec3 worldPos = worldPosRelative+cameraPosition;

    bool isSky = depth==1;

    bool voxelLit = isVoxelInBounds(worldPos+normal*0.1) && !isSky;
    if(voxelLit)
        voxelLighting = vec4(voxelSample(worldPos,normal),1);
    else
        voxelLighting = vec4(0);

#if VOLUMETRIC_FOG_SAMPLES > 0
    voxelFog = vec4(0);

    if(length(worldPosRelative)>MAX_FOG_DEPTH)
        worldPosRelative=normalize(worldPosRelative)*MAX_FOG_DEPTH;

    float length = length(worldPosRelative);

//    int fogSamples = min(VOLUMETRIC_FOG_SAMPLES,int(2*length)); //theoretically saves work but in practice not really unless indoors
    const int fogSamples = VOLUMETRIC_FOG_SAMPLES;
    for(int i=0; i<VOLUMETRIC_FOG_SAMPLES; i++){
        //TODO maybe smarter spacing?
        if(i>=fogSamples)
            break;
        float weight = 1-clamp(float(i+ditherValue)/fogSamples,0.001,0.999);
        vec3 fogSamplePos = cameraPosition +worldPosRelative*weight;
        if(!isVoxelInBounds(fogSamplePos))continue;

        float density = FOG_DENSITY * (length/fogSamples);
        density = min(1.0,density);
        vec4 newSample = vec4(voxelSampleFog(fogSamplePos),density);
        voxelFog = voxelFog*(1-density) + newSample*density;
    }

    voxelFog.rgb*=FOG_BRIGHTNESS;
#endif

#if DEBUG_SPECIAL_VIEW == 0
    funnyDebug = vec3(length(worldPosRelative)/40,normalAndMore.a,float(isSky));
#elif DEBUG_SPECIAL_VIEW == 1
    funnyDebug = normalAndMore.xyz;
#elif DEBUG_SPECIAL_VIEW == 2
    funnyDebug = voxelLighting.xyz;
#elif DEBUG_SPECIAL_VIEW == 3
    funnyDebug = voxelFog.xyz;
#elif DEBUG_SPECIAL_VIEW == 4
    funnyDebug = vec3(ditherValue);
#elif DEBUG_SPECIAL_VIEW == 5
    funnyDebug = vec3((inTexpos.x^inTexpos.y)&4,(inTexpos.x^inTexpos.y)&2,(inTexpos.x^inTexpos.y)&1);
#elif DEBUG_SPECIAL_VIEW == 6
#elif DEBUG_SPECIAL_VIEW == 7
#elif DEBUG_SPECIAL_VIEW == 8
#elif DEBUG_SPECIAL_VIEW == 9
#elif DEBUG_SPECIAL_VIEW == 10
#endif
}