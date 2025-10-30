Shader "shader lab/week 7/half lambert" {
    Properties {
        _surfaceColor ("surface color", Color) = (0.4, 0.1, 0.9)
    }
    SubShader {
        Tags {"RenderPipeline" = "UniversalPipeline"}
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            
            CBUFFER_START(UnityPerMaterial)
            float3 _surfaceColor;
            CBUFFER_END

            struct MeshData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.normal = TransformObjectToWorldNormal(v.normal);
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 normal = normalize(i.normal);
                float3 color = 0;

                Light light = GetMainLight();
                float falloff = max(0, dot(normal, light.direction));

                float halfLambert = pow(falloff * 0.5 + 0.5, 2);
                
                color = halfLambert * _surfaceColor * light.color;

                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}