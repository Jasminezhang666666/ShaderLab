Shader "shader lab/week 5/HW5" {
    Properties {
        _Radius         ("Sphere radius", Float) = 0.5
        _CycleSeconds   ("Loop cycle (seconds)", Range(1, 30)) = 6
        _FacetK         ("Faceting amount (2..30)", Range(2, 30)) = 9

        _SpikeScale     ("Spike noise scale", Range(1, 50)) = 18
        _SpikePower     ("Spike sharpness", Range(0.5, 8)) = 3.5
        _SpikeAmp       ("Spike amplitude", Range(0, 0.6)) = 0.25
        _SpikeHold ("Spike phase length multiplier", Range(1,5)) = 2.5

        _WaveFreq       ("Wave frequency", Range(0, 12)) = 5.0
        _WaveAmp        ("Wave amplitude factor", Range(0, 1)) = 0.5

        _BaseColor      ("Base Color", Color) = (0.17, 0.45, 0.95, 1)
        _SpikeColor     ("Spike Accent", Color) = (1.0, 0.7, 0.25, 1)
        _RimColor       ("Rim Color", Color) = (1,1,1,1)
        _RimPower       ("Rim Power", Range(0.1, 8)) = 2.2

        _GourdWaist     ("Gourd waist depth", Range(0, 0.7)) = 0.45
        _GourdSharpness ("Gourd waist sharpness", Range(1, 6)) = 3.0
        _GourdCap       ("Gourd cap pull", Range(0, 0.6)) = 0.25

    }

    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            CBUFFER_START(UnityPerMaterial)
             float  _Radius;
            float  _CycleSeconds; //total loop duration in seconds
            float  _FacetK;

            float  _SpikeScale;
            float  _SpikePower;
            float  _SpikeAmp;
            float _SpikeHold;

            float  _WaveFreq;
            float  _WaveAmp;

            float3 _BaseColor;
            float3 _SpikeColor;
            float3 _RimColor;
            float  _RimPower;

            float _GourdWaist; //how deep the pinch is
            float _GourdSharpness; //how narrow the waist band is
            float _GourdCap; //how much to tug the poles apart

            CBUFFER_END

             // ---------------- Helpers ----------------
            // Simple 2D hash -> value noise (like class)
            float rand(float2 uv) {
                return frac(sin(dot(uv, float2(12.9898,78.233))) * 43758.5453123);
            }

            float value_noise(float2 uv) {
                float2 ip = floor(uv);
                float2 f  = frac(uv);
                float a = rand(ip);
                float b = rand(ip + float2(1,0));
                float c = rand(ip + float2(0,1));
                float d = rand(ip + float2(1,1));
                float2 s = smoothstep(0,1,f);
                return lerp( lerp(a,b,s.x), lerp(c,d,s.x), s.y );
            }

            float fractal_noise(float2 uv) {
                float n = 0;
                n  = 0.5  * value_noise(uv * 1);
                n += 0.25 * value_noise(uv * 2);
                n += 0.125* value_noise(uv * 4);
                n += 0.0625*value_noise(uv * 8);
                return n;
            }

            //smooth morphs that accelerate and decelerate gently
            //instead of moving at a constant rate.
            float3 blend(float3 a, float3 b, float t) {
                return lerp(a, b, smoothstep(0.0, 1.0, t));
            }

            // Turn a smooth unit vector n into a coarsely quantized direction to fake flat, polygonal facets
            //Multiply by k (e.g., 9), round each component, divide back by k → snaps the vector to a 3D grid
            float3 facet_dir(float3 n, float k) {
                return normalize( round(n * k) / k ); //normalize(...) puts it back on the unit sphere.
            }

            struct MeshData {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                //float2 uv     : TEXCOORD0;
            };

            struct Interpolators {
                float4 vertex : SV_POSITION;
                float3 normal : TEXCOORD0;
                float  spike : TEXCOORD1; 
                float3 pos : TEXCOORD2;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;

                float3 p0 = v.vertex.xyz; // object-space position
                float3 dir = (length(p0) > 1e-5) ? normalize(p0)  // unit direction from origin
                                 : float3(0,0,1); // fallback to avoid /0

                // ----- Targets (5 “states”) -----
                // 0) Cube: original mesh
                float3 pCube = p0;

                // 1) Sphere: Push the vertex to the sphere at _Radius along its outward direction
                float3 pSphere = dir * _Radius;

                // 2) Faceted poly-sphere
                float3 fdir = facet_dir(dir, _FacetK);
                float3 pFacet = fdir * _Radius;

                // --- GOURD target (pinched waist + pulled caps) ---
                float y = dir.y; // use direction so it’s size-independent
                float a = abs(y);

                // waist: strongest at equator (a=0), fades to 0 at poles (a=1)
                //a = |y| is 0 at the equator and 1 at the poles
                //1 - a is 1 at the equator and 0 at the poles
                float waistProfile = pow(1.0 - a, _GourdSharpness);  //gives a lobe centered on the equator: _GourdSharpness > 1 narrows that lobe (sharper, skinnier waist band).
                float xzScale      = 1.0 - _GourdWaist * waistProfile; // <1 near equator, shrinks the horizontal axes (x and z) most strongly at the equator and fades to 0 shrink at the poles.
                //e.g. if _GourdWaist = 0.5, then at the equator xzScale = 0.5 (half width), and at the poles xzScale = 1.0 (no change).

                // caps: stretch along Y near the poles
                float capMask = smoothstep(0.5, 1.0, a);
                float yScale  = 1.0 + _GourdCap * capMask;
                //At a ≤ 0.5, capMask≈0 → no stretch.
                //As a→1, capMask→1, so that yScale → 1 + _GourdCap

                // apply per-axis scale
                float3 gdir   = float3(dir.x * xzScale, dir.y * yScale, dir.z * xzScale);
                float3 pGourd = gdir * _Radius;  // keep radial variation

                // 3) Sharp spikes (on the faceted sphere)
                //Project onto the horizontal plane (x, z), then normalize to a unit circle
                float2 d2raw = float2(dir.x, dir.z);
                float  d2len = max(length(d2raw), 1e-5);
                float2 d2    = d2raw / d2len; // safe normalize

                float nBase = fractal_noise(d2 * _SpikeScale);

                // Shape that noise to spikes: Higher power = rarer/brighter peaks → pointier spikes
                float spike = pow(saturate(nBase), _SpikePower) * _SpikeAmp;

                // 4) Wavy spikes (amplitude modulated over time)
                // Time-based wave that varies by direction (so different spikes sway differently)
                float phase = dot(dir, float3(3.1, 2.7, 4.0));
                float wave = 0.5 + 0.5 * sin(_WaveFreq * _Time.y + phase); //oscillates in [0,1]
                float spikeWavy = spike * lerp(1.0, 1.0 + _WaveAmp, wave); //smoothly scales spike height between 1× and (1+_WaveAmp)×

                // ----- 10 segments: cube→gourd→sphere→facet→sharp→wavy→sharp→facet→sphere→gourd→cube
                float w0 = 1.5;        // cube   -> gourd
                float w1 = 1.5;        // gourd  -> sphere
                float w2 = 1.0;        // sphere -> facet
                float w3 = 1.0;        // facet  -> sharp
                float w4 = _SpikeHold; // sharp  -> wavy   (linger)
                float w5 = _SpikeHold; // wavy   -> sharp  (linger)
                float w6 = 1.0;        // sharp  -> facet
                float w7 = 1.0;        // facet  -> sphere
                float w8 = 1.5;        // sphere -> gourd
                float w9 = 1.5;        // gourd  -> cube

                // loop time t in [0, W)
                float W  = w0+w1+w2+w3+w4+w5+w6+w7+w8+w9; //sum of time
                float t  = frac(_Time.y / max(_CycleSeconds, 0.01)) * W;

                // cumulative boundaries (in t-space)
                float b0=0.0;
                float b1=b0+w0, b2=b1+w1, b3=b2+w2, b4=b3+w3, b5=b4+w4;
                float b6=b5+w5, b7=b6+w6, b8=b7+w7, b9=b8+w8, b10=b9+w9;

                // start in the last 40% of the sphere->facet segment, finish by end of facet->sharp
                float gStart = lerp(b1, b2, 0.60); // 60% into sphere->facet
                float gEnd   = b4; // end of facet->sharp
                float u = (t - gStart) / max(gEnd - gStart, 1e-5); //remaps the current timeline t into a 0..1 ramp across that sub-interval
                float spikeGrow = smoothstep(0.0, 1.0, u);


                // build the spiky targets using the ramp
                //Before gStart, spikeGrow ≈ 0 → pSpike* ≈ pFacet (no spikes)
                //Between gStart and gEnd, spikes expand
                //After gEnd, spikeGrow ≈ 1 → spikes at full design height
                float3 pSpikeSharp = pFacet + fdir * (spike * spikeGrow);
                float3 pSpikeWavy  = pFacet + fdir * (spikeWavy * spikeGrow);

                // Find which segment and local 0..1 progress inside it
                float3 A, B;
                float segStart, segEnd;

                if      (t < b1)  { A=pCube;       B=pGourd;      segStart=b0;  segEnd=b1;  } // 0
                else if (t < b2)  { A=pGourd;      B=pSphere;     segStart=b1;  segEnd=b2;  } // 1
                else if (t < b3)  { A=pSphere;     B=pFacet;      segStart=b2;  segEnd=b3;  } // 2
                else if (t < b4)  { A=pFacet;      B=pSpikeSharp; segStart=b3;  segEnd=b4;  } // 3
                else if (t < b5)  { A=pSpikeSharp; B=pSpikeWavy;  segStart=b4;  segEnd=b5;  } // 4
                else if (t < b6)  { A=pSpikeWavy;  B=pSpikeSharp; segStart=b5;  segEnd=b6;  } // 5
                else if (t < b7)  { A=pSpikeSharp; B=pFacet;      segStart=b6;  segEnd=b7;  } // 6
                else if (t < b8)  { A=pFacet;      B=pSphere;     segStart=b7;  segEnd=b8;  } // 7
                else if (t < b9)  { A=pSphere;     B=pGourd;      segStart=b8;  segEnd=b9;  } // 8
                else              { A=pGourd;      B=pCube;       segStart=b9;  segEnd=b10; } // 9

                // robust local progress in [0,1],
                //“how far through this leg are we,” normalized to 0..1
                float segU = saturate( (t - segStart) / max(segEnd - segStart, 1e-5) );

                // eased blend, every leg accelerates/decelerates smoothly
                float3 p = blend(A, B, segU);

                // Approximate normal from direction to keep lighting stable
                float3 nWS = normalize(TransformObjectToWorldDir( (length(p) > 1e-4) ? normalize(p) : v.normal )); //approximate the normal by the outward direction of the final position p, then transform to world for lighting in the fragment shader
                float3 posWS = TransformObjectToWorld(p);
                // Spike weight for coloring: A 0..1 measure of how “spiky” a point currently is.
                float spikeWeight = saturate( (length(p) - _Radius) / max(_SpikeAmp, 1e-4) );
                //Near the base radius: length(p) ≈ _Radius → weight ≈ 0 (base color).
                //Out on spikes: length(p) ≈ _Radius + _SpikeAmp → weight ≈ 1 (spike accent color).


                // Pack varyings
                o.vertex = TransformWorldToHClip(posWS); // position for rasterization
                o.normal = nWS; // for N·L and rim
                o.pos    = posWS; // for view vector    
                o.spike  = spikeWeight; // for spike color blend

                return o;
            }

            float4 frag (Interpolators i) : SV_Target {
                // Simple lambert + rim to show silhouette and spikes nicely
                float3 N = normalize(i.normal); //the surface normal (unit length)
                float3 L = normalize(_MainLightPosition.xyz); //the main light direction (URP provides _MainLightPosition; for a directional light its .xyz acts like a direction
                float  ndotl = saturate(dot(N, L));
                /*
                dot(N,L) = cosine of the angle between the surface and the light.
                    1 → fully facing the light (brightest)
                    0 → perpendicular (edge)
                    <0 → facing away (shouldn’t light), so we saturate to clamp negatives to 0.
                */

                // Rim
                float3 V = normalize(_WorldSpaceCameraPos.xyz - i.pos); //V is the view direction (from surface point toward the camera).
                float  rim = pow(1.0 - saturate(dot(N, V)), _RimPower); 
                /*
                dot(N,V) is largest when the surface faces the camera (center of the object), and small near silhouettes.
                1 - dot(N,V) therefore peaks near the edges (silhouette).

                Raise it to _RimPower to control the falloff:
                    _RimPower small → wide, soft rim
                    _RimPower big → thin, sharp rim
                */

                // Mix base and spike colors by spike weight & lighting
                float3 baseCol  = _BaseColor * (0.35 + 0.65 * ndotl);
                float3 spikeCol = _SpikeColor * (0.25 + 0.75 * ndotl);
                //Each has a small ambient floor (0.35 or 0.25) so the dark side isn’t pitch black.
                //The rest scales with ndotl (diffuse brightness)

                float3 col = lerp(baseCol, spikeCol, i.spike);
                // i.spike 0 near the base sphere → use mostly baseCol
                //1 out on spikes → use mostly spikeCol
                col += _RimColor * rim * 0.35;

                return float4(col, 1);
            }
            ENDHLSL
        }
    }
}