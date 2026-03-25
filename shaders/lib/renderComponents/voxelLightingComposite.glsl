#include "/lib/voxel/voxelSampler.glsl"
#include "/lib/util/dither.glsl"

uniform sampler2D colortex4;
uniform sampler2D depthtex0;
uniform sampler2D depthtex2;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferModelViewInverse;



///* RENDERTARGETS: 6 */
//layout(location = 0) out vec4 lighting;

vec4 voxelLighting;
vec4 voxelFog;

void doVoxelLighting(vec2 sampleTexCoord, ivec2 texpos) {

    float solidDepth = texelFetch(depthtex2,texpos,0).x;
    vec4 normalAndMore = texelFetch(colortex4,texpos,0);
    float depth = texelFetch(depthtex0,texpos,0).x;

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
    float offset = dither(texpos);

    const float maxFogDepth = 70;
    if(length(worldPosRelative)>maxFogDepth)
        worldPosRelative=normalize(worldPosRelative)*maxFogDepth;

    float length = length(worldPosRelative);

//    int fogSamples = min(VOLUMETRIC_FOG_SAMPLES,int(2*length)); //theoretically saves work but in practice not really
    const int fogSamples = VOLUMETRIC_FOG_SAMPLES;
    for(int i=0; i<VOLUMETRIC_FOG_SAMPLES; i++){
        //TODO maybe smarter spacing?
        if(i>=fogSamples)
            break;
        float weight = 1-clamp(float(i+offset)/fogSamples,0.001,0.999);
        vec3 fogSamplePos = cameraPosition +worldPosRelative*weight;
        if(!isVoxelInBounds(fogSamplePos))continue;

        float density = FOG_DENSITY * (length/fogSamples);
        density = min(1.0,density);
        vec4 newSample = vec4(voxelSampleFog(fogSamplePos),density);
        voxelFog = voxelFog*(1-density) + newSample*density;
    }

    voxelFog.rgb*=FOG_BRIGHTNESS;
#endif
}