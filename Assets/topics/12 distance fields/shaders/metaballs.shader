Shader "shader lab/week 12/metaballs" {
    Properties {
        _smoothness ("shape blend smoothness", Range(0.001, 1)) = 0.2
    }
    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define MAX_STEPS 100
            #define MAX_DIST 10
            #define MIN_DIST 0.001

            CBUFFER_START(UnityPerMaterial)
            float _smoothness;
            CBUFFER_END
            
            struct MeshData {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 hitPos : TEXCOORD1;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex);
                o.hitPos = mul(unity_ObjectToWorld, v.vertex);
                o.uv = v.uv;
                return o;
            }

            float sdf_sphere (float3 spherePos, float radius, float3 pos) {
                return distance(spherePos, pos) - radius;
            }
            
            // https://iquilezles.org/www/articles/smin/smin.htm
            // a substitute for our min function that smoothly blends primitives together
            // when float a and b are far apart nothing changes
            // when a and b are close, then the distance is smoothly blended between them
            float smin ( float a, float b) {
                // k is smoothness factor
                float s = _smoothness;
                float k = s;
                float h = max( k-abs(a-b), 0.0 )/k;
                return min( a, b ) - h*h*h*k*(1.0/6.0);
            }

            float get_dist (float3 pos) {
                // this defines the scene

                float t = _Time.y;
                float s1 = sdf_sphere(float3(sin(t), -cos(t), 0) * 0.8, 0.75, pos);
                float s2 = sdf_sphere(float3(0, -sin(t), cos(t)) * 0.7, 0.60, pos);
                float s3 = sdf_sphere(pow(float3(-cos(t), sin(t), cos(t)), 5) * 0.5, 0.5, pos);
                
                return smin(smin(s1, s2), s3);
            }

            float ray_march (float3 rayOrigin, float3 rayDir) {
                // keep track of the total distance we've traveled
                float marchDist = 0;

                for(int i = 0; i < MAX_STEPS; i++) {
                    // our current position
                    float3 pos = rayOrigin + rayDir * marchDist;

                    // our current distance to the closest point in the scene
                    float distToSurf = get_dist(pos);

                    // add this distance to our accumulated march distance
                    marchDist += distToSurf;

                    // break out of loop if we are at the surface or go too far
                    if (distToSurf < MIN_DIST || marchDist > MAX_DIST) break;
                }

                return marchDist;
            }

            float4 frag (Interpolators i) : SV_Target {
                float3 color = 0;

                float3 camPos = _WorldSpaceCameraPos;
                float3 rayDir = normalize(i.hitPos - camPos);
                float d = ray_march(camPos, rayDir);

                // shade the surfaces based on the percent distance between 0 and our MAX_DIST
                float depth = 1-(d / MAX_DIST);
                
                color = depth.rrr;
                return float4(color, 1.0);
            }
            ENDHLSL
        }
    }
}