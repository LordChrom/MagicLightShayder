#include "/lib/voxel/voxelSampler.glsl"
#include "/lib/util/dither.glsl"

uniform sampler2D colortex2;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;

/*
//const int colortex6Format = RGBA16F;
const int colortex6Format = RGB10_A2;
//const int colortex7Format = RGBA16F;
*/

layout(location = 2) out vec3 funnyDebug;

vec4 voxelLighting;
vec4 voxelFog;

void doVoxelLighting(vec2 sampleTexCoord,vec2 screenDims) {
    ivec2 texpos = ivec2(round(vec2(sampleTexCoord)*screenDims*LIGHTING_RENDERSCALE-0.07));
    ivec2 sourceTexpos = ivec2(round(vec2(sampleTexCoord)*screenDims-0.07));

    float ditherValue = dither(texpos);

    float solidDepth = texelFetch(depthtex2,sourceTexpos,0).x;
    vec4 normalAndMore = texelFetch(colortex2,sourceTexpos,0);
    float depth = texelFetch(depthtex0,sourceTexpos,0).x;

    vec3 ndcPos = vec3(vec3(sampleTexCoord,solidDepth)*2-1);

    vec3 normal = normalize(normalAndMore.xyz*2-1);

    bool isHand = normalAndMore.a>0.4 && normalAndMore.a<0.6;
    if(isHand) //currently, normal.a only stores if it is or isnt the hand
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

    if(length(worldPosRelative)>MAX_FOG_DEPTH || isSky)
        worldPosRelative=normalize(worldPosRelative)*MAX_FOG_DEPTH;

    float hitDistance = length(worldPosRelative);

//    int fogSamples = min(VOLUMETRIC_FOG_SAMPLES,int(2*length)); //theoretically saves work but in practice not really unless indoors
    const int fogSamples = VOLUMETRIC_FOG_SAMPLES;
    for(int i=0; i<VOLUMETRIC_FOG_SAMPLES; i++){
        //TODO maybe smarter spacing?
        if(i>=fogSamples)
            break;
        float weight = 1-clamp(float(i+ditherValue)/fogSamples,0.001,0.999);
        vec3 fogSamplePos = cameraPosition +worldPosRelative*weight;
        if(!isVoxelInBounds(fogSamplePos))continue;

        float density = FOG_DENSITY * (hitDistance/fogSamples);
        density = min(1.0,density);
        vec4 newSample = vec4(voxelSampleFog(fogSamplePos),density);
        voxelFog = voxelFog*(1-density) + newSample*density;
    }

    voxelFog.rgb*=FOG_BRIGHTNESS;
#endif

#if DEBUG_SPECIAL_VIEW == 0
    funnyDebug = vec3(clamp(0.03*sqrt(length(worldPosRelative)),0,1),bool(isHand),float(isSky));
#elif DEBUG_SPECIAL_VIEW == 1
    float debugCheckerScale = 7;
    bool checker = bool((int(texpos.x/debugCheckerScale)^int(texpos.y/debugCheckerScale))&1);
    vec3 mult = checker?vec3(1):vec3(normal.x<0,normal.y<0,normal.z<0)*0.25+0.75;
    funnyDebug = abs(normal)*mult;
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