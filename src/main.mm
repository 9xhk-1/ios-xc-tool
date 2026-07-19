#import "OverlayView.h"
#import "Config.h"
#import <UIKit/UIKit.h>

__attribute__((constructor))
static void ios_xc_tool_init(void)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        OverlayView *ov = [OverlayView shared];
        // setupImGuiAndMetal must run on main thread — GImGui is thread_local
        [ov setupImGuiAndMetal];
        [ov show];
    });
}
