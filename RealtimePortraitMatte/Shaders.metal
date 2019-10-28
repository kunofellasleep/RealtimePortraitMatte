/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The sample app's shaders.
*/

#include <metal_stdlib>
#include <simd/simd.h>

// Include header shared between this Metal shader code and C code executing Metal API commands.
#import "ShaderTypes.h"

using namespace metal;

typedef struct {
    float2 position [[attribute(kVertexAttributePosition)]];
    float2 texCoord [[attribute(kVertexAttributeTexcoord)]];
} ImageVertex;


typedef struct {
    float4 position [[position]];
    float2 texCoord;
} ImageColorInOut;


// This defines the captured image vertex function.
vertex ImageColorInOut capturedImageVertexTransform(ImageVertex in [[stage_in]]) {
    ImageColorInOut out;
    
    // Pass through the image vertex's position.
    out.position = float4(in.position, 0.0, 1.0);
    
    // Pass through the texture coordinate.
    out.texCoord = in.texCoord;
    
    return out;
}

// Convert from YCbCr to rgb
float4 ycbcrToRGBTransform(float4 y, float4 CbCr) {
    const float4x4 ycbcrToRGBTransform = float4x4(
      float4(+1.0000f, +1.0000f, +1.0000f, +0.0000f),
      float4(+0.0000f, -0.3441f, +1.7720f, +0.0000f),
      float4(+1.4020f, -0.7141f, +0.0000f, +0.0000f),
      float4(-0.7010f, +0.5291f, -0.8860f, +1.0000f)
    );

    float4 ycbcr = float4(y.r, CbCr.rg, 1.0);
    return ycbcrToRGBTransform * ycbcr;
}

// This defines the captured image fragment function.
fragment float4 capturedImageFragmentShader(ImageColorInOut in [[stage_in]],
                                            texture2d<float, access::sample> capturedImageTextureY [[ texture(kTextureIndexY) ]],
                                            texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(kTextureIndexCbCr) ]]) {
    
    constexpr sampler colorSampler(mip_filter::linear,
                                   mag_filter::linear,
                                   min_filter::linear);
    
    // Sample Y and CbCr textures to get the YCbCr color at the given texture coordinate.
    return ycbcrToRGBTransform(capturedImageTextureY.sample(colorSampler, in.texCoord),
                               capturedImageTextureCbCr.sample(colorSampler, in.texCoord));
}


typedef struct {
    float2 position;
    float2 texCoord;
} CompositeVertex;

typedef struct {
    float4 position [[position]];
    float2 texCoordCamera;
    float2 texCoordScene;
} CompositeColorInOut;

// Composite the image vertex function.
vertex CompositeColorInOut compositeImageVertexTransform(const device CompositeVertex* cameraVertices [[ buffer(0) ]],
                                                         const device CompositeVertex* sceneVertices [[ buffer(1) ]],
                                                         unsigned int vid [[ vertex_id ]]) {
    CompositeColorInOut out;

    const device CompositeVertex& cv = cameraVertices[vid];
    const device CompositeVertex& sv = sceneVertices[vid];

    out.position = float4(cv.position, 0.0, 1.0);
    out.texCoordCamera = cv.texCoord;
    out.texCoordScene = sv.texCoord;

    return out;
}

// Composite the image fragment function.
fragment half4 compositeImageFragmentShader(CompositeColorInOut in [[ stage_in ]],
                                    texture2d<float, access::sample> capturedImageTextureY [[ texture(0) ]],
                                    texture2d<float, access::sample> capturedImageTextureCbCr [[ texture(1) ]],
                                    texture2d<float, access::sample> sceneColorTexture [[ texture(2) ]],
                                    depth2d<float, access::sample> sceneDepthTexture [[ texture(3) ]],
                                    texture2d<float, access::sample> alphaTexture [[ texture(4) ]],
                                    texture2d<float, access::sample> dilatedDepthTexture [[ texture(5) ]],
                                    texture2d<float, access::sample> frontLayerTexture [[ texture(6) ]],
                                    texture2d<float, access::sample> backLayerTexture [[ texture(7) ]],
                                    device float *backLayerDistance [[buffer(0)]],
                                    constant SharedUniforms &uniforms [[ buffer(kBufferIndexSharedUniforms) ]])
{
    constexpr sampler s(address::clamp_to_edge, filter::linear);

    float2 texcoord = in.texCoordCamera;
    // camera rgba
    float4 rgba = ycbcrToRGBTransform(capturedImageTextureY.sample(s, texcoord), capturedImageTextureCbCr.sample(s, texcoord));
    half4 cameraColor = half4(rgba);
    // front layer rgba
    half4 frontLayerColor = half4(frontLayerTexture.sample(s, float2(1-texcoord.y, texcoord.x)));
    // back layer rgba
    half4 backLayerColor = half4(backLayerTexture.sample(s, float2(1-texcoord.y, texcoord.x)));
    // matte
    half matte = half(alphaTexture.sample(s, texcoord)[0]);
    // segmentation depth
    float dilatedDepth = half(dilatedDepthTexture.sample(s, texcoord)[0]);
    // 指定距離以内のpeople occulusionのみ表示
    half cutoff = (half)(step(dilatedDepth, *backLayerDistance)) * matte;
    // 後ろのレイヤーとカメラ画像(奥側)の合成
    half4 compositeColor = mix(cameraColor, backLayerColor, backLayerColor.a);
    // カメラ画像(手前側)の合成
    compositeColor = mix(compositeColor, cameraColor, cutoff);
    // フロントレイヤー合成
    compositeColor = mix(compositeColor, frontLayerColor, frontLayerColor.a);
    
    return compositeColor;
}

