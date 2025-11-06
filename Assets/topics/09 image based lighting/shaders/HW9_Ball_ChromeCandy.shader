Shader "HW9_Ball_ChromeCandy"
{
    Properties
    {
        [NoScaleOffset]_IBL ("IBL cubemap", Cube) = "black" {}
        _Reflectivity ("Reflectivity", Range(0,1)) = 0.95
        _Roughness    ("Roughness", Range(0,1)) = 0.15
        _FresnelPower ("Fresnel Power", Range(0,10)) = 5

        // airbrush tint
        _TintLow  ("Tint Low (down)", Color) = (1.0,0.5,0.8,1)
        _TintHigh ("Tint High (up)",  Color) = (1.0,0.8,0.3,1)
        _TintMix  ("Tint Mix", Range(0,1)) = 0.5
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

            #define SPECULAR_MIP_STEPS 4

            CBUFFER_START(UnityPerMaterial)
            float4 _TintLow, _TintHigh;
            float _Reflectivity,_Roughness,_FresnelPower,_TintMix;
            CBUFFER_END

            TEXTURECUBE(_IBL); SAMPLER(sampler_IBL);

            struct VIn { float4 vertex:POSITION; float3 normal:NORMAL; };
            struct VOut{ float4 pos:SV_POSITION; float3 nWS:TEXCOORD0; float3 wpos:TEXCOORD1; };

            VOut vert(VIn v){ VOut o; o.pos=TransformObjectToHClip(v.vertex);
                o.nWS=TransformObjectToWorldNormal(v.normal);
                o.wpos=mul(unity_ObjectToWorld,v.vertex).xyz; return o; }

            float4 frag(VOut i):SV_Target
            {
                float3 N=normalize(i.nWS);
                float3 V=normalize(GetCameraPositionWS()-i.wpos);
                float3 R=reflect(-V,N);

                float gloss = 1 - _Roughness;
                float mip=(1-gloss)*SPECULAR_MIP_STEPS;
                float3 refl=SAMPLE_TEXTURECUBE_LOD(_IBL,sampler_IBL,R,mip);

                float fres = pow(1 - saturate(dot(V,N)), _FresnelPower);
                float3 tint = lerp(_TintLow.rgb, _TintHigh.rgb, saturate(N.y*0.5+0.5));
                float3 color = refl * lerp(_Reflectivity*0.7, _Reflectivity, fres);

                // airbrush tint mainly in highlights
                color = lerp(color, color*tint, _TintMix*0.6*fres);

                return float4(color,1);
            }
            ENDHLSL
        }
    }
}
