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
enum { SDL_QUIT = 0x100 };
int SDL_main(int argc, char *argv[]);
void SDL_SetMainReady(void);
SDL_Window *SDL_GL_GetCurrentWindow(void);
void SDL_GL_GetDrawableSize(SDL_Window *window, int *w, int *h);
int SDL_PushEvent(SDL_Event *event);

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
unsigned int mkxpz_get_sdl_framebuffer(void) {
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

int MKXPRunGame(const char *gameRoot) {
    if (const char *level = getenv("MKXPZ_LOG_LEVEL")) g_mkxpz_log_level = atoi(level);
    setenv("MKXPZ_GAME_ROOT", gameRoot, 1);
    static char name[] = "mkxp-z";
    char *argv[] = { name, NULL };

    // SDL creates its window in the app's window scene (ThirdParty/mkxp-deps/patches).
    SDL_SetMainReady();
    return SDL_main(1, argv);
}

void MKXPRequestQuit(void) {
    SDL_Event event = {};
    event.type = SDL_QUIT;
    SDL_PushEvent(&event);
}

#else

bool MKXPIsAvailable(void) { return false; }
int MKXPRunGame(const char *gameRoot) { return -1; }
void MKXPRequestQuit(void) {}

#endif
