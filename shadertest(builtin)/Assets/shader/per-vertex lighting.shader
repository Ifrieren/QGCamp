// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/per-vertex lighting"
{
    Properties
    {
        _Color("Color Tint", Color)=(1,1,1,1)
        _Diffuse("Diffuse", Color)=(1,1,1,1)

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
            fixed4 _Color;
            fixed4 _Diffuse;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord :TEXCOORD;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                fixed3 color : COLOR0;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                fixed3 ambient =UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 worldNormal = normalize(mul(v.normal,(float3x3)unity_WorldToObject));
                fixed3 worldLight = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 diffuse = _LightColor0.rgb*_Diffuse.rgb*
                saturate(dot(worldNormal,worldLight));
                o.color = ambient + diffuse;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                return fixed4(i.color*_Color.rgb,1);
            }
            ENDCG
        }
        
    }
    FallBack "Diffuse"
}
