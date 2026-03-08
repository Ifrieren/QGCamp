Shader "Custom/face"
{
    Properties
    {
        [header(texture)]
        _BaseMap("Base Map",2D)="white"{}
        [header(shadow option)]
        [Toggle(_USE_SDF_SHADOW)]_UseSDFShadow("UseSDFShadow",Range(0,1)) = 1
        _SDF("SDF",2D)="white"{}
        _ShadowMask("Shadow Mask",2D)="white"{}
        _ShadowColor("Shadow Color", Color)=(1,0.87,0.87,1)

        [header(Head Direction)]
        [HideInInspector]_HeadForward("Head Forward", Vector)=(0,0,1,0)
        [HideInInspector]_HeadRight("Head Right", Vector)=(1,0,0,0)
        [HideInInspector]_HeadUp("Head Up", Vector)=(1,0,0,0)

        [Header(Face Flush)]
        _FaceFlushColor("Face Flush Color",Color)=(0,1,0,0)
        _FaceFlushStrength("Face Flush Strength", Range(0,1))=0

        [header(rimlight)]
        _RimColor("Rim Color", Color) = (1,0,0,1)
        _RimPower("Rim Power", Range(0,10)) = 9
        _RimWidth("Rim Width", Range(0,10)) = 10

        [header(specular)]
        _Gloss("Gloss Power",Range(1,512))=64
        _SpecularColor("SpecualrColor", Color)=(1,1,1,1)
    }
    SubShader
    {
        Tags {  
            "RenderPipeline" = "UniversalPipeline" 
                "RenderType" = "Opaque" 
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

        #pragma shader_feature_local _USE_SDF_SHADOW
        
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // 核心库
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 光照库
        CBUFFER_START(UnityPerMaterial)
            sampler2D _BaseMap;

            sampler2D _ShadowMask;
            sampler2D _SDF;
            float4 _ShadowColor;

            float3 _HeadForward;
            float3 _HeadRight;
            float3 _HeadUp;

            float4 _RimColor;
            float _RimPower;
            float _RimWidth;

            float4 _FaceFlushColor;
            float _FaceFlushStrength;

            float _Gloss;
            float4 _SpecularColor;

        CBUFFER_END
        ENDHLSL
        Pass
        {
            Name "UniversalForward"
            Tags { "LightMode" = "UniversalForward" }

            HLSLPROGRAM
            #pragma vertex MainVS
            #pragma fragment MainFS
            struct Attribites
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv0 : TEXCOORD0;
            };
            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 normalWS : NORMAL;
                float2 uv0 : TEXCOORD0;
                float3 worldPos : TEXCOORD2;
            };
            Varyings MainVS(Attribites input)
            {
                Varyings output;
                VertexPositionInputs positionInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normalInput.normalWS;
                output.positionCS = positionInput.positionCS;
                output.uv0 = input.uv0;
                output.worldPos = positionInput.positionWS;
                return output;
            }
            half4 MainFS(Varyings input) : SV_TARGET
            {   
                Light mainlight = GetMainLight();
                half3 L = normalize(mainlight.direction);
                half3 N = normalize(input.normalWS);
                half NdotL = dot (N,L);

                half4 baseMap = tex2D(_BaseMap,input.uv0);

                half3 headUpDir = normalize(_HeadUp);
                half3 headRightDir = normalize(_HeadRight);
                half3 headForwardDir = normalize(_HeadForward);

                half halflambert = (NdotL*0.5)+0.5;
                half4 shadowMask = tex2D(_ShadowMask,input.uv0);

                half3 LpU = dot(L, headUpDir) / pow(length(headUpDir), 2) * headUpDir; // 计算光源方向在面部上方的投影
                half3 LpHeadHorizon = normalize(L- LpU); // 光照方向在头部水平面上的投影
                half value = acos(dot(LpHeadHorizon, headRightDir)) / 3.141592654; // 计算光照方向与面部右方的夹角
                half exposeRight = step(value, 0.5); // 判断光照是来自右侧还是左侧
                half valueR = pow(1 - value * 2, 3); // 右侧阴影强度
                half valueL = pow(value * 2 - 1, 3); // 左侧阴影强度
                half mixValue = lerp(valueL, valueR, exposeRight); // 混合阴影强度
                half sdfLeft = tex2D(_SDF, half2(1 - input.uv0.x, input.uv0.y)).r; // 左侧距离场
                half sdfRight = tex2D(_SDF, input.uv0).r; // 右侧距离场
                half mixSdf = lerp(sdfRight, sdfLeft, exposeRight); // 采样SDF纹理
                half sdf = step(mixValue, mixSdf); // 计算硬边界阴影
                sdf = lerp(0, sdf, step(0, dot(LpHeadHorizon, headForwardDir))); // 计算右侧阴影
                sdf *= shadowMask.g; // 使用G通道控制阴影强度
                sdf = lerp(sdf, 1, shadowMask.a); // 使用A通道作为阴影遮罩

                half flushStrength = lerp(0 , baseMap.a ,_FaceFlushStrength);

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

                #if _USE_SDF_SHADOW
                    half3 finalcolor = lerp(_ShadowColor.rgb* baseMap.rgb , baseMap.rgb , sdf)+ specularColor+ rimColor;
                #else
                    half3 finalcolor = baseMap.rgb * halflambert+ specularColor+ rimColor;
                #endif

                finalcolor = lerp(finalcolor, finalcolor*_FaceFlushColor.rgb, flushStrength);
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
