Shader "shader lab/week 8/transparency" {
    Properties {
        _color ("color", Color) = (1, 1, 1, 1)
    }
    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Transparent"
            "IgnoreProjector" = "True"
        }
        
        ZWrite Off
        
        // source = this shader's color output
        // destination = the color in the frame buffer
        // final color = srcColor * srcFactor + dstColor * dstFactor
        // final color = (this shader's color * this shader's alpha output) + (frame buffer color * (1 - this shader's alpha output))
        // additive: final color = srcColor + dstColor
        Blend SrcAlpha OneMinusSrcAlpha // alpha blending
//        Blend One One // additive blending
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _color;
            CBUFFER_END

            struct MeshData {
                float4 vertex : POSITION;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                return _color;
            }
            ENDHLSL
        }
    }
}