Shader "HW9_Ball_PearlPlastic"
{
    Properties
    {
        _Albedo  ("Albedo", Color) = (0.9,0.2,0.3,1)
        [NoScaleOffset]_IBL("IBL cubemap", Cube) = "black" {}
        _Gloss   ("Gloss (direct spec)", Range(0,1)) = 0.6
        _CoatReflect ("Coat Reflectivity", Range(0,1)) = 0.35
        _CoatRough   ("Coat Roughness", Range(0,1)) = 0.25
        _FresnelPower("Fresnel Power", Range(0,10)) = 4
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
            #define MAX_SPECULAR_POWER 256
            #define SPECULAR_MIP_STEPS 4

            CBUFFER_START(UnityPerMaterial)
            float4 _Albedo; float _Gloss,_CoatReflect,_CoatRough,_FresnelPower;
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
                Light L=GetMainLight();
                float3 H=normalize(V+L.direction);

                // Direct
                float diff = max(0,dot(N,L.direction));
                float spec = pow(max(0,dot(N,H)), _Gloss * MAX_SPECULAR_POWER + 1) * _Gloss;

                // Diffuse IBL
                float3 iblDiffuse = SAMPLE_TEXTURECUBE_LOD(_IBL,sampler_IBL,N,DIFFUSE_MIP_LEVEL);

                float3 base = _Albedo.rgb * (diff*L.color + iblDiffuse) + spec*L.color;

                // Clearcoat reflection
                float3 R=reflect(-V,N);
                float mip=_CoatRough * SPECULAR_MIP_STEPS;
                float3 coat = SAMPLE_TEXTURECUBE_LOD(_IBL,sampler_IBL,R,mip);
                float fres = pow(1 - saturate(dot(V,N)), _FresnelPower);

                float3 color = base + coat * (_CoatReflect * fres);
                return float4(color,1);
            }
            ENDHLSL
        }
    }
}
