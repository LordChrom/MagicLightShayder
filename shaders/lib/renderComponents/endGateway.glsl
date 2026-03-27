uniform int frameCounter;


const float gatewayspeed = 0.00004;

const mat2 angle_5 = mat2(0.996195, 0.087156, -0.087156, 0.996195);
const mat2 angle30 = mat2(0.866025, -0.5, 0.5, 0.866025);

const vec3 blu = vec3(0.05,0.25,0.4);
const vec3 grn = vec3(0.1,0.2,0.18);
const vec3 prpl = vec3(0.18,0.12,0.2);
const vec3 background = vec3(0,0.025,0.04);

#define GATEWAY_DOUBLE_SAMPLE
#define GATEWAY_ANGLES

vec3 singleEndGatewayLayer(vec2 srcPos, vec2 timeShift, vec3 color, float depth){
    srcPos=fract((srcPos+timeShift/depth)*vec2(depth*0.9,depth));
    vec3 ret = texture(gtexture,srcPos).rgb;
#ifdef GATEWAY_DOUBLE_SAMPLE
        ret=max(ret,0.6*texture(gtexture,fract(srcPos+0.5)).rgb);
#endif
    return ret*color;
}

vec3 doEndGateway(vec2 srcPos){
#define pos0 srcPos
#ifdef GATEWAY_ANGLES
    #define pos180 -srcPos
    vec2 pos_5 = srcPos*angle_5;
    vec2 pos30 = srcPos*angle30;
#else
    #define pos_5 srcPos
    #define pos30 srcPos
    #define pos180 srcPos
#endif
    vec2 timeShift = vec2(0,fract(frameCounter*gatewayspeed));
    vec3 ret = background*clamp((1-singleEndGatewayLayer(pos0,timeShift,vec3(10),1)),0,1)+
        + singleEndGatewayLayer(pos0,   timeShift,vec3(0.2),3)
        + singleEndGatewayLayer(pos180, timeShift,vec3(0.2),3)
        + singleEndGatewayLayer(pos0,   timeShift,blu,0.5)
        + singleEndGatewayLayer(pos_5,  timeShift,blu,0.6)
        + singleEndGatewayLayer(pos30,  timeShift,grn,0.9)
        + singleEndGatewayLayer(pos0,   timeShift,prpl,1.8)
        + singleEndGatewayLayer(pos_5,  timeShift,vec3(0.1)+prpl*0.6,2.2)
    ;
    return ret.rgb;
}