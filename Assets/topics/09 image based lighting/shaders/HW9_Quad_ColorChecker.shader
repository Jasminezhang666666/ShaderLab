Shader "HW9_Quad_ColorChecker"
{
    Properties
    {
        [NoScaleOffset]_IBL("IBL cubemap", Cube) = "black" {}
        _Scale   ("Tile Scale", Range(0.2,6)) = 2.0
        _Skew    ("Diagonal Skew", Range(-1,1)) = 0.25
        _Mix     ("IBL Mix", Range(0,1)) = 0.25
        _Col1 ("Color 1", Color) = (0.95,0.2,0.7,1)
        _Col2 ("Color 2", Color) = (0.15,0.25,0.9,1)
        _Col3 ("Color 3", Color) = (0.1,0.9,0.8,1)
    }

    SubShader
    {
        Tags{ "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #define DIFFUSE_MIP_LEVEL 5

            CBUFFER_START(UnityPerMaterial)
            float4 _Col1,_Col2,_Col3; float _Scale,_Skew,_Mix;
            CBUFFER_END

            TEXTURECUBE(_IBL); SAMPLER(sampler_IBL);

            struct VIn{ float4 vertex:POSITION; float3 normal:NORMAL; };
            struct VOut{ float4 pos:SV_POSITION; float3 wpos:TEXCOORD0; float3 nWS:TEXCOORD1; };

            VOut vert(VIn v){ VOut o; o.pos=TransformObjectToHClip(v.vertex);
                o.wpos=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.nWS=TransformObjectToWorldNormal(v.normal); return o; }

            float4 frag(VOut i):SV_Target
            {
                // world-space uv with optional diagonal skew
                float2 uv=float2(i.wpos.x + i.wpos.z*_Skew, i.wpos.z - i.wpos.x*_Skew) * _Scale;

                // checker via sign of sin() (softened)
                float cx = sin(uv.x*3.14159);
                float cy = sin(uv.y*3.14159);
                float checker = cx*cy; // -1..1
                float m = smoothstep(-0.2,0.2, checker); // soft edges

                float3 baseCol = lerp(_Col1.rgb, _Col2.rgb, m);
                // subtle gradient shift across world height for poster look
                float g = saturate((i.wpos.y+2.0)/4.0);
                baseCol = lerp(baseCol, _Col3.rgb, g*0.35);

                float3 ibl = SAMPLE_TEXTURECUBE_LOD(_IBL,sampler_IBL,normalize(i.nWS),DIFFUSE_MIP_LEVEL);
                float3 color = lerp(baseCol, baseCol*ibl, _Mix);
                return float4(color,1);
            }
            ENDHLSL
        }
    }
}
