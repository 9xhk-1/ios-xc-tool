#import "OverlayView.h"
#import <UIKit/UIKit.h>

__attribute__((constructor))
static void init(void) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2*NSEC_PER_SEC),
        dispatch_get_main_queue(), ^{
            [[OverlayView shared] setupImGui];
            [[OverlayView shared] start];
        });
}
