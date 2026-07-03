#version 430 compatibility
#include "/lib/settings.glsl"
#include "/lib/util/materialId.glsl"

#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE == 0)
    #define HARDCODED_MATERIAL
    flat out uvec4 hardcodedMaterialInfo;
    #if !(HARDCODED_EMISSIVE_SELECTIVITY==-1)
        #define NEEDS_MATERIAL_ID
    #endif
#endif

#ifdef BASIC
out flat vec4 glcolor;
#else
out vec4 glcolor;
#endif

#ifdef TEXTURED
out vec2 texcoord;
    #if MATERIALS_TYPE == 1
    in vec4 at_tangent;
    flat out mat3 TBN;
    #endif
#endif

#ifdef VERTEX_NORMALS
out vec3 normal;
#endif

#ifdef LIT
out vec2 lmcoord;
const vec2 maxLm = vec2(15.0/16.0);
#endif

#if defined NORMALS_NOT_INCLUDED || defined HAND
uniform mat4 gbufferModelViewInverse;
#endif


#if ( VOXELIZATION_MODE >=1 ) && (defined IS_TERRAIN )
    #include "/lib/voxel/voxelMapper.glsl"
    #define NEEDS_WORLD_POS 0
    #define UPDATE_VOXEL_MAP
    #define NEEDS_MC_ENTITY
#endif

#if defined FORWARD_TRANSLUCENTS && defined TRANSLUCENT
    #define NEEDS_WORLD_POS 1
#endif

#ifdef NEEDS_WORLD_POS
uniform vec3 cameraPosition;

#if NEEDS_WORLD_POS>=1
    out vec3 worldPos;
#endif
#endif

#if (defined NEEDS_MATERIAL_ID) || (defined HARDCODED_MATERIAL)
    #ifdef BLOCK_ENTITY
        uniform int blockEntityId;
    #else
        #define NEEDS_MC_ENTITY
    #endif
#endif

#if (!defined POM_ELLIGIBLE) || defined NORMALS_NOT_INCLUDED
    #undef POM
#endif

#ifdef POM
  #ifndef ENTITY
    uniform ivec2 atlasSize;
  #else
    uniform sampler2D normals;
    #define atlasSize textureSize(normals,0)
  #endif
uniform mat4 gbufferProjectionInverse;
in vec2 mc_midTexCoord;
out vec2 differential;
flat out ivec2 baseTexpos;
flat out ivec2 texsize;
out float worldLength;
#endif

#ifdef NEEDS_MATERIAL_ID
flat out int materialID;
#endif

#ifdef NEEDS_MC_ENTITY
in vec2 mc_Entity;
#endif
in vec4 at_midBlock;

uniform float frameTimeCounter;
void main() {
    gl_Position = ftransform();

#ifdef TEXTURED
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#endif

#ifdef VERTEX_NORMALS

    #ifdef HAND
    normal = (gbufferModelViewInverse*vec4(gl_Normal,0)).xyz;
    #elif defined NORMALS_NOT_INCLUDED
    //TODO make these all subsurface
//    normal = (gbufferModelViewInverse*vec4(0,0,1,0)).xyz;
    normal = (gbufferModelViewInverse[2]).xyz;
    #else
    normal = gl_Normal;
    #endif

    #if MATERIALS_TYPE == 1 && defined TEXTURED
    TBN = mat3(at_tangent.xyz,normalize(cross(at_tangent.xyz,normal)*at_tangent.w),normal);
        #ifdef POM
    worldLength = length(gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz);
    texsize = ivec2(ceil(2*atlasSize*abs(mc_midTexCoord-texcoord)));
    baseTexpos = ivec2(atlasSize*(mc_midTexCoord-abs(mc_midTexCoord-texcoord)));

    mat4 invProjection = gbufferProjectionInverse;

    #ifdef HAND
        invProjection = inverse(gl_ProjectionMatrix);
    #endif

    vec3 scrnVecNorm = normalize((invProjection*gl_Position).xyz);
            #ifdef HAND
    vec3 texHitVec = transpose(gl_NormalMatrix*mat3(at_tangent.xyz,normalize(cross(at_tangent.xyz,gl_Normal)*at_tangent.w),gl_Normal))*scrnVecNorm;
            #else
    vec3 texHitVec = transpose(gl_NormalMatrix*TBN)*scrnVecNorm;
            #endif
    differential=-texsize*texHitVec.xy/texHitVec.z;

            #ifdef ENTITY
    if(texsize.x*texsize.y<=1)
        differential=vec2(0);
            #else
    if(abs(normal.x)+abs(normal.y)+abs(normal.z)>1.000001){
        //TODO fix lava
//        texsize=ivec2(16);
//        baseTexpos=(ivec2(atlasSize*texcoord)/texsize)*texsize;
        differential=vec2(0);
    }
            #endif
        #endif
    #endif
#endif

#ifdef LIT
    lmcoord = (gl_TextureMatrix[1] * gl_MultiTexCoord1).xy;
    lmcoord = min(lmcoord,maxLm);
#endif

#if (defined NEEDS_MATERIAL_ID) || (defined HARDCODED_MATERIAL)
    #ifndef NEEDS_MATERIAL_ID
        int materialID;
    #endif

    #ifdef BLOCK_ENTITY
        materialID = blockEntityId;
        if(materialID==65535)
            materialID=-1;
    #else
    //TODO handle old versions, optifine jank
        materialID = int(round(mc_Entity.x));
    #endif
#endif

#ifdef HARDCODED_MATERIAL
    hardcodedMaterialInfo = getHardcodedMaterial(materialID,int(at_midBlock.w));
#endif

#ifdef NEEDS_WORLD_POS
    #if NEEDS_WORLD_POS<1
        vec3
    #endif
    worldPos = gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz+cameraPosition;
#endif

#ifdef UPDATE_VOXEL_MAP
    int emission = int(at_midBlock.w);

    vec3 toMidblock = at_midBlock.xyz/64.0;
    int blockId = int(mc_Entity.x);
    writeVoxelMap(worldPos,blockId,toMidblock,gl_Normal,emission);
#endif

    glcolor = gl_Color;
}