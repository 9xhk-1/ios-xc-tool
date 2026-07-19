#pragma once

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface OverlayView : UIView <MTKViewDelegate>

@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, assign) BOOL imguiReady;

+ (instancetype)shared;
+ (void)initializeImGuiGlobal;

- (void)show;
- (void)hide;
- (void)toggle;

@end
