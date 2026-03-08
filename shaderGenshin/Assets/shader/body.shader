Shader "Custom/body"
{
    Properties
    {
        [header(texture)]
        _BaseMap("Base Map", 2D) = "white"{}
        _LightMap("Light Map", 2D) = "white"{}
        [Toggle(_USE_LIGHTMAP_AO)]
        _UseLightMapAO("Use LightMap AO", Range(0,1) ) = 1
        _RampTex("Ramp Tex",2D)="white"{}
        [header(rampShadow)]
        [Toggle(_USE_RAMP_SHADOW)]
        _UseRampShadow("Use Ramp Shadow", Range(0,1) ) = 1
        _ShadowRampWidth("Shadow Ramp Width", Float ) = 1
        _ShadowPosition("Shadow Position", Float) = 0.55
        _ShadowSoftness("Shadow Softness", Float) = 0.5
        [Toggle(_USE_RAMP_SHADOW2)]
        _UseRampShadow2("Use Ramp Shadow2", Range(0,1) ) = 1
        [Toggle(_USE_RAMP_SHADOW3)]
        _UseRampShadow3("Use Ramp Shadow3", Range(0,1) ) = 1
        [Toggle(_USE_RAMP_SHADOW4)]
        _UseRampShadow4("Use Ramp Shadow4", Range(0,1) ) = 1
        [Toggle(_USE_RAMP_SHADOW5)]
        _UseRampShadow5("Use Ramp Shadow5", Range(0,1) ) = 1


        [header(halflambert)]
        _lambertPower("lambertPower", Range(0.1,5)) =1

        [header(rimlight)]
        _RimColor("Rim Color", Color) = (1,0,0,1)
        _RimPower("Rim Power", Range(0,10)) = 9
        _RimWidth("Rim Width", Range(0,10)) = 10

        [header(Lighting Option)]
        _DayOrNight("Day Or Night", Range(0,1)) = 0

        [header(specular)]
        _Gloss("Gloss Power",Range(1,512))=64
        _SpecularColor("SpecualrColor", Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags
        {
            "RenderPipeline"="UniversalRenderPipeline"
            "RenderType"="Opaque"
        }
        HLSLINCLUDE

        #pragma multi_compile _MAIN_LIGHT_SHADOWS // 主光源阴影
        #pragma multi_compile _MAIN_LIGHT_SHADOWS_CASCADE // 主光源阴影级联
        #pragma multi_compile _MAIN_LIGHT_SHADOWS_SCREEN // 主光源阴影屏幕空间

        #pragma multi_compile_fragment _LIGHT_LAYERS // 光照层
        #pragma multi_compile_fragment _LIGHT_COOKIES // 光照饼干
        #pragma multi_compile_fragment _SCREEN_SPACE_OCCLUSION // 屏幕空间遮挡
        #pragma multi_compile_fragment _ADDITIONAL_LIGHT_SHADOWS // 额外光源阴影
        #pragma multi_compile_fragment _SHADOWS_SOFT // 阴影软化
        #pragma multi_compile_fragment _REFLECTION_PROBE_BLENDING // 反射探针混合
        #pragma multi_compile_fragment _REFLECTION_PROBE_BOX_PROJECTION // 反射探针盒投影

        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库
        
        #pragma shader_feature_local _USE_LIGHTMAP_AO
        #pragma shader_feature_local _USE_RAMP_SHADOW


        CBUFFER_START(UnityPerMaterial)
            sampler2D _BaseMap;
            sampler2D _LightMap;
            sampler2D _RampTex;

            float4 _RimColor;
            float _RimPower;
            float _RimWidth;
            float _lambertPower;

            float _ShadowRampWidth;
            float _ShadowSoftness;
            float _ShadowPosition;
            float _UseRampShadow2;
            float _UseRampShadow3;
            float _UseRampShadow4;
            float _UseRampShadow5;

            float _DayOrNight;

            float _Gloss;
            float4 _SpecularColor;

        CBUFFER_END

        // 官方版本的RampShadowID函数
        float RampShadowID(float input, float useShadow2, float useShadow3, float useShadow4, float useShadow5, 
            float shadowValue1, float shadowValue2, float shadowValue3, float shadowValue4, float shadowValue5)
        {
            // 根据input值将模型分为5个区域
            float v1 = step(0.6, input) * step(input, 0.8); // 0.6-0.8区域
            float v2 = step(0.4, input) * step(input, 0.6); // 0.4-0.6区域
            float v3 = step(0.2, input) * step(input, 0.4); // 0.2-0.4区域
            float v4 = step(input, 0.2);                    // 0-0.2区域

            // 根据开关控制是否使用不同材质的值
            float blend12 = lerp(shadowValue1, shadowValue2, useShadow2);
            float blend15 = lerp(shadowValue1, shadowValue5, useShadow5);
            float blend13 = lerp(shadowValue1, shadowValue3, useShadow3);
            float blend14 = lerp(shadowValue1, shadowValue4, useShadow4);

            // 根据区域选择对应的材质值
            float result = blend12;                // 默认使用材质1或2
            result = lerp(result, blend15, v1);    // 0.6-0.8区域使用材质5
            result = lerp(result, blend13, v2);    // 0.4-0.6区域使用材质3
            result = lerp(result, blend14, v3);    // 0.2-0.4区域使用材质4
            result = lerp(result, shadowValue1, v4); // 0-0.2区域使用材质1

            return result;
        }

        ENDHLSL
        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }
            ZWrite On
            ZTest LEqual

            HLSLPROGRAM

            #pragma vertex MainVS
            #pragma fragment MainFS

            struct Attributes
            {
                float4 PositionOS : POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 color : COLOR0;
            };

            struct Varyings
            {
                float4 PositionCS : SV_POSITION;
                float2 uv0 : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float4 color : TEXCOORD3;
            };

            Varyings MainVS(Attributes input) 
            {
                Varyings output;
                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.PositionOS.xyz);
                VertexNormalInputs vertexNormalInputs = GetVertexNormalInputs(input.normalOS);

                output.normalWS = vertexNormalInputs.normalWS;
                output.PositionCS = vertexInput.positionCS;
                output.uv0 = input.uv0;
                output.worldPos = vertexInput.positionWS;
                output.color = input.color;
                return output;
            }
            half4 MainFS(Varyings input) : SV_TARGET 
            {
                //半lambert漫反射
                Light mainlight = GetMainLight();
                half4 vertexColor = input.color;

                half3 N = normalize(input.normalWS);
                half3 L = normalize(mainlight.direction);
                half NdotL = dot(N,L);
                half halflambert = (NdotL*0.5)+0.5;
                halflambert=halflambert*_lambertPower;
                half4 baseMap = tex2D(_BaseMap, input.uv0);
                half lambertStep = smoothstep(0.01,1,halflambert);
                half shadowFactor = lerp(0,halflambert,lambertStep);

                //AD环境光
                half4 lightMap = tex2D(_LightMap, input.uv0);

                #if _USE_LIGHTMAP_AO
                    half ambient = lightMap.g;  
                #else
                    half ambient = halflambert;
                #endif

                half shadow = (ambient+halflambert)*0.5;
                shadow = lerp(shadow,1,step(0.95,ambient));
                shadow = lerp(shadow,0,step(ambient,0.05));

                half isShadowArea = step(shadow,_ShadowPosition);
                half shadowDepth =saturate((_ShadowPosition - shadow )/_ShadowPosition);
                shadowDepth= pow(shadowDepth,_ShadowSoftness);
                shadowDepth= min(shadowDepth,1); 
                half rampWidthFactor = vertexColor.g * 2 * _ShadowRampWidth;
                half shadowPosition =(_ShadowPosition - shadowFactor)/_ShadowPosition;

                half rampU= 1- saturate(shadowDepth / rampWidthFactor);
                half rampID = RampShadowID(lightMap.a,_UseRampShadow2,_UseRampShadow3,_UseRampShadow4,_UseRampShadow5,1,2,3,4,5);
                half rampV= 0.45-(rampID - 1) * 0.1;
                half2 rampDayUV = half2(rampU,rampV+0.5);
                half2 rampNightUV = half2(rampU,rampV);
                half3 rampDaycolor = tex2D(_RampTex,rampDayUV).rgb;
                half3 rampNightcolor = tex2D(_RampTex,rampNightUV).rgb;
                half3 rampColor = lerp(rampDaycolor,rampNightcolor,_DayOrNight);

                //rim轮廓光
                half3 viewDir = normalize(_WorldSpaceCameraPos-input.worldPos);
                half NdotV = dot(N,viewDir);
                half rimFactor = 1-smoothstep(0,_RimWidth ,NdotV);
                rimFactor=rimFactor*_RimPower;
                half3 rimColor = _RimColor.rgb * rimFactor;

                //blinnPhong
                half3 H = normalize(L+viewDir);
                half NdotH = saturate(dot(N,H));
                half SpecularStrength = pow(NdotH,_Gloss);
                half backLightMask = step(0,NdotL);
                SpecularStrength = step(0.5, SpecularStrength);
                half3 specularColor = SpecularStrength * _SpecularColor.rgb * mainlight.color * backLightMask;
                specularColor *= lightMap.r;
                #if _USE_RAMP_SHADOW
                    half3 finalcolor = baseMap.rgb * rampColor *(isShadowArea? 1 : 1.2) * (shadow+0.5) + rimColor + specularColor;
                #else
                    half3 finalcolor = baseMap.rgb * halflambert * (shadow+0.5) + rimColor + specularColor;
                #endif

                return half4(finalcolor,1);
            }   

            ENDHLSL
        }   
        Pass
        {
            Name "ShadowCaster"
            Tags { "LightMode" = "ShadowCaster"}

            ZWrite On
            ZTest LEqual
            ColorMask 0
            Cull Off

            HLSLPROGRAM
                #pragma multi_compile_instancing // 启用GPU实例化编译
                #pragma multi_compile _ _DOTS_INSTANCING_ON // 启用DOTS实例化编译
                #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW // 启用点光源阴影

                #pragma vertex ShadowVS
                #pragma fragment ShadowFS

                float3 _LightDirection;
                float3 _LightPosition;

                struct Attributes
                {
                    float4 positionOS : POSITION;
                    float3 normalOS : NORMAL;
                };

                struct Varyings
                {
                    float4 PositionCS : SV_POSITION;
                    
                };

                // 将阴影的世界空间顶点位置转换为适合阴影投射的裁剪空间位置
                float4 GetShadowPositionHClip(Attributes input)
                {
                    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz); // 将本地空间顶点坐标转换为世界空间顶点坐标
                    float3 normalWS = TransformObjectToWorldNormal(input.normalOS); // 将本地空间法线转换为世界空间法线

                    #if _CASTING_PUNCTUAL_LIGHT_SHADOW // 点光源
                        float3 lightDirectionWS = normalize(_LightPosition - positionWS); // 计算光源方向
                    #else // 平行光
                        float3 lightDirectionWS = _LightDirection; // 使用预定义的光源方向
                    #endif

                    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS)); // 应用阴影偏移

                    // 根据平台的Z缓冲区方向调整Z值
                    #if UNITY_REVERSED_Z // 反转Z缓冲区
                        positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在近裁剪平面以下
                    #else // 正向Z缓冲区
                        positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE); // 限制Z值在远裁剪平面以上
                    #endif

                    return positionCS; // 返回裁剪空间顶点坐标
                }

                Varyings ShadowVS (Attributes input)
                {
                    Varyings output;
                    output.PositionCS = GetShadowPositionHClip(input);
                    return output;
                }

                half4 ShadowFS(Varyings input):SV_TARGET
                {
                    return 0 ;
                }

            ENDHLSL

        }

    }
}
