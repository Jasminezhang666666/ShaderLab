Shader "shader lab/week 11/skeletonXRay_HW11"
{
    Properties
    {
        _boneColor  ("bone color", Color) = (0.9, 0.9, 1.0, 1)
        _emission   ("emission", Range(0, 10)) = 3
        _alpha      ("alpha", Range(0,1)) = 0.6
        _stencilRef ("stencil reference", Int) = 2
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue"          = "Transparent"
        }

        ZWrite Off
        ZTest Always
        Blend SrcAlpha OneMinusSrcAlpha

        Stencil
        {
            Ref      [_stencilRef]   // 2
            Comp     Equal
            ReadMask 2               // only bit 1
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _boneColor;
            float  _emission;
            float  _alpha;
            CBUFFER_END

            struct MeshData
            {
                float4 vertex : POSITION;
            };

            struct Interpolators
            {
                float4 vertex : SV_POSITION;
            };

            Interpolators vert (MeshData v)
            {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                return o;
            }

            float4 frag (Interpolators i) : SV_Target
            {
                float3 color = _boneColor.rgb * _emission;
                return float4(color, _alpha);
            }
            ENDHLSL
        }
    }
}
