//
//  MKXPBridge.h
//  RPG Maker
//  SPDX-License-Identifier: GPL-3.0-or-later
//  Copyright (C) 2026 The RPG-Marker Authors. See AUTHORS.
//
//  C interface between the app and mkxp-z (RPG Maker XP / VX / VX Ace runtime).
//

#ifndef MKXPBridge_h
#define MKXPBridge_h

#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Whether this build links mkxp-z (see ThirdParty/mkxp-ios/build.sh).
bool MKXPIsAvailable(void);

@class UIViewController;

/// Starts the game in `gameRoot` (the folder with Game.ini) from the main run loop and calls
/// `completion` with mkxp-z's exit status once it quits. SDL runs its own event loop meanwhile.
void MKXPStartGame(const char *gameRoot, void (^completion)(int status));

/// Provides the view controller laid over the game (on-screen controls, pause menu). It is asked
/// for on the main thread once the game's window and GL view exist.
void MKXPSetOverlayProvider(UIViewController *(^provider)(void));

/// Presses or releases a key, as an SDL scancode (e.g. 40 = Return).
void MKXPSetKey(int scancode, bool pressed);

/// Halts the game and its audio, or resumes them.
void MKXPSetPaused(bool paused);

/// Asks the running game to quit, as closing its window would.
void MKXPRequestQuit(void);

#ifdef __cplusplus
}
#endif

#endif
