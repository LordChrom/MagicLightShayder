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
    normal = (gl_ModelViewMatrixInverse[2]).xyz;
    #else
    normal = gl_Normal;
    #endif

    #if MATERIALS_TYPE == 1 && defined TEXTURED

    TBN = mat3(at_tangent.xyz,normalize(cross(at_tangent.xyz,normal)*at_tangent.w),normal);

        #ifdef POM
    vec3 texHitVec = mat3(gl_ModelViewMatrix[0].xyz,gl_ModelViewMatrix[1].xyz,gl_ModelViewMatrix[2].xyz)*gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
            #ifdef HAND
                mat3 texTBN = mat3(at_tangent.xyz,normalize(cross(at_tangent.xyz,gl_Normal)*at_tangent.w),gl_Normal);
            #else
                #define texTBN TBN
            #endif

    texHitVec = transpose(gl_NormalMatrix*texTBN)*texHitVec;

    worldLength = length(gl_Vertex.xyz-gl_ProjectionMatrix[3].xyz);
    texsize = ivec2(ceil(2*atlasSize*abs(mc_midTexCoord-texcoord)));
    baseTexpos = ivec2(atlasSize*(mc_midTexCoord-abs(mc_midTexCoord-texcoord)));

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
    lmcoord = clamp(lmcoord,1.0/32,31.0/32);
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