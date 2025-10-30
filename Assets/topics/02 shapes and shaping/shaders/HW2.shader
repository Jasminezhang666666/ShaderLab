Shader "shader lab/week 2/HW2" {
    Properties
    {
        // ===== Symmetry & Motion =====
        _Segments        ("Segments", Float) = 16 //how many "pizza slices"
        _StepHz          ("Step Rate per sec", Float) = 1.0 //snap time
        _VisibleStepFrac ("Visible Step Fraction of Slice", Range(0,1)) = 0.25 //smaller "extra" snap
        [Toggle] _OvalOpposite ("Ovals Opposite Direction", Float) = 1 //make ellipses rotate opposite. 0 if same

        // ===== Layout =====
        _CenterHole ("Center Hole Radius", Range(0,0.6)) = 0.05 //larger = bigger empty enter
        _OuterFade  ("Outer Fade Radius",  Range(0.6,1.5)) = 1.05 //Where the pattern fades to the background at the edges

        // ===== Shapes =====
        _PetalFreq ("Petal Frequency", Float) = 8.0
        _PetalAmp  ("Petal Amplitude", Range(0,1)) = 0.45
        _MixPetals ("Mix Petals", Range(0,1)) = 0.7

        _LinesPerSector   ("Polar Lines Per Sector", Range(1, 12)) = 3
        _EllipsesPerUnit  ("Ellipses Per Radial Unit", Float) = 6
        _EllipseA         ("Ellipse Semi-axis Along Radius", Range(0.05, 0.6)) = 0.35
        _EllipseB         ("Ellipse Semi-axis Across Angle", Range(0.02, 0.6)) = 0.18
        _MixEllipse       ("Mix Ellipse", Range(0,1)) = 0.6

        _WaveLinesPerUnit ("Wave Lines Per Radial Unit", Float) = 8.0
        _WaveAmp          ("Wave Amplitude", Range(0.0, 0.5)) = 0.18
        _WaveWidth        ("Wave Band Softness", Range(0.001, 0.1)) = 0.03
        _WaveSpeed        ("Wave Scroll Speed", Float) = 0.6
        _MixWave          ("Mix Wave", Range(0,1)) = 0.55
    }

    SubShader {
        Tags { "RenderPipeline" = "UniversalPipeline" }
        Pass {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            #define TAU 6.283185

            static const float kPetalSharpness = 4.0;
            static const float kPetalPulse     = 1.1;   // Hz
            static const float kEllipseAA      = 0.010;
            static const float kWaveAngFreq = 10.0;
            static const float kWaveSwirl   = 3.0;

            // simple static background gradient
            static const float3 kBGInner = float3(0.08, 0.00, 0.12);
            static const float3 kBGOuter = float3(0.00, 0.00, 0.00);

            // color step rates (random per step)
            static const float kPetalStepHz   = 0.7;
            static const float kEllInnerStepHz= 0.9;
            static const float kEllOuterStepHz= 0.6;
            static const float kWaveStepHz    = 0.6;

            CBUFFER_START(UnityPerMaterial)
            float _Segments;
            float _StepHz, _VisibleStepFrac;

            float _CenterHole, _OuterFade;

            float _PetalFreq, _PetalAmp, _MixPetals;

            float _LinesPerSector, _EllipsesPerUnit, _EllipseA, _EllipseB, _MixEllipse;

            float _WaveLinesPerUnit, _WaveAmp, _WaveWidth, _WaveSpeed, _MixWave;

            float _BGHueScroll;

            float _OvalOpposite;
            CBUFFER_END

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

            float rand1(float x) {                 // 0..1 pseudo-random
                return frac(sin(x) * 43758.5453);  // simple, readable
            }
            float3 randColor(float seed) {         // bright-ish RGB
                return 0.35 + 0.65 * float3(
                    rand1(seed + 1.0),
                    rand1(seed + 2.0),
                    rand1(seed + 3.0)
                );
            }

            // --- geometry helpers ---
            float foldAngleMirrored(float a, float sector){
                float aLocal = a - floor(a / sector) * sector; // [0, sector)
                return abs(aLocal - sector * 0.5);             // mirror inside slice
            }

            float petalField(float aLocal, float r, float freq, float amp, float sharp){
                float lobe = 0.5 + 0.5 * cos(aLocal * freq);
                lobe = pow(saturate(lobe), sharp);
                float edge = lobe * amp + (1.0 - amp);
                return 1.0 - smoothstep(edge, edge + 0.02, r);
            }

            float ellipseAlongPolar(float r, float aLocal, float sector, float phaseShift){
                float lines   = max(1.0, floor(_LinesPerSector));
                float stepAng = sector / lines;
                float phaseA  = frac((aLocal / stepAng) + phaseShift); // signed; survives mirroring
                float dA      = abs(phaseA - 0.5) * 2.0;
                float v       = dA * r;

                float cell    = r * _EllipsesPerUnit;
                float uPhase  = frac(cell);
                float uSigned = uPhase - 0.5;
                float u       = abs(uSigned);

                float a = max(1e-4, _EllipseA);
                float b = max(1e-4, _EllipseB);
                float eq = (u/a)*(u/a) + (v/b)*(v/b);

                float halfGate = step(0.0, uSigned); // outward half only
                float ellipse  = 1.0 - smoothstep(1.0, 1.0 + kEllipseAA, eq);
                return ellipse * halfGate;
            }

            float waveOrbitField(float r, float a, float t){
                float baseCoord = frac(r * _WaveLinesPerUnit);
                float offset    = _WaveAmp * sin(a * kWaveAngFreq + r * kWaveSwirl + t * _WaveSpeed);
                float w         = abs(frac(baseCoord + offset) - 0.5);
                return 1.0 - smoothstep(0.5 - _WaveWidth, 0.5 + _WaveWidth, w);
            }

            float4 frag (Interpolators i) : SV_Target
            {
                // centered UV -> polar
                float2 p = i.uv * 2.0 - 1.0;
                float r = length(p);
                float a = atan2(p.y, p.x);

                // sector
                float seg    = max(2.0, floor(_Segments));
                float sector = TAU / seg;

                // snapped rotation
                float stepCount = floor(_Time.y * _StepHz + 1e-6);
                float rotStep   = sector * stepCount;
                float rotStepVis= sector * _VisibleStepFrac * stepCount;

                // base angle and folded local angle
                float aBase      = a - (rotStep + rotStepVis);
                float aLocalBase = foldAngleMirrored(aBase, sector);

                // ellipse opposite/same via phase shift 
                float lines   = max(1.0, floor(_LinesPerSector));
                float stepAng = sector / lines;
                float sOval   = (_OvalOpposite > 0.5) ? +1.0 : -1.0;
                float phaseShiftOval = sOval * ((rotStep + rotStepVis) / stepAng);

                // waves use stepped time
                float tWave = stepCount / max(1e-6, _StepHz);

                // petal pulsing (shrink/expand)
                float pulse   = 0.4 + 0.6 * (0.5 + 0.5 * sin(_Time.y * kPetalPulse)); // 0.4..1.0
                float ampAnim = _PetalAmp * pulse;

                // masks
                float mPetal   = petalField(aLocalBase, r, _PetalFreq, ampAnim, kPetalSharpness) * _MixPetals;
                float mEllipse = ellipseAlongPolar(r, aLocalBase, sector, phaseShiftOval) * _MixEllipse;
                float mWave    = waveOrbitField(r, aBase, tWave) * _MixWave;

                // background
                float tRad = saturate(r / _OuterFade);
                float3 col = lerp(kBGInner, kBGOuter, tRad);

                // random colors per group, stepped in time
                float idxP      = floor(_Time.y * kPetalStepHz);
                float3 petalCol = randColor(10.0 + idxP);

                float idxIn     = floor(_Time.y * kEllInnerStepHz);
                float3 ellIn    = randColor(20.0 + idxIn);

                float idxOut    = floor(_Time.y * kEllOuterStepHz);
                float3 ellOut   = randColor(21.0 + idxOut);

                float3 ellCol   = (tRad < 0.45) ? ellIn : ellOut;

                float idxW      = floor(_Time.y * kWaveStepHz);
                float3 waveBase = randColor(30.0 + idxW);
                float3 waveCol  = waveBase;

                // center hole
                float hole = smoothstep(_CenterHole, _CenterHole + 0.02, r);
                col *= hole;

                // compose
                col = lerp(col, petalCol, mPetal);
                col = lerp(col, ellCol,   mEllipse);
                col = lerp(col, waveCol,  mWave);

                // outer circular fade
                float edge = smoothstep(_OuterFade, _OuterFade - 0.05, r);
                col = lerp(kBGOuter, col, edge);

                return float4(saturate(col), 1.0);
            }

            ENDHLSL
        }
    }
}