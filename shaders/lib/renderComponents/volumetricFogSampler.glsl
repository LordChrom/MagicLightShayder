#include "/lib/settings.glsl"

in vec2 jitteredTexcoord;
in vec3 worldPosDirection;

/* RENDERTARGETS: 7 */

layout(location = 0) out vec4 voxelFog;


uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

#include "/lib/lightingWrapper/lightSampler.glsl"
#include "/lib/util/dither.glsl"
#include "/lib/util/conversions.glsl"

uniform sampler2D colortex2;
uniform sampler2D depthtex2;
uniform sampler2D depthtex0;

uniform sampler2D colortex1;

uniform vec3 fogColor;



void main() {
    vec4 worldPosRelative;
    worldPosRelative.xy=jitteredTexcoord;
    ivec2 sourceTexpos = ivec2((worldPosRelative.xy*textureSize(depthtex0,0)+0.01));

    bool solidTransInFront = texelFetch(colortex1,sourceTexpos,0).a>=1;

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


    float ditherValue = dither(ivec2(gl_FragCoord.xy));
    #ifdef FOG_TEMPORAL_NOISE
    ditherValue = temporalNoise(ditherValue);
    #endif

    voxelFog = vec4(0,0,0,1);
    float prevWeight = 1.0;


    for(int i=0; i<VOLUMETRIC_FOG_SAMPLES; i++){
        //TODO better fog amount calc, and fix the banding, maybe smarter spacing
        float weight = 1-(float(i)+ditherValue)/VOLUMETRIC_FOG_SAMPLES;
        vec3 newSample = lightingSampleFog(cameraPosition + worldPosRelative.xyz*weight,ditherValue);

        const float fogDensityMult = FOG_THICKNESS*log(0.5)/FOG_HALF_LIFE;

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
}