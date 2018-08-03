//
//  PlayESView.m
//  DecodeVideo
//
//  Created by macro macro on 2018/8/3.
//  Copyright © 2018年 macro macro. All rights reserved.
//

#import "PlayESView.h"

@implementation PlayESView {
    id<MTLComputePipelineState> _pipelineState;
    id<MTLCommandQueue> _commandQueue;
    CVMetalTextureCacheRef _textCache;
}

- (instancetype)initWithCoder:(NSCoder *)coder {
    self = [super initWithCoder:coder];
    if (self) {
        id<MTLDevice> device = MTLCreateSystemDefaultDevice();
        _commandQueue = [device newCommandQueue];
        id<MTLLibrary> library  = [device newDefaultLibrary];
        id<MTLFunction> function = [library newFunctionWithName:@"yuvToRGB"];
        NSError * error = NULL;
        _pipelineState = [device newComputePipelineStateWithFunction:function error:&error];

        CVReturn ret = CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &_textCache);
        if (ret != kCVReturnSuccess) {
            NSLog(@"Unable to allocate texture cache");
            return nil;
        }

        self.device = device;
        self.framebufferOnly = NO;
        self.autoResizeDrawable = NO;
    }
    return self;
}

- (void)renderWithPixelBuffer:(CVPixelBufferRef)buffer {
    if (buffer == nil) return;
    CVMetalTextureRef y_texture ;
    //获取pixelbuffer中y数据的宽和高，然后创建包含y数据的MetalTexture，注意pixelformat为MTLPixelFormatR8Unorm
    size_t y_width = CVPixelBufferGetWidthOfPlane(buffer, 0);
    size_t y_height = CVPixelBufferGetHeightOfPlane(buffer, 0);
    CVReturn ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textCache, buffer, nil, MTLPixelFormatR8Unorm, y_width, y_height, 0, &y_texture);
    if (ret != kCVReturnSuccess) {
        NSLog(@"fail to create texture");
    }
    id<MTLTexture> y_inputTexture = CVMetalTextureGetTexture(y_texture);
    if (y_inputTexture == nil) {
        NSLog(@"failed to create metal texture");
    }

    CVMetalTextureRef uv_texture ;
    //获取pixelbuffer中uv数据的宽和高，然后创建包含uv数据的MetalTexture，注意pixelformat为MTLPixelFormatRG8Unorm
    size_t uv_width = CVPixelBufferGetWidthOfPlane(buffer, 1);
    size_t uv_height = CVPixelBufferGetHeightOfPlane(buffer, 1);
    ret = CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, _textCache, buffer, nil, MTLPixelFormatRG8Unorm, uv_width, uv_height, 1, &uv_texture);
    if (ret != kCVReturnSuccess) {
        NSLog(@"fail to create texture");
    }
    id<MTLTexture> uv_inputTexture = CVMetalTextureGetTexture(uv_texture);
    if (uv_inputTexture == nil) {
        NSLog(@"failed to create metal texture");
    }

    CVPixelBufferRelease(buffer);
    CAMetalLayer * metalLayer = (CAMetalLayer *)self.layer;
    id<CAMetalDrawable> drawable = metalLayer.nextDrawable;
    id<MTLCommandBuffer> commandBuffer = [_commandQueue commandBuffer];
    id<MTLComputeCommandEncoder> computeCommandEncoder = [commandBuffer computeCommandEncoder];
    [computeCommandEncoder setComputePipelineState:_pipelineState];
    //把包含y数据的texture、uv数据的texture和承载渲染图像的texture传入
    [computeCommandEncoder setTexture:y_inputTexture atIndex:0];
    [computeCommandEncoder setTexture:uv_inputTexture atIndex:1];
    [computeCommandEncoder setTexture:drawable.texture atIndex:2];
    MTLSize threadgroupSize = MTLSizeMake(16, 16, 1);
    MTLSize threadgroupCount = MTLSizeMake((y_width  + threadgroupSize.width -  1) / threadgroupSize.width, (y_width + threadgroupSize.height - 1) / threadgroupSize.height, 1);
    [computeCommandEncoder dispatchThreadgroups:threadgroupCount threadsPerThreadgroup: threadgroupSize];
    [computeCommandEncoder endEncoding];
    [commandBuffer addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull cmdBuffer) {
        CVBufferRelease(y_texture);
        CVBufferRelease(uv_texture);
    }];
    [commandBuffer presentDrawable:drawable];
    [commandBuffer commit];
}

@end
