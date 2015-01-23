//
//  PSTEnableUIKitDebugging.m
//
//  Copyright (c) 2015 Peter Steinberger. Licensed under the MIT license.
//

#import "Aspects.h"
#import "fishhook.h"
#import <dlfcn.h>

// UIAnimationDragCoefficient
// UISimulatedApplicationResizeGestureEnabled
// UIExternalTouchSloppinessFactor
// UIEnableParallaxEffects
// UIDeviceUsesLowQualityGraphics

// UIMotionEffectsEnabled
// UIMotionEffectMotionUpdateFrequency
// UIMotionEffectMotionUpdateSlowFrequency
// UIMotionEffectMinimumBacklightLevel
// UIMotionEffectHysteresisExitThreshold
// UIMotionEffectHysteresisEntranceThreshold
// UIMotionEffectUIUpdateFrequency
// UIMotionEffectUIUpdateSlowFrequency

// UIDocumentConsoleLogLevel
// UIDocumentFileLogLevel
// GestureFailureMapLogging
// UIPopoverControllerForceAttemptsToAvoidKeyboard

// _UISiriAnimationSpeed ...

// UIBackdropViewNoBlur
// UIBackdropViewNoComputedColorSettingsKey

static NSDictionary *UIKitOverrides() {
    return @{@"UIPopoverControllerPaintsTargetRect" : @YES, // only works on iOS 7
             @"TouchLogging" : @YES,
             @"AnimationLogging" : @YES,
             @"UIUseAugmentedPopGesture" : @YES,
             @"UIKitDecorateFallbackImagesFromScale" : @YES,
             @"UIScreenEdgePanRecognizerShouldLog" : @YES,
             @"SystemGestureGateLogging" : @YES,
             @"GestureLogging" : @YES,
             @"GestureFailureMapLogging" : @YES,
             @"UIKeyboardTypingSpeedLogger" : @YES,
             @"UICatchCAPackageDecodingExceptions" : @YES
             };
}

static BOOL (*GetBoolAnswer)(NSString *capability);
static BOOL PSTGetBoolAnswer(NSString *capability) {
    return [capability isEqual:@"InternalBuild"] ? YES : GetBoolAnswer(capability);
}

__attribute__((constructor)) static void PSTEnableUIKitDebugMode() {
    // Enable Internal Build mode.
    GetBoolAnswer = dlsym(dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY), "MGGetBoolAnswer");
    rebind_symbols((struct rebinding[1]){{"MGGetBoolAnswer", PSTGetBoolAnswer}}, 1);

    // Install custom overrides.
    NSDictionary *overrides = UIKitOverrides();

    [[NSUserDefaults standardUserDefaults] aspect_hookSelector:@selector(persistentDomainForName:) withOptions:0 usingBlock:^(id<AspectInfo> info, NSString *domainName) {
        if ([domainName hasSuffix:@"com.apple.UIKit"]) {
            __autoreleasing NSDictionary *dictionary;
            [[info originalInvocation] invoke];
            [[info originalInvocation] getReturnValue:&dictionary];
            NSMutableDictionary *mutable = [NSMutableDictionary dictionaryWithDictionary:dictionary];
            [mutable addEntriesFromDictionary:overrides];
            dictionary = [mutable copy];
            [[info originalInvocation] setReturnValue:&dictionary];
        }
    } error:NULL];

    [NSUserDefaults aspect_hookSelector:@selector(objectForKey:) withOptions:0 usingBlock:^(id<AspectInfo> info, NSString *key) {
        if (overrides[key]) {
            __autoreleasing id value = overrides[key];
            [[info originalInvocation] setReturnValue:&value];
        }
    } error:NULL];
}
