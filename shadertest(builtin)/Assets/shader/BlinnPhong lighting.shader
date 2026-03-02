// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/SpecularPerPixel lighting"
{
    Properties
    {
        _Diffuse ("Color", Color) = (1,1,1,1)
        _Specular ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(8,256)) = 20

    }
    SubShader
    {
        

        Pass
        {
            Tags{"LightMode"="ForwardBase"}
            CGPROGRAM
            #pragma vertex vert 
            #pragma fragment frag 
            #include "UnityCG.cginc"
            #include "Lighting.cginc"
            fixed4 _Diffuse;
            fixed4 _Specular;
            fixed _Gloss;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord :TEXCOORD;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldNormal = mul(v.normal,(float3x3)unity_WorldToObject);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 ambient =UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 diffuse = _LightColor0.rgb*_Diffuse.rgb*
                saturate(dot(worldNormal,worldLight));

                fixed3 reflectDir= normalize(reflect(-worldLight,worldNormal));
                fixed3 viewDir=normalize(_WorldSpaceCameraPos.xyz
                -i.worldPos.xyz);
                fixed3 halfDir=normalize(worldLight+viewDir);

                fixed3 specular =_LightColor0.rgb * _Specular.rgb*
                pow(max(0,saturate(dot(reflectDir,halfDir))) , _Gloss);

                fixed3 color = ambient + diffuse + specular;

                return fixed4(color,1);
            }
            ENDCG
        }
        
    }
    FallBack "Diffuse"
}
