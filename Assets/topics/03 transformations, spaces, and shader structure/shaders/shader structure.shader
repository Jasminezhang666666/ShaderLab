// our shader. some of this is a unity language called "ShaderLab" The code in between "HLSLPROGRAM" and "ENDHLSL" is normal shader code (HLSL)
Shader "shader lab/week 3/shader structure" {
    // this is how you declare properties which are just values that get exposed to be edited in a material (like global variables in your c# scripts)
    Properties {
        // property template:
        // variable name  ("text description", type) = (default value)
        _Color ("a i can type whatever color", Color) = (1, 1, 1, 1)
        _Texture ("a texture", 2D) = "white" {}
        _Float ("a number", Float) = 1
        _Range ("a range", Range(-100, 100)) = 0.5
        _Vector ("a vector", Vector) = (1, 1, 1, 1)
    }
    

    // shaders can contain more than one SubShader, but unless you're doing way more advanced stuff targeting different capabilities of different GPU hardware, you'll only need one.
    SubShader {

        // you will often see tags here. we won't delve too deeply into tag usage unless it's necessary for a particular example. generally, tags are a way to give unity certain information about how to treat the shader. they can have broad and varied implications that are outside the scope of this class. we've been using a tag in our shaders thusfar to tell unity that our shader is meant for the universal render pipeline (urp). if you want to learn more you can here: https://docs.unity3d.com/Manual/SL-SubShaderTags.html
        Tags { "RenderPipeline" = "UniversalPipeline" }


        // each SubShader can have one or more passes. a pass executes its own vertex and fragment shaders so adding another pass alows you to do some other process on top of one you just did. we'll eventually write some shaders with multiple passes and we'll discuss it in more detail then.
        Pass {
            HLSLPROGRAM
            #pragma vertex vert      // defines what our vertex shader is called (vert) so the gpu knows what to execute
            #pragma fragment frag    // defines what our fragment shader is called (frag) so the gpu knows what to execute
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl" // this is a way of including outside code to be accessible inside the shader. Core.hlsl holds many essential unity functions. you can write your own .hlsl files with common reusable shader code and access them across different shaders by using an #include command just like we do with unity's Core.hlsl file!

            // defining our properties and variables in the shader
            // you can put plain numeric material properties (floats, float2/3/4, matrices) in between CBUFFER_START and CBUFFER_END calls. doing this bundles a material’s numeric properties into one block that unity can send to the gpu all at once, cutting cpu work. it also keeps data layout consistent across platforms.
            CBUFFER_START(UnityPerMaterial)
            float4 _Color;
            float _Float;
            float _Range;
            float4 _Vector;
            CBUFFER_END
            
            // texture data is not plain numberic values and the same efficiencies CBUFFER calls offer do not apply, so we declare them outside.
            TEXTURE2D(_Texture);
            SAMPLER(sampler_Texture);
            
            // a struct used to define what data we'll use from the mesh
            struct MeshData {
                float4 vertex : POSITION;  // vertex position input
                float3 normal : NORMAL;    // vertex normal input
                float4 color  : COLOR;     // vertex color input
                float2 uv0    : TEXCOORD0; // vertex uv0 input
                float2 uv1    : TEXCOORD1; // vertex uv1 input
            };

            // a struct used to define what data we're passing from the vertex shader to the fragment shader
            // these outputs from the vertex shader get interpolated across the face of the triangle
            struct Interpolators {
                float4 vertex : SV_POSITION; // clip space position output
                float3 normal : TEXCOORD0;   // TEXCOORDn is a high precision variable. there is a limit to the number of these you can have depending on target hardware. you can safely use up to 8 for most all hardware.
                float4 color  : TEXCOORD1;
                float2 uv0    : TEXCOORD2;
                float2 uv1    : TEXCOORD3;
            };

            Interpolators vert (MeshData v) {
                Interpolators o;
                o.vertex = TransformObjectToHClip(v.vertex); // transforms object space vertex position to clip space position. TransformObjectToHClip() is code that we get by using Core.hlsl
                return o;
            }

            // SV_Target is a shader semantic that is referring to a render target (a render target is just where the output of our fragment shader goes. usually this is the frame buffer, but in some specialized use cases can be separate arbitrary texture data)
            float4 frag (Interpolators i) : SV_Target {
                return _Color;
            }
            ENDHLSL
        }
    }
}