using UnityEditor;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

public class ImageEffectMultiPass : ScriptableRendererFeature {
    RenderPassEvent injectionPoint = RenderPassEvent.AfterRenderingPostProcessing;
    public Material material;
    ImageEffectPasses imageEffectPasses;
    
    // called automatically by unity when the renderer feature is first loaded,
    // enabled, or when properties are changed in the inspector.
    // this is where you should create and initialize your render pass(es).
    public override void Create() {
        if (material == null) return;
        name = material.name;
        imageEffectPasses = new ImageEffectPasses();
        
        imageEffectPasses.renderPassEvent = injectionPoint;
    }
    
    // called automatically by unity every frame, for each camera.
    // this is where you add your render passes to the renderer's execution list
    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData) {
        if (material == null) return;
        
        imageEffectPasses.Setup(material, name);
        renderer.EnqueuePass(imageEffectPasses);
    }
    
    class ImageEffectPasses : ScriptableRenderPass {
        string passName;
        Material material;

        // called in AddRenderPass to pass data from the render feature to this render pass
        public void Setup (Material mat, string passName) {
            material = mat;
            this.passName = passName;
            
            // this flag tells unity that this pass writes to an intermediate texture, which is necessary for our effect to function properly
            requiresIntermediateTexture = true;
        }
        
        // called automatically by unity every frame if this pass has been added (enqueued) to the renderer. this function is where the work of our pass happens
        // render graph is an object that allows us to do things like create textures and add passes
        // frame data is an object that holds data about the current frame, like the camera's current color texture data
        public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData) {
            UniversalResourceData resourceData = frameData.Get<UniversalResourceData>();
            
            TextureHandle source = resourceData.activeColorTexture;
            TextureDesc destinationDesc = renderGraph.GetTextureDesc(source);
            destinationDesc.name = passName;
            
            TextureHandle destination = renderGraph.CreateTexture(destinationDesc);
            
            renderGraph.AddBlitPass(new (source, destination, material, 0), passName);
            
            renderGraph.AddBlitPass(new (destination, source, material, 1), passName);
            
            resourceData.cameraColor = source;
        }
    }
}