Shader "shader lab/week 10/kernels" {
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" }
        
        ZWrite Off
        Cull Off
        ZTest Always
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
            float4 _BlitTexture_TexelSize;
            CBUFFER_END

            TEXTURE2D(_BlitTexture);
            SAMPLER(sampler_BlitTexture);
            
            struct MeshData {
                uint vertexID : SV_VertexID;
            };
            
            struct Interpolators {
                float4 posCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.posCS = GetFullScreenTriangleVertexPosition(v.vertexID);
                o.uv    = GetFullScreenTriangleTexCoord   (v.vertexID);
                return o;
            }
            
            float3 convolution (float2 uv, float3x3 kernel) {
                float2 ts = _BlitTexture_TexelSize.xy;
                float3 result = 0;
                
                for(int x = -1; x <= 1; x++) {
                    for(int y = -1; y <= 1; y++) {
                        float2 offset = float2(x, y) * ts;
                        float3 sample = SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, uv + offset);
                        result += sample * kernel[x+1][y+1];
                    }
                }

                return result;
            }

            float3x3 boxBlurKernel() {
                return float3x3 (
                    // box
                    0.11, 0.11, 0.11,
                    0.11, 0.11, 0.11,
                    0.11, 0.11, 0.11
                );
            }

            float3x3 gaussianBlurKernel() {
                return float3x3 (
                    // gaussian
                    0.0625, 0.125, 0.0625,
                    0.1250, 0.250, 0.1250,
                    0.0625, 0.125, 0.0625
                );
            }

            float3x3 sharpenKernel() {
                return float3x3 (
                    // sharpen
                     0, -1,  0,
                    -1,  5, -1,
                     0, -1,  0
                );
            }

            float3x3 embossKernel() {
                return float3x3 (
                    // emboss
                    -2, -1,  0,
                    -1,  1,  1,
                     0,  1,  2
                );
            }

            float3x3 edgeDetectionKernel() {
                return float3x3 (
                    // edge detection (kind of a bad one. better edge detection using sobel requires two kernels, one for each x and y dimension)
                     1,  0, -1,
                     0,  0,  0,
                    -1,  0,  1
                );
            }
            
            float4 frag (Interpolators i) : SV_Target {
                float3 color = convolution(i.uv, embossKernel());
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}