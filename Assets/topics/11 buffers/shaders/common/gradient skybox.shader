Shader "shader lab/week 11/gradient skybox" {
    Properties {
        _colorHigh ("color high", Color) = (1, 1, 1, 1)
        _colorLow ("color low", Color) = (0, 0, 0, 1)
        _offset ("offset", Range(0, 1)) = 0
        _contrast ("contrast", Float) = 1
    }

    SubShader {
        // these tags tell unity to render the skybox in the right queue order
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue"="Background"
            "RenderType"="Background"
            "PreviewType"="Skybox"
        }
        
        Cull Off
        ZWrite Off

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float3 _colorHigh;
            float3 _colorLow;
            float _offset;
            float _contrast;
            CBUFFER_END

            struct MeshData {
                float4 vertex : POSITION;
                float3 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float3 uv : TEXCOORD0;

                // using world position to show that uvs of the mesh are a vector containing world position or view direction data
                float3 worldPos : TEXCOORD1;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);

                // just demonstrating what uv data is being used for in the skybox
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;
                // need to normalize vector after interpolation
                // change range from -1 to 1 into 0 to 1
                float3 coord = normalize(i.uv) * 0.5 + 0.5;
                // coord = normalize(i.worldPos);
                
                color = lerp(_colorLow, _colorHigh, smoothstep(0, 1, pow(coord.y + _offset, _contrast)));
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}