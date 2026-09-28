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

/// Runs the game in `gameRoot` (the folder with Game.ini). Blocks on the main thread until the
/// game quits, while SDL keeps the run loop going. Returns mkxp-z's exit status.
int MKXPRunGame(const char *gameRoot);

/// Asks the running game to quit, as closing its window would.
void MKXPRequestQuit(void);

#ifdef __cplusplus
}
#endif

#endif
