#include "/lib/settings.glsl"



#define SIZE 16
const vec2 workGroupsRender = vec2(LIGHTING_RENDERSCALE,LIGHTING_RENDERSCALE);
layout (local_size_x = SIZE, local_size_y = SIZE, local_size_z = 1) in;

layout (rgba16f) uniform writeonly restrict image2D colorimg6;

#if DEBUG_SPECIAL_VIEW >= 0
//TODO restore debug here funnyDebug
//layout(location = 1) out vec3 funnyDebug;
#endif



uniform mat4 gbufferProjectionInverse, gbufferModelViewInverse;
uniform vec3 cameraPosition;

uniform sampler2D colortex2;
uniform sampler2D depthtex2;
uniform sampler2D depthtex0;
uniform sampler2D colortex3;

#if MATERIALS_TYPE >= 0
uniform usampler2D colortex8;
#endif

#include "/lib/util/uniforms/frameCounter"
#include "/lib/lighting/lightWrapper.glsl"
#define TEMPORAL_DITHER
#include "/lib/util/dither.glsl"



#ifdef SSAO
#include "/lib/renderComponents/ssao.glsl"
#endif


void main() {
    vec4 worldPosRelative;
    worldPosRelative.xy = (vec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy)+0.5)/imageSize(colorimg6);
    vec4 normal = texture(colortex2,worldPosRelative.xy);
    float solidDepth = texture(depthtex2,worldPosRelative.xy).x;
    #if MATERIALS_TYPE >= 0
    uvec4 matInfo = texture(colortex8,worldPosRelative.xy);
    #endif


    bool isHand = normal.a>0.4 && normal.a<0.6;

    vec4 voxelLighting=vec4(0,0,0,1);
    if(solidDepth==1){
        return;
    }
    worldPosRelative.z = solidDepth;
    worldPosRelative.w=1;
    vec2 jitteredTexcoord = worldPosRelative.xy;

    if(isHand){
        #if (IRIS_VERSION < 11008 )&& (DEBUG_SPECIAL_VIEW != 100)
        return;
        #else
        worldPosRelative.z=texture(depthtex0,worldPosRelative.xy).x/MC_HAND_DEPTH;
        #endif
    }

    worldPosRelative.xyz=worldPosRelative.xyz*2-1;
    worldPosRelative = gbufferProjectionInverse*worldPosRelative;
    worldPosRelative/=worldPosRelative.w;
    worldPosRelative.xyz = mat3(gbufferModelViewInverse)*worldPosRelative.xyz+gbufferModelViewInverse[3].xyz;

    float subsurface = 0;
    float emissive = 0;
#if MATERIALS_TYPE >= 0
    subsurface = clamp(float(int(matInfo.b)-64)/190.0, 0.0,1.0);

    //TODO subsurface on porous materials like wool
//    if(matInfo.b>=20u && matInfo.b<=64u) subsurface=float(matInfo.b)/64;
    if(matInfo.a!=255)
        emissive = (matInfo.a/254.0);
#endif



    normal.xyz = normalize(normal.xyz*2-1);

    float ditherValue = dither(ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy));


    #ifdef SSAO
    if(emissive<0.4 && !isHand){
        voxelLighting.a = doSsao(jitteredTexcoord, normal.xyz, solidDepth, ditherValue);
    }
        #if DEBUG_SPECIAL_VIEW == 103
        funnyDebug = vec3(voxelLighting.a);
        #endif
    #endif

    voxelLighting.rgb = lightingSample(worldPosRelative.xyz+cameraPosition,normal.xyz,subsurface,ditherValue)+(EMISSIVE_BRIGHTNESS*emissive);
    #ifdef SSAO
    voxelLighting.rgb*=voxelLighting.a;
    #endif

    imageStore(colorimg6,ivec2(gl_LocalInvocationID.xy+gl_WorkGroupSize.xy*gl_WorkGroupID.xy),voxelLighting);
}