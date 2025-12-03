Shader "HW9_Quad_ColorLines"
{
    Properties
    {
        [NoScaleOffset]_IBL("IBL cubemap", Cube) = "black" {}
        _LineFreq ("Line Frequency", Range(0.2,8)) = 2.5
        _Scroll   ("Scroll Speed", Range(-4,4)) = 0.6
        _Mix      ("IBL Mix", Range(0,1)) = 0.3
        _A ("Color A", Color) = (1,0.4,0.2,1)
        _B ("Color B", Color) = (0.2,0.6,1,1)
        _C ("Color C", Color) = (1,1,0.3,1)
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
            float4 _A,_B,_C; float _LineFreq,_Scroll,_Mix;
            CBUFFER_END

            TEXTURECUBE(_IBL); SAMPLER(sampler_IBL);

            struct VIn{ float4 vertex:POSITION; float3 normal:NORMAL; };
            struct VOut{ float4 pos:SV_POSITION; float3 wpos:TEXCOORD0; float3 nWS:TEXCOORD1; };

            VOut vert(VIn v){ VOut o; o.pos=TransformObjectToHClip(v.vertex);
                o.wpos=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.nWS=TransformObjectToWorldNormal(v.normal); return o; }

            float4 frag(VOut i):SV_Target
            {
                // world-space lines along XZ, animated along Z
                float t = i.wpos.x * _LineFreq + i.wpos.z * _LineFreq + _Time.y*_Scroll;
                float s = sin(t);
                float3 lineCol = lerp(_A.rgb, _B.rgb, saturate(s*0.5+0.5));
                // add a second harmonic for neon accents
                float s2 = sin(t*2.0 + 1.57);
                lineCol = lerp(lineCol, _C.rgb, saturate(s2*0.5+0.5)*0.4);

                // subtle IBL to seat it in the world
                float3 ibl = SAMPLE_TEXTURECUBE_LOD(_IBL,sampler_IBL,normalize(i.nWS),DIFFUSE_MIP_LEVEL);
                float3 color = lerp(lineCol, lineCol*ibl, _Mix);
                return float4(color,1);
            }
            ENDHLSL
        }
    }
}
