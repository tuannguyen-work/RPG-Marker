//
//  MKXPBridge.mm
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//

#import "MKXPBridge.h"
#import <UIKit/UIKit.h>
#import <OpenGLES/EAGL.h>
#import <objc/runtime.h>
#include <stdlib.h>

#if MKXPZ_AVAILABLE

// Only the handful of SDL declarations the bridge needs, to avoid depending on SDL's headers.
extern "C" {
typedef struct SDL_Window SDL_Window;
typedef union { unsigned int type; unsigned char padding[56]; } SDL_Event;
enum { SDL_QUIT = 0x100, SDL_APP_WILLENTERBACKGROUND = 0x103, SDL_APP_DIDENTERFOREGROUND = 0x106 };
int SDL_main(int argc, char *argv[]);
void SDL_SetMainReady(void);
SDL_Window *SDL_GL_GetCurrentWindow(void);
void SDL_GL_GetDrawableSize(SDL_Window *window, int *w, int *h);
int SDL_PushEvent(SDL_Event *event);

// Input injection from the RPGPlayer fork (src/eventthread.cpp): works for quick taps too.
void mkxpz_set_library_injected_key_state(int scancode, int pressed);
void mkxpz_reset_library_injected_key_state(void);

// ---- Symbols mkxp-z (RPGPlayer iOS fork) expects the host app to provide.

/// 1 = errors, 2 = +ok, 3 = +info, 4 = +debug.
int g_mkxpz_log_level = 2;

/// Drawable size of the GL view in pixels.
void mkxpz_get_ios_screen_size(int *w, int *h) {
    *w = 0;
    *h = 0;
    if (SDL_Window *window = SDL_GL_GetCurrentWindow()) {
        SDL_GL_GetDrawableSize(window, w, h);
    }
}

/// SDL draws into its own framebuffer object instead of 0; mkxp-z must render into it.
/// Called on mkxp-z's render thread right after it made SDL's GL context current. The main thread
/// is busy running SDL's event loop, so everything is read from that context: SDL's EAGLContext
/// subclass keeps a reference to its view, which owns the framebuffer.
static void installOverlay(void);

unsigned int mkxpz_get_sdl_framebuffer(void) {
    // The GL view now exists: lay the app's controls over it (the main queue is free, see MKXPStartGame).
    dispatch_async(dispatch_get_main_queue(), ^{ installOverlay(); });

    EAGLContext *context = [EAGLContext currentContext];
    if (![context respondsToSelector:NSSelectorFromString(@"sdlView")]) return 0;
    id view = [context valueForKey:@"sdlView"];
    if (!view) return 0;
    if ([view respondsToSelector:NSSelectorFromString(@"drawableFramebuffer")]) {
        return [[view valueForKey:@"drawableFramebuffer"] unsignedIntValue];
    }
    Ivar ivar = class_getInstanceVariable([view class], "viewFramebuffer");
    return ivar ? *(unsigned int *)((uint8_t *)(__bridge void *)view + ivar_getOffset(ivar)) : 0;
}
}

bool MKXPIsAvailable(void) { return true; }

static UIViewController *(^overlayProvider)(void);
static UIViewController *installedOverlay;

void MKXPSetOverlayProvider(UIViewController *(^provider)(void)) {
    overlayProvider = [provider copy];
}

static void installOverlay(void) {
    if (!overlayProvider || installedOverlay) return;
    Class sdlWindowClass = NSClassFromString(@"SDL_uikitwindow");
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            UIViewController *root = window.rootViewController;
            if (![window isKindOfClass:sdlWindowClass] || !root) continue;
            UIViewController *overlay = overlayProvider();
            [root addChildViewController:overlay];
            overlay.view.frame = root.view.bounds;
            overlay.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            overlay.view.backgroundColor = UIColor.clearColor;
            [root.view addSubview:overlay.view];
            [overlay didMoveToParentViewController:root];
            installedOverlay = overlay;
            return;
        }
    }
}

static int runGame(const char *gameRoot) {
    if (const char *level = getenv("MKXPZ_LOG_LEVEL")) g_mkxpz_log_level = atoi(level);
    setenv("MKXPZ_GAME_ROOT", gameRoot, 1);
    // MIDI soundfont for games that don't name one (built into Assets.bundle by build.sh).
    NSString *soundFont = [NSBundle.mainBundle pathForResource:@"GeneralUser-GS" ofType:@"sf2" inDirectory:@"Assets.bundle"];
    if (soundFont) setenv("MKXPZ_SOUNDFONT", soundFont.fileSystemRepresentation, 1);
    static char name[] = "mkxp-z";
    char *argv[] = { name, NULL };

    mkxpz_reset_library_injected_key_state();
    // SDL creates its window in the app's window scene (ThirdParty/mkxp-deps/patches).
    SDL_SetMainReady();
    int status = SDL_main(1, argv);

    [installedOverlay willMoveToParentViewController:nil];
    [installedOverlay.view removeFromSuperview];
    [installedOverlay removeFromParentViewController];
    installedOverlay = nil;
    return status;
}

void MKXPStartGame(const char *gameRoot, void (^completion)(int status)) {
    NSString *root = @(gameRoot);
    // Run from a run-loop callout rather than a main-queue block: SDL_main doesn't return until the
    // game quits, and while it runs the main queue (Swift's MainActor, dispatch_async) must keep working.
    CFRunLoopPerformBlock(CFRunLoopGetMain(), kCFRunLoopCommonModes, ^{
        int status = runGame(root.fileSystemRepresentation);
        completion(status);
    });
    CFRunLoopWakeUp(CFRunLoopGetMain());
}

void MKXPSetKey(int scancode, bool pressed) {
    mkxpz_set_library_injected_key_state(scancode, pressed ? 1 : 0);
}

void MKXPSetPaused(bool paused) {
    // mkxp-z's event filter halts its threads and audio device for these, as on app backgrounding.
    SDL_Event event = {};
    event.type = paused ? SDL_APP_WILLENTERBACKGROUND : SDL_APP_DIDENTERFOREGROUND;
    SDL_PushEvent(&event);
}

void MKXPRequestQuit(void) {
    SDL_Event event = {};
    event.type = SDL_QUIT;
    SDL_PushEvent(&event);
}

#else

bool MKXPIsAvailable(void) { return false; }
void MKXPStartGame(const char *gameRoot, void (^completion)(int status)) { completion(-1); }
void MKXPSetOverlayProvider(UIViewController *(^provider)(void)) {}
void MKXPSetKey(int scancode, bool pressed) {}
void MKXPSetPaused(bool paused) {}
void MKXPRequestQuit(void) {}

#endif
