Shader "shader lab/week 9/cubemap skybox" {
    Properties {
       
    }

    SubShader {
        // these tags tell unity to render the skybox in the right queue order
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Background"
            "RenderType" = "Background"
            "PreviewType" = "Skybox"
        }
        
        Cull Off
        ZWrite Off

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
                float3 color = 0;
                

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}