Shader "shader lab/week 11/window" {
    Properties {
        
    }

    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
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