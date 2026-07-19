#pragma once

#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>

@interface OverlayView : UIView <MTKViewDelegate>

+ (instancetype)shared;
- (void)start;

@end
