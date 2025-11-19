Shader "shader lab/week 11/window" {
    Properties {
        _stencilRef ("stencil reference", Int) = 1
    }

    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry-1" // geometry = 2000
        }
        
        ZWrite Off
        ColorMask 0
        
        Stencil {
            Ref [_stencilRef]
            Comp Always
            Pass Replace
        }
        
        // nothing new below
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

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
                return 0;
            }
            ENDHLSL
        }
    }
}