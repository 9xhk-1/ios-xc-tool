#import "OverlayView.h"
#import "Config.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>

__attribute__((constructor))
static void ios_xc_tool_init(void)
{
    // Create ImGui context IMMEDIATELY (thread_local GImGui must exist
    // before any touch/system event can trigger ImGui::GetIO)
    [OverlayView initializeImGuiGlobal];

    // Defer Metal/UI setup until app is running
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [[OverlayView shared] show];
    });
}
