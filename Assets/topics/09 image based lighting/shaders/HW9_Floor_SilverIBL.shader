Shader "HW9_Floor_SilverIBL"
{
    Properties
    {
        [NoScaleOffset]_IBL ("IBL cubemap", Cube) = "black" {}
        _BaseTint   ("Base Tint (very subtle)", Color) = (0.5,0.5,0.55,1)
        _Reflectivity ("Reflectivity", Range(0,1)) = 0.95
        _Gloss      ("Gloss (sharpness)", Range(0,1)) = 0.98

        // Soft world-space chevron tint (set strength to 0 to disable)
        _ChevronA   ("Chevron Color A", Color) = (0.8,0.2,1.0,1)
        _ChevronB   ("Chevron Color B", Color) = (0.1,0.6,1.0,1)
        _ChevronFreq("Chevron Frequency", Range(0.05,2)) = 0.2
        _ChevronMix ("Chevron Mix", Range(0,1)) = 0.35
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
            float4 _BaseTint, _ChevronA, _ChevronB;
            float  _Reflectivity, _Gloss, _ChevronFreq, _ChevronMix;
            CBUFFER_END

            TEXTURECUBE(_IBL); SAMPLER(sampler_IBL);

            struct VIn { float4 vertex:POSITION; float3 normal:NORMAL; };
            struct VOut{ float4 pos:SV_POSITION; float3 nWS:TEXCOORD0; float3 wpos:TEXCOORD1; };

            VOut vert(VIn v){
                VOut o; o.pos=TransformObjectToHClip(v.vertex);
                o.nWS=TransformObjectToWorldNormal(v.normal);
                o.wpos=mul(unity_ObjectToWorld,v.vertex).xyz; return o;
            }

            float4 frag(VOut i):SV_Target
            {
                float3 N=normalize(i.nWS);
                float3 V=normalize(GetCameraPositionWS()-i.wpos);
                float3 R=reflect(-V,N);

                float mip=(1-_Gloss)*SPECULAR_MIP_STEPS;
                float3 refl=SAMPLE_TEXTURECUBE_LOD(_IBL,sampler_IBL,R,mip);

                // World-space chevron tint to echo printed posters
                float s = abs(frac((i.wpos.x+i.wpos.z)*_ChevronFreq)-0.5);
                float chevron = smoothstep(0.2,0.0,s); // thin bands
                float3 tint = lerp(_ChevronA.rgb,_ChevronB.rgb, chevron);

                float3 color = lerp(_BaseTint.rgb, refl, _Reflectivity);
                color = lerp(color, color*tint, _ChevronMix);

                return float4(color,1);
            }
            ENDHLSL
        }
    }
}
