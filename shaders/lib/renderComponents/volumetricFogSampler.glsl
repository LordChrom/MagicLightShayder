#include "/lib/settings.glsl"


///* RENDERTARGETS: 7 */
//layout(location = 0) out vec4 voxelFog;
#define SIZE 16
const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba16f) uniform writeonly restrict image2D colorimg7;


uniform vec2 scaledScreenDim;

uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform sampler2D colortex2;
uniform sampler2D depthtex2;
uniform sampler2D depthtex0;

uniform sampler2D colortex3;

uniform vec3 fogColor;

#include "/lib/util/uniforms/frameCounter"
#define FOG_SHADER
#include "/lib/lighting/lightWrapper.glsl"
#define TEMPORAL_DITHER
#include "/lib/util/dither.glsl"
#include "/lib/util/conversions.glsl"


const float fogDensityMult = FOG_THICKNESS*log(0.5)/FOG_HALF_LIFE;


void main() {
    vec4 worldPosRelative;
    worldPosRelative.xy=(vec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)+0.5)/scaledScreenDim;
    ivec2 sourceTexpos = ivec2((worldPosRelative.xy*textureSize(depthtex0,0)+0.01));

    bool solidTransInFront = texelFetch(colortex3,sourceTexpos,0).a>=1;

    if(abs(texelFetch(colortex2,sourceTexpos,0).a-0.5)<0.1){//hand
        worldPosRelative.z/=MC_HAND_DEPTH;
    }else if(solidTransInFront){//solid translucent
        worldPosRelative.z = texelFetch(depthtex0,sourceTexpos,0).x;
    }else{//normal terrain
        worldPosRelative.z = texelFetch(depthtex2,sourceTexpos,0).x;
    }

    worldPosRelative = gbufferProjectionInverse*vec4(worldPosRelative.xyz*2-1,1);
    worldPosRelative/=worldPosRelative.w;
    worldPosRelative.xyz = mat3(gbufferModelViewInverse)*worldPosRelative.xyz+gbufferModelViewInverse[3].xyz;;

    const float maxFogDepth = min(MAX_FOG_DEPTH,MIN_SCALE*0.5*AREA_SIZE*(1<<NUM_CASCADES));

    if(length(worldPosRelative.xyz)>maxFogDepth){
        worldPosRelative.xyz*=maxFogDepth/length(worldPosRelative.xyz);
    }


    float ditherValue = dither(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy));
    #ifdef FOG_TEMPORAL_NOISE
    ditherValue = temporalNoise(ditherValue);
    #endif

    vec4 voxelFog = vec4(0,0,0,1);
    float prevWeight = 1.0;


    for(int i=0; i<VOLUMETRIC_FOG_SAMPLES; i++){
        //TODO better fog amount calc, and fix the banding, maybe smarter spacing
        float weight = 1-(float(i)+ditherValue)/VOLUMETRIC_FOG_SAMPLES;
        vec3 newSample = lightingSampleFog(cameraPosition + worldPosRelative.xyz*weight,ditherValue);

        float localFogDensity = fogDensityMult;
        float worldPosLen = length(worldPosRelative);
        float prevFogDecay= exp(localFogDensity*worldPosLen*prevWeight);
        float fogDecay = (i==VOLUMETRIC_FOG_SAMPLES-1)? 1 : exp(localFogDensity*worldPosLen*weight);

        voxelFog *= prevFogDecay/fogDecay;
        voxelFog.rgb += newSample*(fogDecay-prevFogDecay);
        prevWeight=weight;
    }

    vec3 fogCol = max(fogColor,0.01);
    fogCol=fogCol*(FOG_BIOME_TINT_STRENGTH/length(fogCol)) + (1-FOG_BIOME_TINT_STRENGTH);
    voxelFog.rgb*=fogCol.rgb;
    imageStore(colorimg7,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),voxelFog);
}