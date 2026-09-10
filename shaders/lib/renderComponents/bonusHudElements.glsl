uniform float aspectRatio;
uniform bool hideGUI;
uniform mat4 gbufferModelView;

const vec2 bonusHudSpot = vec2(0.03,0.03);
const float bonusHudScale = 0.02;
const float bonusHudBirghtness = 2;
const float bonusHudOpacity = 1;
const float bonusHudWidth = 0.12;
const float bonusHudBorderThickness = 0.2;


void renderAxisGizmo(inout vec3 color, vec2 texcoord){
    if(hideGUI)
        return;
    texcoord.x*=aspectRatio;
    texcoord/=bonusHudScale;
    texcoord-=bonusHudSpot/bonusHudScale;

    float maxTxAbs = max(abs(texcoord.x),abs(texcoord.y));
    if(maxTxAbs>1)
        return;


    float len = length(texcoord);
    if(len>1) return;
    vec3 hudColor = vec3(0);



    float angle = atan(texcoord.y,texcoord.x);



    vec3 axisAngles=vec3(
        atan(gbufferModelView[0][1],gbufferModelView[0][0]),
        atan(gbufferModelView[1][1],gbufferModelView[1][0]),
        atan(gbufferModelView[2][1],gbufferModelView[2][0])
    );
    axisAngles=abs(axisAngles-angle);
    axisAngles=min(axisAngles,2*PI-axisAngles);


    vec3 axisLen = vec3(
        gbufferModelView[0].z,
        gbufferModelView[1].z,
        gbufferModelView[2].z
    );

    if(len>1-bonusHudBorderThickness){
        hudColor=(asin(min(abs(axisLen),1))-0.5*axisAngles)/PI;
        hudColor=step(-hudColor,vec3(0)) * max(step(fract(hudColor*12+0.25),vec3(0.5))*0.7+0.3,step(axisLen,vec3(0)));
        hudColor*=abs(axisLen);
    }else {
        len/=1-(bonusHudBorderThickness+0.1);


        axisAngles/= atan(bonusHudWidth/len);

        axisLen=sqrt(1-axisLen*axisLen);

        hudColor+=bonusHudBirghtness*clamp((1-axisAngles)*3, 0, 1)*clamp((axisLen-len)*100, 0, 1);

        if (len<bonusHudWidth)
            hudColor=vec3(bonusHudBirghtness);

        axisLen = vec3(
            gbufferModelView[0].z,
            gbufferModelView[1].z,
            gbufferModelView[2].z
        );

        if(hudColor.r>0 && axisLen.r>max(axisLen.g,axisLen.b))
            hudColor.gb=vec2(0);
        if(hudColor.g>0 && axisLen.g>max(axisLen.r,axisLen.b))
            hudColor.rb=vec2(0);
        if(hudColor.b>0 && axisLen.b>max(axisLen.r,axisLen.g))
            hudColor.rg=vec2(0);
    }
    color = mix(color,hudColor,bonusHudOpacity);
}