//
//  PlayESView.h
//  DecodeVideo
//
//  Created by macro macro on 2018/8/3.
//  Copyright © 2018年 macro macro. All rights reserved.
//
//PlayESView.h  导入MetalKit库创建MTKView子类PlayESView
#import <Cocoa/Cocoa.h>
#import <MetalKit/MetalKit.h>
@interface PlayESView : MTKView
- (void)renderWithPixelBuffer:(CVPixelBufferRef)buffer;  //传入存储YUV数据的pixelbuffer进行渲染
@end
