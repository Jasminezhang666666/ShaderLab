Shader "HW9_Glass_RefractReflect"
{
    Properties {
        [NoScaleOffset]_IBL("IBL cubemap", Cube) = "black" {}
        _Tint       ("Glass Tint", Color) = (1,0.6,0.5,1)
        _Opacity    ("Opacity", Range(0,1)) = 0.28
        _RefractStr ("Refraction Strength", Range(0,0.1)) = 0.04
        _ReflGloss  ("Reflection Gloss", Range(0,1)) = 0.92
        _Reflect    ("Reflectivity", Range(0,1)) = 0.75
        _F0Power    ("Fresnel Power", Range(0,8)) = 4
    }
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" "Queue"="Transparent" "IgnoreProjector"="True" }
        Cull Back
        ZWrite Off
        Pass {
            Blend SrcAlpha OneMinusSrcAlpha
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #define SPEC_MIP_STEPS 4

            CBUFFER_START(UnityPerMaterial)
            float4 _Tint;
            float  _Opacity, _RefractStr, _ReflGloss, _Reflect, _F0Power;
            CBUFFER_END

            TEXTURECUBE(_IBL); SAMPLER(sampler_IBL);
            TEXTURE2D(_CameraOpaqueTexture); SAMPLER(sampler_CameraOpaqueTexture);

            struct VIn  { float4 pos:POSITION; float3 n:NORMAL; };
            struct VOut { float4 pos:SV_POSITION; float3 nWS:TEXCOORD0; float3 wpos:TEXCOORD1; float4 sp:TEXCOORD2; };

            VOut vert(VIn v){
                VOut o;
                o.pos   = TransformObjectToHClip(v.pos);
                o.nWS   = TransformObjectToWorldNormal(v.n);
                o.wpos  = mul(unity_ObjectToWorld, v.pos);
                o.sp    = ComputeScreenPos(o.pos);
                return o;
            }

            float4 frag(VOut i):SV_Target{
                float3 N = normalize(i.nWS);
                float3 V = normalize(GetCameraPositionWS() - i.wpos);

                // screen refraction
                float2 uv = i.sp.xy / i.sp.w;
                float2 refrUV = uv + N.xy * _RefractStr;
                float3 refr = SAMPLE_TEXTURE2D(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, refrUV);

                // IBL reflection
                float3 R = reflect(-V, N);
                float  mip = (1 - _ReflGloss) * SPEC_MIP_STEPS;
                float3 refl = SAMPLE_TEXTURECUBE_LOD(_IBL, sampler_IBL, R, mip);

                // Fresnel mix (edges reflect, faces refract)
                float F = pow(1.0 - saturate(dot(V,N)), _F0Power);
                float3 col = lerp(refr * _Tint.rgb, refl, F * _Reflect);

                // final transparency
                float alpha = saturate(_Opacity + F*0.15); // edges a bit thicker
                return float4(col, alpha);
            }
            ENDHLSL
        }
    }
}
