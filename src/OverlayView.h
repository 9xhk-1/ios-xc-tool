#pragma once

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface OverlayView : UIView <MTKViewDelegate>

@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, assign) BOOL isReady;

+ (instancetype)shared;

- (void)setupImGuiAndMetal;
- (void)show;
- (void)addLog:(NSString *)msg;

@end
