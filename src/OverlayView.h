#pragma once

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface OverlayView : UIView <MTKViewDelegate>

@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) id<MTLDevice> device;

+ (instancetype)shared;

- (void)show;
- (void)hide;
- (void)toggle;

@end
