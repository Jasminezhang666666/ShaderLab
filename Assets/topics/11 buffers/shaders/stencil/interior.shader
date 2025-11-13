Shader "shader lab/week 11/interior" {
    Properties {
        _colorA ("color a", Color) = (1, 1, 1, 1)
        _colorB ("color b", Color) = (1, 1, 1, 1)
        _cubeMap ("cube map", Cube) = "white" {}
    }

    SubShader {
        Tags {
            "RenderPipeline" = "UniversalPipeline"
            "Queue" = "Geometry"
        }
        
        
        
        // nothing new below
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            
            #define TAU 6.283185307

            CBUFFER_START(UnityPerMaterial)
            float3 _colorA;
            float3 _colorB;
            CBUFFER_END

            TEXTURECUBE(_cubeMap);
            SAMPLER(sampler_cubeMap);

            struct MeshData {
                float4 vertex : POSITION;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float3 objPos : TEXCOORD1;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.objPos = v.vertex.xyz;
                o.vertex = TransformObjectToHClip(v.vertex);
                
                return o;
            }

            float get_luminance (float3 color) {
                float3 channelWeight = float3(0.2126, 0.7152, 0.0722);
                return dot(color, channelWeight);
            }

            float4 frag (Interpolators i) : SV_Target {
                
                float3 cube = SAMPLE_TEXTURECUBE(_cubeMap, sampler_cubeMap, i.objPos);
                float luminance = get_luminance(cube);
                int steps = 12;
                luminance = floor(luminance * steps) / steps;
                float3 color = lerp(_colorA, _colorB, luminance);
                
                // color = cube;
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}