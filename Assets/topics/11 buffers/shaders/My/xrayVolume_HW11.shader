Shader "shader lab/week 11/xrayVolume_HW11"
{
    Properties
    {
        _stencilRef ("stencil reference", Int) = 2
        _Color      ("Color", Color) = (0, 1, 1, 0.3)
    }

    SubShader
    {
        Tags
        {
            "RenderPipeline" = "UniversalPipeline"
            "Queue"          = "Transparent"   // can see through it
        }

        ZWrite Off
        ZTest LEqual
        Blend SrcAlpha OneMinusSrcAlpha     // translucent object (knife)

        Stencil
        {
            Ref       [_stencilRef]   // 2 -> 0000 0010
            Comp      Always
            Pass      Replace
            WriteMask 2               // only touch bit 1 (doesn't kill portal)
        }

        Pass
        {
            HLSLPROGRAM
            #pragma vertex   vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
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
                return _Color;
            }
            ENDHLSL
        }
    }
}
