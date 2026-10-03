#version 430 compatibility
#define GBUFFER_SHADER
#include "/lib/settings.glsl"
#include "/lib/voxelStorage/blockPacking.glsl"

#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE >= 0)
    #define NEEDS_MATERIAL_ID
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
    flat out uint packedTangent;
    #endif
#endif

#ifdef VERTEX_NORMALS
flat out uint packedNormal;
#endif


#if defined LIT && defined TRANSLUCENT
#define NEEDS_LMCOORD
out vec2 lmcoord;
#endif

#if defined NORMALS_NOT_INCLUDED || defined HAND
uniform mat4 gbufferModelViewInverse;
#endif


#if ( VOXELIZATION_MODE >=1 ) && (defined IS_TERRAIN )
    #include "/lib/voxelStorage/vsMapper.glsl"
    #define UPDATE_VOXEL_MAP
    #define NEEDS_MC_ENTITY
    uniform vec3 cameraPosition;
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
flat out uint packedBaseTexpos;
flat out uint packedTexsize;
out float worldLength;
#endif

#ifdef NEEDS_MATERIAL_ID
flat out int materialID;
#endif

#ifdef NEEDS_MC_ENTITY
in vec2 mc_Entity;
#endif

#if defined HARDCODED_MATERIAL || defined UPDATE_VOXEL_MAP
in vec4 at_midBlock;
#endif

#ifdef DH_SHADER
out float distFromCam;
#endif
void main() {
    gl_Position = gl_ProjectionMatrix*(mat3x4(gl_ModelViewMatrix)*gl_Vertex.xyz+gl_ModelViewMatrix[3]);
//    gl_Position = gl_ProjectionMatrix*gl_ModelViewMatrix*gl_Vertex;
    #ifdef DH_SHADER
    distFromCam=length(gl_Vertex.xyz);
    #endif
#ifdef TEXTURED
    texcoord = (gl_TextureMatrix[0] * gl_MultiTexCoord0).xy;
#endif

#ifdef VERTEX_NORMALS
    vec3 normal;

    #ifdef HAND
    normal = (gbufferModelViewInverse*vec4(gl_Normal,0)).xyz;
    #elif defined NORMALS_NOT_INCLUDED
    //TODO make these all subsurface
    normal = (gl_ModelViewMatrixInverse[2]).xyz;
    #else
    normal = gl_Normal;
    #endif
    normal = normalize(normal);

    const int normPackScale = 0x7fff;
    uvec2 h = uvec2(clamp(ivec2(round((normal.xy*0.5+0.5)*normPackScale)),0,normPackScale));
    packedNormal = (h.x<<17)|(h.y<<2)|((normal.z>=0)?2u:0u);


    #if MATERIALS_TYPE == 1 && defined TEXTURED
    h = uvec2(clamp(ivec2(round((at_tangent.xy*0.5+0.5)*normPackScale)),0,normPackScale));
    packedTangent = (h.x<<17)|(h.y<<2)|(at_tangent.z>0?2u:0u)|(at_tangent.w>0?1u:0u);


    #ifdef POM
    mat3 texTBNinverse = transpose(mat3(at_tangent.xyz,normalize(cross(at_tangent.xyz,gl_Normal)*at_tangent.w),gl_Normal));
    vec3 texHitVec = texTBNinverse  * gl_Vertex.xyz;

    worldLength = length(gl_Vertex.xyz);
    ivec2 texsize = ivec2(ceil(2*atlasSize*abs(mc_midTexCoord-texcoord)));
    packedTexsize=(texsize.x<<16)|(texsize.y&0xffff);
    ivec2 baseTexpos = ivec2(atlasSize*(mc_midTexCoord-abs(mc_midTexCoord-texcoord)));
    packedBaseTexpos = (baseTexpos.x<<16)|(baseTexpos.y&0xffff);

    differential=-texsize*texHitVec.xy/texHitVec.z;
    if(length(gl_Vertex.xyz)>POM_DISTANCE)
        differential=vec2(0);

            #ifdef ENTITY
    if(texsize.x*texsize.y<=1)
        differential=vec2(0);
            #else
    if(abs(normal.x)+abs(normal.y)+abs(normal.z)>1.000001){
        //TODO fix non-square blocks
//        texsize=ivec2(16);
//        baseTexpos=(ivec2(atlasSize*texcoord)/texsize)*texsize;
        differential=vec2(0);
    }
            #endif
        #endif
    #endif
#endif

#ifdef NEEDS_LMCOORD
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

#ifdef UPDATE_VOXEL_MAP
    writeVoxelMap(
        gl_Vertex.xyz+cameraPosition+at_midBlock.xyz*0.015625,  //world pos
        int(mc_Entity.x),                                       //block id
        int(at_midBlock.w)                                      //emission
    );
#endif

    glcolor = gl_Color;
}