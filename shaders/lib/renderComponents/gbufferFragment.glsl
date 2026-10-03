#ifndef VOXY_PATCH
#version 430 compatibility
#endif

#include "/lib/settings.glsl"
const float translucentPrecedenceCutoff = 0.99;

#ifdef LOD_MOD_SHADER
    #ifdef DH_SHADER
    #define MATERIALS_TYPE -1
    #endif

    #if MATERIALS_TYPE>=0 && !defined TRANSLUCENT
        #define NEEDS_MATERIAL_ID
        #define HARDCODED_MATERIAL
        #define MATERIALS_TYPE 0
        #define WRITE_MATERIALS 2
        #include "/lib/voxelStorage/blockPacking.glsl"
    #else
        #define MATERIALS_TYPE -1
        #undef WRITE_MATERIALS
    #endif
    #undef POM
#else

#if ((DEBUG_SPECIAL_VIEW==104) || (DEBUG_SPECIAL_VIEW==106))
#undef TRANSLUCENT
#endif

#if MATERIALS_TYPE < 0
    #undef WRITE_MATERIALS
#endif

#if (defined WRITE_MATERIALS) && (MATERIALS_TYPE == 0)
    #define NEEDS_MATERIAL_ID
    #define HARDCODED_MATERIAL
    flat in uvec4 hardcodedMaterialInfo;
    #if !(HARDCODED_EMISSIVE_SELECTIVITY==-1)
        #define NEEDS_MATERIAL_ID
    #endif
#endif

#ifdef TEXTURED
in vec2 texcoord;
uniform sampler2D gtexture;
    #if MATERIALS_TYPE ==1
uniform sampler2D specular;
uniform sampler2D normals;
flat in uint packedTangent;
    #endif
#endif

#ifndef VOXY
    #undef CHECK_VOXY_DEPTH
#elif defined CHECK_VOXY_DEPTH
    uniform sampler2D vxDepthTexTrans;
#endif

#ifdef VERTEX_NORMALS
flat in uint packedNormal;
#endif

#ifdef ALPHATEST
uniform float alphaTestRef = 0.1;
#endif

#ifdef ENTITY
uniform vec4 entityColor;
#endif

#ifdef BONUS_STUFF
void doBonusStuff();
#endif

#ifdef BASIC
in flat vec4 glcolor;
#else
in vec4 glcolor;
#endif

#ifdef NEEDS_MATERIAL_ID
flat in int materialID;
#include "/lib/voxelStorage/blockPacking.glsl"
#endif

#if defined MAYBE_END_GATEWAY && defined GATEWAYS_IN_GBUFFER
    uniform float viewWidth, viewHeight;
    #include "/lib/renderComponents/endGateway.glsl"
#endif

#ifndef LOD_MOD_SHADER
    #define SOLIDIFY_OPAQUE_TRANSLUCENTS
#endif

#if defined TRANSLUCENT
    #ifdef SOLIDIFY_OPAQUE_TRANSLUCENTS
        #ifdef WRITE_MATERIALS
        #define WRITE_MATERIALS 5
        /* RENDERTARGETS: 3,4,1,2,5,8 */
        #else
        /* RENDERTARGETS: 3,4,1,2,5 */
        #endif
        layout(location = 2) out vec4 solidColorOut;
        layout(location = 3) out vec4 solidNormalOut;
        layout(location = 4) out vec4 specialDepthOut;
    #else
        #ifdef WRITE_MATERIALS
            #define WRITE_MATERIALS 2
        /* RENDERTARGETS: 3,4,8 */
        #else
        /* RENDERTARGETS: 3,4 */
        #endif
    #endif
#else
    #ifdef WRITE_MATERIALS
        #define WRITE_MATERIALS 2
    /* RENDERTARGETS: 1,2,8 */
    #else
    /* RENDERTARGETS: 1,2 */
    #endif
#endif

#endif


#ifdef HAND
    #define NORMAL_A 0.5
#elif defined TRANSLUCENT
    #define NORMAL_A 1
#else
    #define NORMAL_A 0
#endif

#if (!defined POM_ELLIGIBLE) || defined NORMALS_NOT_INCLUDED
    #undef POM
#endif

#if (defined ENTITY) && !(defined ENTITY_POM)
    #undef POM
#endif

#ifdef POM
    in vec2 differential;
    flat in uint packedBaseTexpos;
    flat in uint packedTexsize;
    ivec2 baseTexpos, texsize;
    in float worldLength;
    #ifndef ENTITY
    uniform ivec2 atlasSize;
    #else
    #define atlasSize textureSize(normals,0)
    #endif
    uniform mat4 gbufferProjectionInverse;
    float rayDepth=0;
    #include "/lib/renderComponents/pom.glsl"
    #ifdef POM_WRITE_DEPTH
    #include "/lib/util/conversions.glsl"
    #endif
#else
#undef POM_WRITE_DEPTH
#undef POM_NORMALS
#endif

layout(location = 0) out vec4 color;
layout(location = 1) out vec4 normalOut;

#ifdef WRITE_MATERIALS
layout(location = WRITE_MATERIALS) out uvec4 materialInfo;
#endif

#if defined LIT && defined TRANSLUCENT
    #include "/lib/util/shadowLightInfo.glsl"
    #ifndef VOXY_PATCH
    in vec2 lmcoord;
    #endif
#endif

const uint normPackScale = 0x7fff;

#ifdef LOD_MOD_SHADER
void handleFragment(vec4 glcolor,vec3 normal,vec2 lmcoord,vec4 voxycolor, int materialID)

#if 0
;//for my IDE :/
#endif

#else
void main()
#endif
{

#if defined VERTEX_NORMALS && !defined LOD_MOD_SHADER

    vec3 normal;

    normal.xy=vec2((uvec2(packedNormal)>>uvec2(17,2))&normPackScale)*(2.0/normPackScale)-1;
    normal.z=dot(normal.xy,normal.xy);
    normal.z = normal.z>=1?0:(sqrt(1-normal.z)*(bool(packedNormal&2u)?1:-1));

    #if (defined TEXTURED) && (MATERIALS_TYPE == 1)
    vec4 tangent;
    tangent.xy=vec2((uvec2(packedTangent)>>uvec2(17,2))&uvec2(normPackScale))*(2.0/normPackScale)-1;
    tangent.z = dot(tangent.xy,tangent.xy);
    tangent.z = tangent.z>=1?0:(sqrt(1-tangent.z)*(bool(packedTangent&2u)?1:-1));
    tangent.w = bool(packedTangent&1u)?1:-1;
    #endif
#endif

#ifdef CHECK_VOXY_DEPTH //mainly just for clouds
    float voxyDepth = texelFetch(vxDepthTexTrans,ivec2(gl_FragCoord.xy),0).x;
    if(voxyDepth<1.0)
        discard;
#endif

#ifdef MAYBE_END_GATEWAY
    bool isEndGateway = materialID==END_GATEWAY_ID;
#endif

#ifdef TEXTURED
    #ifdef POM
        baseTexpos = ivec2(packedBaseTexpos>>16,packedBaseTexpos)&0xffff;
        texsize = ivec2(packedTexsize>>16,packedTexsize)&0xffff;
        vec2 newTexcoord;

            #ifdef MAYBE_END_GATEWAY
            if(isEndGateway)
                newTexcoord=texcoord;
            else
            #endif
        {
            newTexcoord=doPom(texcoord);
        }
        #ifdef POM_WRITE_DEPTH
        float linearDepth = depthToLinear(gl_FragCoord.z);
        rayDepth = length(vec3(differential/texsize,1))*rayDepth;
        linearDepth+=rayDepth;
        gl_FragDepth=depthToBuf(linearDepth);
        #endif
    #else
//        gl_FragDepth=gl_FragCoord.z;
        #define newTexcoord texcoord
    #endif
#endif


    color=glcolor;
#ifdef MAYBE_END_GATEWAY
    if(isEndGateway){
        color = vec4(doEndGateway(gl_FragCoord.xy/vec2(viewWidth,viewHeight)),1);
    }else{
        color *= texture(gtexture, newTexcoord);
    }

#elif defined LOD_MOD_SHADER
    color *= voxycolor;
#elif defined TEXTURED
    color *= texture(gtexture, newTexcoord);
#endif

#ifdef ENTITY
    color.rgb = mix(color.rgb, entityColor.rgb, entityColor.a);
#endif

#ifdef ALPHATEST
    if (color.a < alphaTestRef) {
        discard;
    }
#endif

#ifdef VERTEX_NORMALS
    #if (defined TEXTURED) && (MATERIALS_TYPE == 1)
    vec4 pbrNormalSample = texture(normals,newTexcoord);

    pbrNormalSample.xy = (pbrNormalSample.xy-0.5)*2;

    normalOut.xyz = normalize(vec3(PBR_NORMALS_STRENGTH*pbrNormalSample.xy,sqrt(1.0 - dot(pbrNormalSample.xy, pbrNormalSample.xy))));

    #ifdef POM_NORMALS
    const float pomDistFalloffMult = 4;
    pomNormal=normalize(mix(vec3(0,0,1),pomNormal+vec3(0,0,0.1),clamp(pomDistFalloffMult/(max(1e-4,worldLength)),0,1)));

    float texNormalWeight = max(1e-6,pomNormal.z);

    normalOut.xyz = normalize(pomNormal+texNormalWeight*normalOut.xyz);
    #endif
    normalOut.xyz = normalize( mat3(tangent.xyz,normalize(cross(tangent.xyz,normal)*tangent.w),normal) * normalOut.xyz );

    #ifdef POM
        #if DEBUG_SPECIAL_VIEW==104
        ivec2 checkerPos = (ivec2(floor(texcoord*atlasSize))-baseTexpos)%texsize;
        float checkerf=((bitCount(checkerPos.x^checkerPos.y)&3))/3.0;
        color.xyz=vec3(min(abs(differential.xy*0.3),1)*vec2((differential.x<=0)?1-checkerf:1,(differential.y<=0)?1-checkerf:1),0.1);
        #elif DEBUG_SPECIAL_VIEW==106
        ivec2 checkerPos = (ivec2(floor(newTexcoord*atlasSize))-baseTexpos)%texsize;
        float checkerf=((bitCount(checkerPos.x^checkerPos.y)&3))/3.0;
        color.xyz=mix(color.xyz,vec3(checkerf.x),0.5);
        if(checkerPos.x==0 || checkerPos.y==0)
            color.r=1;
        else if(checkerPos.x==(texsize.x-1) || checkerPos.y==(texsize.y-1))
            color.b=1;
        #endif
    #endif
    #else
        normalOut.xyz=normal;
    #endif

    normalOut.a=NORMAL_A;


    #ifdef TRANSLUCENT
    if(color.a<=translucentPrecedenceCutoff)
        normalOut.a=0;
    #endif
#endif


#ifdef WRITE_MATERIALS
    #if MATERIALS_TYPE == 0 //hardcoded
        #ifdef LOD_MOD_SHADER
    materialInfo = getHardcodedMaterial(uint(materialID));
        #else
    materialInfo = hardcodedMaterialInfo;
        #endif
        #if !(HARDCODED_EMISSIVE_SELECTIVITY==-1)
    if(materialInfo.a!=255){
        vec3 lightColor = getMaterialColor(uint(materialID));
        float brightness = dot(color.rgb/glcolor.rgb,normalize(lightColor));
        brightness*=brightness;
        brightness = brightness*HARDCODED_EMISSIVE_SELECTIVITY + (1-HARDCODED_EMISSIVE_SELECTIVITY);
        materialInfo.a=uint(clamp(brightness,0,1)*materialInfo.a);
    }
        #endif

    #elif MATERIALS_TYPE == 1 //PBR pack
    materialInfo = uvec4(round(clamp(texture(specular,newTexcoord)*255.0,0,255)));
    #endif

    #ifdef TRANSLUCENT

    if(color.a<translucentPrecedenceCutoff)
        materialInfo.a=255;
    #endif
#endif


    #ifdef BONUS_STUFF
    doBonusStuff();
    #endif


#ifdef TRANSLUCENT
    #ifdef SOLIDIFY_OPAQUE_TRANSLUCENTS


    if(color.a>=0.99){
        solidColorOut =vec4(color.rgb,1.0);
        solidNormalOut=vec4(normalOut.rgb,1.0);

        normalOut = vec4(0.0,0.0,0.0,-0.9);
        specialDepthOut=vec4(gl_FragCoord.z,0,0,1);

        color=vec4(0.0,0.0,0.0,1.0);
    }else{
        #ifdef LIT
        color.rgb*=max(vec3(0.2),lmcoord.y*getSunColor());
        #endif
        solidColorOut=vec4(0.0);
        solidNormalOut=vec4(0.0);

        specialDepthOut=vec4(0,color.a,0,color.a);
        normalOut.a=0;
    }

    #ifdef MAYBE_END_GATEWAY
    if(isEndGateway)
        normalOut.a=1;
    #endif
    #elif defined VOXY_PATCH
    color.rgb*=max(vec3(0.2),lmcoord.y*getSunColor());
    #endif
#else
    #ifdef SKYTEXTURED
//    color.rgb*=0;
    #elif defined MAYBE_END_GATEWAY
    color.a=isEndGateway?0.0:1.0;
    #elif defined LIT
    color.a=1.0;
    #elif defined BASIC
    bool isLeash = length(glcolor.xyz-vec3(0.425,0.34,0.25))<0.5;
    color.a=float(isLeash);
    #else
    color.a=0.0;
    #endif
#endif
}