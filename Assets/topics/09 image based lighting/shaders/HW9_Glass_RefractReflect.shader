Shader "HW9_Glass_RefractReflect"
{
    Properties
    {
        [NoScaleOffset]_IBL ("IBL cubemap", Cube) = "black" {}
        _Tint       ("Glass Tint", Color) = (0.9,1.0,1.1,1)
        _Opacity    ("Opacity", Range(0,1)) = 0.25
        _Refraction ("Refraction Strength", Range(0,0.2)) = 0.06
        _Gloss      ("Reflection Gloss", Range(0,1)) = 0.95
        _Reflectivity("Reflectivity", Range(0,1)) = 0.6
    }

    SubShader
    {
        Tags{ "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "IgnoreProjector"="True" }
        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            #define SPECULAR_MIP_STEPS 4

            CBUFFER_START(UnityPerMaterial)
            float4 _Tint; float _Opacity,_Refraction,_Gloss,_Reflectivity;
            CBUFFER_END

            TEXTURECUBE(_IBL); SAMPLER(sampler_IBL);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);

            struct VIn { float4 vertex:POSITION; float3 normal:NORMAL; };
            struct VOut{ float4 pos:SV_POSITION; float3 nWS:TEXCOORD0; float3 wpos:TEXCOORD1; float4 sp:TEXCOORD2; };

            VOut vert(VIn v){ VOut o; o.pos=TransformObjectToHClip(v.vertex);
                o.nWS=TransformObjectToWorldNormal(v.normal);
                o.wpos=mul(unity_ObjectToWorld,v.vertex).xyz;
                o.sp=ComputeScreenPos(o.pos); return o; }

            float4 frag(VOut i):SV_Target
            {
                float3 N=normalize(i.nWS);
                float3 V=normalize(GetCameraPositionWS()-i.wpos);

                // Screen-space refraction
                float2 suv = i.sp.xy/i.sp.w + N.xy * _Refraction;
                float3 behind = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, suv).rgb;

                // IBL reflection
                float3 R=reflect(-V,N);
                float3 refl=SAMPLE_TEXTURECUBE_LOD(_IBL,sampler_IBL,R,(1-_Gloss)*SPECULAR_MIP_STEPS);

                float3 color = lerp(behind*_Tint.rgb, refl, _Reflectivity);
                // Thin glass: mix with opacity (premult-like)
                return float4(color, _Opacity);
            }
            ENDHLSL
        }
    }
}
