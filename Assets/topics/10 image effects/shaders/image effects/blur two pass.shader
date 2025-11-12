Shader "shader lab/week 10/two pass blur" {
    Properties {
        _blurSize ("blur size", float) = 1
    }
    SubShader {
        Tags { "RenderPipeline"="UniversalPipeline" }
        
        Cull Off
        ZWrite Off
        ZTest Always
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float _blurSize;
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
            o.uv    = GetFullScreenTriangleTexCoord(v.vertexID);
            return o;
        }
        ENDHLSL
        
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            float4 frag (Interpolators i) : SV_Target {
                half4 sum = 0;

                #define GRABPIXEL(weight, kernelx) SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, float2(i.uv.x + _BlitTexture_TexelSize.x * kernelx * _blurSize, i.uv.y)) * weight;

                sum += GRABPIXEL(0.05, -4.0);
                sum += GRABPIXEL(0.09, -3.0);
                sum += GRABPIXEL(0.12, -2.0);
                sum += GRABPIXEL(0.15, -1.0);
                sum += GRABPIXEL(0.18,  0.0);
                sum += GRABPIXEL(0.15,  1.0);
                sum += GRABPIXEL(0.12,  2.0);
                sum += GRABPIXEL(0.09,  3.0);
                sum += GRABPIXEL(0.05,  4.0);
                
				return sum;
            }
            ENDHLSL
        }

        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            float4 frag (Interpolators i) : SV_Target {
                half4 sum = 0;

                #define GRABPIXEL(weight, kernely) SAMPLE_TEXTURE2D(_BlitTexture, sampler_BlitTexture, float2(i.uv.x, i.uv.y + _BlitTexture_TexelSize.y * kernely * _blurSize)) * weight;

                sum += GRABPIXEL(0.05, -4.0);
                sum += GRABPIXEL(0.09, -3.0);
                sum += GRABPIXEL(0.12, -2.0);
                sum += GRABPIXEL(0.15, -1.0);
                sum += GRABPIXEL(0.18,  0.0);
                sum += GRABPIXEL(0.15,  1.0);
                sum += GRABPIXEL(0.12,  2.0);
                sum += GRABPIXEL(0.09,  3.0);
                sum += GRABPIXEL(0.05,  4.0);
                
				return sum;
            }
            ENDHLSL
        }
    }
}