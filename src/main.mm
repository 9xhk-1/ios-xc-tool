#import "OverlayView.h"
#import "Config.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

static void __attribute__((constructor)) ios_xc_tool_init(void)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[OverlayView shared] show];
    });
}
