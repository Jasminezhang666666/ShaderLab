Shader "shader lab/week 2/shapes" {
    SubShader {
        Tags {"RenderPipeline" = "UniversalPipeline"}
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.uv = v.uv;
                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                float2 uv = i.uv * 2 - 1;
                float shape = 0;

                // circle
                // float radius = 0.5;
                // float distance = length(uv);
                // // distance -= radius;
                // float cutoff = 1-step(radius, distance);
                //
                // float aa = 0.01;
                // cutoff = smoothstep(0, aa, distance);

                // shape = cutoff;
                

                // rectangle
                float2 hSize = float2(0.5, 0.5);
                float leftSide = step(-hSize.x, uv.x);
                float bottomEdge = step(-hSize.y, uv.y);
                float rightSide = 1-step(hSize.x, uv.x);
                float topEdge = 1-step(hSize.y, uv.y);
                
                shape = leftSide * bottomEdge * rightSide * topEdge;



                // right triangle
                float s = 0.5;
                float h = step(uv.y, uv.x);
                float bottom = step(-s, uv.y);
                float right = 1-step(s, uv.x);
                shape = h * bottom * right;
                
                return float4(shape.rrr, 1.0);
            }
            ENDHLSL
        }
    }
}
