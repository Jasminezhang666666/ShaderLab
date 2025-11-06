Shader "HW9_Ball_ChromeCandy"
{
    Properties
    {
        [NoScaleOffset]_IBL ("IBL cubemap", Cube) = "black" {}
        _Reflectivity ("Reflectivity", Range(0,1)) = 0.95
        _Roughness    ("Roughness", Range(0,1)) = 0.15
        _FresnelPower ("Fresnel Power", Range(0,10)) = 5
    }

    SubShader
    {
        Tags { "RenderPipeline"="UniversalPipeline" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define SPECULAR_MIP_STEPS 4

            CBUFFER_START(UnityPerMaterial)
            float _Reflectivity, _Roughness, _FresnelPower;
            CBUFFER_END

            TEXTURECUBE(_IBL); SAMPLER(sampler_IBL);

            struct VIn  { float4 vertex:POSITION; float3 normal:NORMAL; };
            struct VOut { float4 pos:SV_POSITION; float3 nWS:TEXCOORD0; float3 wpos:TEXCOORD1; };

            // minimal vertex: just build world-space normal/position
            VOut vert (VIn v)
            {
                VOut o;
                o.pos  = TransformObjectToHClip(v.vertex);
                o.nWS  = TransformObjectToWorldNormal(v.normal);
                o.wpos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            // chrome look: image-based reflection and fresnel-weighted intensity
            float4 frag (VOut i) : SV_Target
            {
                float3 N = normalize(i.nWS);
                float3 V = normalize(GetCameraPositionWS() - i.wpos);
                float3 R = reflect(-V, N);

                // roughness -> pick blurrier mip
                float gloss = 1.0 - _Roughness;
                float mip   = (1.0 - gloss) * SPECULAR_MIP_STEPS;
                float3 refl = SAMPLE_TEXTURECUBE_LOD(_IBL, sampler_IBL, R, mip);

                // fresnel so edges pop; faces a bit dimmer
                float fres  = pow(1.0 - saturate(dot(V, N)), _FresnelPower);

                // final reflected color
                float3 color = refl * lerp(_Reflectivity * 0.6, _Reflectivity, fres);
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}
