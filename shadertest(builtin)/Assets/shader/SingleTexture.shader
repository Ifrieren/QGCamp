// Upgrade NOTE: replaced '_World2Object' with 'unity_WorldToObject'

// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

Shader "Custom/SingleTexture"
{
    Properties
    {
        _Diffuse ("Color", Color) = (1,1,1,1)
        _Specular ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(8,256)) = 20
        _MainTex("Main Tex",2D)="white"{}
        _Color("Color Tint",color)=(1,1,1,1)
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
            float4 _Color;
            float4 _MainTex_ST;
            sampler2D _MainTex;

            struct appdata {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float4 texcoord :TEXCOORD0;
            };

            struct v2f {
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD0;
                float3 worldPos : TEXCOORD1;
                float2 uv : TEXCOORD2;
            };

            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                //o.worldNormal = mul(v.normal,(float3x3)unity_WorldToObject);
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld,v.vertex).xyz;
                o.uv = TRANSFORM_TEX(v.texcoord , _MainTex);  
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLight = normalize(UnityWorldSpaceLightDir(i.worldPos));
                

                fixed3 albedo = tex2D(_MainTex, i.uv).rgb * _Color.rgb;
                fixed3 ambient =UNITY_LIGHTMODEL_AMBIENT.xyz * albedo;

                fixed3 diffuse = _LightColor0.rgb*_Diffuse.rgb*albedo*
                saturate(dot(worldNormal,worldLight));
                fixed3 reflectDir= normalize(reflect(-worldLight,worldNormal));
                fixed3 viewDir=normalize(UnityWorldSpaceViewDir(i.worldPos));
                fixed3 specular =_LightColor0.rgb * _Specular.rgb*
                pow(saturate(dot(reflectDir,viewDir)) , _Gloss);

                fixed3 color = ambient + diffuse + specular;

                return fixed4(color,1);
            }
            ENDCG
        }
        
    }
    FallBack "Specular"
}
