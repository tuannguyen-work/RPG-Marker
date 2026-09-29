#!/usr/bin/env python3
# SPDX-License-Identifier: CC0-1.0
"""Builds "RPG Deck Demo", the small game bundled with the app so anyone (including App Review)
can try it without finding a game first.

Everything in it may be redistributed, commercially too:
  - engine: RPG Maker MV corescript (MIT, KADOKAWA / rpgtkoolmv) and its libraries (MIT)
  - font: Pixelify Sans (SIL OFL 1.1)
  - art, sounds, maps and text: generated here, released under CC0
No RPG Maker RTP (default graphics or audio) is used.

Usage: python3 DemoGame/build_demo.py
Output: DemoGame/build/RPG Deck Demo/ and "RPG Maker/Resources/DemoGame.zip".
Needs Pillow and ffmpeg (for the sound effects).
"""

import json
import math
import os
import random
import shutil
import subprocess
import zipfile

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
RUNTIME = os.path.join(HERE, "runtime")
GAME = os.path.join(HERE, "build", "RPG Deck Demo")
ZIP_OUT = os.path.join(HERE, "..", "RPG Maker", "Resources", "DemoGame.zip")
TITLE_ART = os.path.join(HERE, "title_art.png")

TILE = 48

# Handheld Quest palette
NAVY = (28, 36, 112)
NAVY_DARK = (15, 16, 18)
INK = (12, 14, 30)
EMBER = (255, 107, 44)
GOLD = (255, 209, 102)
WHITE = (242, 243, 245)
GREY = (144, 151, 163)


def rgba(color, alpha=255):
    return color + (alpha,)


def save(image, *path):
    full = os.path.join(GAME, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    image.save(full)


def write_json(data, *path):
    full = os.path.join(GAME, *path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    with open(full, "w", encoding="utf-8") as file:
        json.dump(data, file, ensure_ascii=False, separators=(",", ":"))


# MARK: - Images

def window_skin():
    """MV window skin: background, pattern, frame, cursor, pause sign and text colors."""
    image = Image.new("RGBA", (192, 192), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    # Background (stretched) with a soft vertical gradient.
    for y in range(96):
        t = y / 95
        color = tuple(int(NAVY[i] * (1 - t) + INK[i] * t) for i in range(3))
        draw.line([(0, y), (95, y)], fill=rgba(color, 240))
    # Tiled pattern: sparse pixel stars, mostly transparent.
    rng = random.Random(7)
    for _ in range(14):
        x, y = rng.randrange(96), 96 + rng.randrange(96)
        draw.point((x, y), fill=rgba(WHITE, 40))
    # Frame: gold border with dark outline and square corners.
    fx, fy = 96, 0
    draw.rectangle([fx, fy, fx + 95, fy + 95], outline=rgba(INK), width=2)
    draw.rectangle([fx + 2, fy + 2, fx + 93, fy + 93], outline=rgba(GOLD), width=3)
    draw.rectangle([fx + 5, fy + 5, fx + 90, fy + 90], outline=rgba((170, 120, 40)), width=1)
    for cx, cy in [(fx + 2, fy + 2), (fx + 87, fy + 2), (fx + 2, fy + 87), (fx + 87, fy + 87)]:
        draw.rectangle([cx, cy, cx + 6, cy + 6], fill=rgba(EMBER))
    # Scroll arrows sit in the middle of the frame area.
    ax, ay = fx + 36, fy + 24
    draw.polygon([(ax, ay + 10), (ax + 24, ay + 10), (ax + 12, ay)], fill=rgba(GOLD))
    ay = fy + 60
    draw.polygon([(ax, ay), (ax + 24, ay), (ax + 12, ay + 10)], fill=rgba(GOLD))
    # Cursor (48x48 at 96,96).
    draw.rectangle([96, 96, 143, 143], fill=rgba(EMBER, 70), outline=rgba(EMBER), width=2)
    # Pause sign: four 24x24 frames of a bobbing arrow.
    for i, offset in enumerate([0, 2, 4, 2]):
        px = 144 + (i % 2) * 24
        py = 96 + (i // 2) * 24
        draw.polygon([(px + 6, py + 7 + offset), (px + 18, py + 7 + offset), (px + 12, py + 15 + offset)], fill=rgba(GOLD))
    # Text colors: 32 swatches of 12x12 at (96,144).
    colors = [
        WHITE, (32, 160, 214), (255, 120, 76), (102, 204, 64), (153, 204, 255), (204, 192, 255), (255, 255, 160), (128, 128, 128),
        (192, 192, 192), (32, 112, 204), (255, 56, 16), (0, 160, 16), (62, 154, 222), (160, 152, 255), (255, 204, 32), (0, 0, 0),
        GOLD, (255, 255, 64), (255, 32, 32), (32, 32, 64), (224, 128, 64), (240, 192, 64), (64, 128, 192), (64, 192, 240),
        (128, 255, 128), (192, 128, 128), (128, 128, 255), (255, 128, 255), (0, 160, 64), (0, 224, 96), (160, 96, 224), (192, 128, 255),
    ]
    for n, color in enumerate(colors):
        x = 96 + (n % 8) * 12
        y = 144 + (n // 8) * 12
        draw.rectangle([x, y, x + 11, y + 11], fill=rgba(color))
    return image


def icon_set():
    """16 icons per row, 32px. Only the few the demo uses are drawn."""
    image = Image.new("RGBA", (512, 320), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    def at(index):
        return (index % 16) * 32, (index // 16) * 32

    # 1: potion
    x, y = at(1)
    draw.rectangle([x + 13, y + 5, x + 18, y + 10], fill=rgba((150, 110, 70)))
    draw.ellipse([x + 7, y + 10, x + 24, y + 27], fill=rgba((230, 60, 80)), outline=rgba(INK), width=2)
    draw.rectangle([x + 11, y + 14, x + 13, y + 17], fill=rgba(WHITE))
    # 2: key
    x, y = at(2)
    draw.ellipse([x + 5, y + 9, x + 15, y + 19], outline=rgba(GOLD), width=3)
    draw.rectangle([x + 14, y + 13, x + 27, y + 15], fill=rgba(GOLD))
    draw.rectangle([x + 22, y + 15, x + 24, y + 20], fill=rgba(GOLD))
    # 3: star (the demo's treasure)
    x, y = at(3)
    points = []
    for i in range(10):
        radius = 12 if i % 2 == 0 else 5
        angle = -math.pi / 2 + i * math.pi / 5
        points.append((x + 16 + radius * math.cos(angle), y + 17 + radius * math.sin(angle)))
    draw.polygon(points, fill=rgba(GOLD), outline=rgba(INK))
    return image


def character(draw_frame, name):
    """A "$" single-character sheet: 3 frames x 4 directions (down, left, right, up), 48px."""
    image = Image.new("RGBA", (TILE * 3, TILE * 4), (0, 0, 0, 0))
    for row, direction in enumerate(["down", "left", "right", "up"]):
        for frame in range(3):
            cell = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
            draw_frame(ImageDraw.Draw(cell), direction, frame)
            image.alpha_composite(cell, (frame * TILE, row * TILE))
    save(image, "img", "characters", name + ".png")


def person(hair, body, cape=None, hat=None, skin=(255, 214, 170)):
    def draw_frame(draw, direction, frame):
        step = [0, -2, 2][frame] if frame != 1 else 0
        step = {0: -2, 1: 0, 2: 2}[frame]
        # Legs
        draw.rectangle([18 + (step if direction in ("down", "up") else 0), 36, 22 + (step if direction in ("down", "up") else 0), 44], fill=rgba((60, 50, 70)))
        draw.rectangle([26 - (step if direction in ("down", "up") else 0), 36, 30 - (step if direction in ("down", "up") else 0), 44], fill=rgba((60, 50, 70)))
        if direction in ("left", "right"):
            draw.rectangle([21 + step, 36, 27 + step, 44], fill=rgba((60, 50, 70)))
        # Cape behind the body
        if cape and direction != "down":
            draw.rectangle([13, 22, 35, 40], fill=rgba(cape))
        # Body
        draw.rectangle([15, 22, 33, 37], fill=rgba(body), outline=rgba(INK))
        if cape and direction == "down":
            draw.rectangle([13, 22, 15, 38], fill=rgba(cape))
            draw.rectangle([33, 22, 35, 38], fill=rgba(cape))
        # Head
        draw.rectangle([14, 6, 34, 24], fill=rgba(skin), outline=rgba(INK))
        # Hair / hat
        if hat:
            draw.polygon([(12, 12), (36, 12), (24, -4 + 6)], fill=rgba(hat), outline=rgba(INK))
            draw.rectangle([10, 10, 38, 13], fill=rgba(hat))
        else:
            draw.rectangle([14, 5, 34, 11], fill=rgba(hair))
            draw.rectangle([12, 4, 18, 9], fill=rgba(hair))
            draw.rectangle([28, 3, 34, 8], fill=rgba(hair))
        if direction == "up":
            draw.rectangle([14, 6, 34, 20], fill=rgba(hair if not hat else (220, 220, 230)))
        # Face
        if direction == "down":
            draw.rectangle([19, 15, 21, 18], fill=rgba(INK))
            draw.rectangle([27, 15, 29, 18], fill=rgba(INK))
        elif direction == "left":
            draw.rectangle([17, 15, 19, 18], fill=rgba(INK))
        elif direction == "right":
            draw.rectangle([29, 15, 31, 18], fill=rgba(INK))
        if hat and direction != "up":
            draw.rectangle([18, 20, 30, 27], fill=rgba((220, 220, 230)))  # beard
    return draw_frame


def chest_frame(draw, direction, frame):
    opened = direction == "up"  # row 4 is the opened chest
    draw.rectangle([10, 22, 38, 42], fill=rgba((150, 90, 40)), outline=rgba(INK), width=2)
    draw.rectangle([10, 30, 38, 33], fill=rgba(GOLD))
    if opened:
        draw.rectangle([10, 12, 38, 22], fill=rgba((110, 60, 25)), outline=rgba(INK), width=2)
        draw.rectangle([14, 22, 34, 26], fill=rgba((40, 20, 10)))
    else:
        draw.rectangle([10, 16, 38, 24], fill=rgba((175, 105, 50)), outline=rgba(INK), width=2)
        draw.rectangle([22, 26, 26, 32], fill=rgba(GOLD), outline=rgba(INK))


def crystal_frame(draw, direction, frame):
    glow = [60, 110, 160][frame]
    draw.ellipse([8, 30, 40, 44], fill=rgba(GOLD, glow // 2))
    lift = [0, -1, -2][frame]
    draw.polygon([(24, 2 + lift), (36, 18 + lift), (24, 38 + lift), (12, 18 + lift)], fill=rgba(GOLD), outline=rgba(INK))
    draw.polygon([(24, 2 + lift), (30, 18 + lift), (24, 38 + lift)], fill=rgba((255, 236, 170)))
    draw.point((20, 14 + lift), fill=rgba(WHITE))


def sign_frame(draw, direction, frame):
    draw.rectangle([22, 28, 26, 44], fill=rgba((110, 70, 30)), outline=rgba(INK))
    draw.rectangle([8, 12, 40, 30], fill=rgba((175, 120, 60)), outline=rgba(INK), width=2)
    for y in (17, 22):
        draw.line([(13, y), (35, y)], fill=rgba((110, 70, 30)), width=2)


def tiles():
    """A5 sheet (8x16 tiles). Returns tile indexes and the passability of each."""
    image = Image.new("RGBA", (TILE * 8, TILE * 16), (0, 0, 0, 0))
    rng = random.Random(3)

    def cell(index):
        x, y = (index % 8) * TILE, (index // 8) * TILE
        return ImageDraw.Draw(image), x, y

    def grass(draw, x, y, seed, flowers=False):
        draw.rectangle([x, y, x + TILE - 1, y + TILE - 1], fill=rgba((52, 110, 70)))
        local = random.Random(seed)
        for _ in range(14):
            gx, gy = x + local.randrange(2, 44), y + local.randrange(2, 44)
            draw.rectangle([gx, gy, gx + 1, gy + 3], fill=rgba((74, 140, 86)))
        if flowers:
            for _ in range(4):
                fx, fy = x + local.randrange(6, 40), y + local.randrange(6, 40)
                draw.rectangle([fx, fy, fx + 3, fy + 3], fill=rgba(local.choice([GOLD, (255, 150, 190), WHITE])))

    names = {}
    passable = {}

    draw, x, y = cell(0); grass(draw, x, y, 1); names["grass"] = 0; passable[0] = True
    draw, x, y = cell(1); grass(draw, x, y, 2, flowers=True); names["flowers"] = 1; passable[1] = True
    draw, x, y = cell(2)
    draw.rectangle([x, y, x + 47, y + 47], fill=rgba((176, 140, 92)))
    for _ in range(10):
        px, py = x + rng.randrange(44), y + rng.randrange(44)
        draw.rectangle([px, py, px + 2, py + 2], fill=rgba((150, 116, 74)))
    names["path"] = 2; passable[2] = True
    draw, x, y = cell(3)
    draw.rectangle([x, y, x + 47, y + 47], fill=rgba((40, 90, 170)))
    for row in range(3):
        wy = y + 10 + row * 14
        draw.line([(x + 6 + row * 6, wy), (x + 20 + row * 6, wy)], fill=rgba((120, 170, 230)), width=2)
    names["water"] = 3; passable[3] = False
    draw, x, y = cell(4); grass(draw, x, y, 5)
    draw.rectangle([x + 20, y + 30, x + 27, y + 46], fill=rgba((100, 64, 36)), outline=rgba(INK))
    draw.ellipse([x + 4, y + 2, x + 43, y + 36], fill=rgba((30, 80, 55)), outline=rgba(INK), width=2)
    draw.ellipse([x + 10, y + 6, x + 26, y + 20], fill=rgba((50, 115, 75)))
    names["tree"] = 4; passable[4] = False
    draw, x, y = cell(5)
    draw.rectangle([x, y, x + 47, y + 47], fill=rgba((90, 96, 120)))
    for row in range(4):
        by = y + row * 12
        draw.line([(x, by), (x + 47, by)], fill=rgba((60, 64, 84)), width=2)
        off = 0 if row % 2 == 0 else 12
        for bx in range(x + off, x + 48, 24):
            draw.line([(bx, by), (bx, by + 12)], fill=rgba((60, 64, 84)), width=2)
    names["wall"] = 5; passable[5] = False
    draw, x, y = cell(6); grass(draw, x, y, 7)
    draw.rectangle([x, y + 18, x + 47, y + 22], fill=rgba((150, 100, 50)), outline=rgba(INK))
    draw.rectangle([x, y + 30, x + 47, y + 34], fill=rgba((150, 100, 50)), outline=rgba(INK))
    for fx in (x + 4, x + 40):
        draw.rectangle([fx, y + 12, fx + 5, y + 42], fill=rgba((120, 80, 40)), outline=rgba(INK))
    names["fence"] = 6; passable[6] = False
    draw, x, y = cell(7)
    draw.rectangle([x, y, x + 47, y + 47], fill=rgba((176, 140, 92)))
    draw.rectangle([x + 4, y + 4, x + 43, y + 43], outline=rgba((150, 116, 74)), width=2)
    names["plaza"] = 7; passable[7] = True

    save(image, "img", "tilesets", "Demo_A5.png")
    return names, passable


def title_image():
    image = Image.new("RGBA", (816, 624), rgba(INK))
    draw = ImageDraw.Draw(image)
    for y in range(624):
        t = y / 623
        color = tuple(int(NAVY[i] * (1 - t) + INK[i] * t) for i in range(3))
        draw.line([(0, y), (815, y)], fill=rgba(color))
    rng = random.Random(11)
    for _ in range(90):
        sx, sy = rng.randrange(816), rng.randrange(400)
        size = rng.choice([1, 1, 2, 3])
        draw.rectangle([sx, sy, sx + size, sy + size], fill=rgba(rng.choice([WHITE, GOLD]), rng.randrange(120, 255)))
    if os.path.exists(TITLE_ART):
        art = Image.open(TITLE_ART).convert("RGBA")
        scale = 380 / art.height
        art = art.resize((int(art.width * scale), 380), Image.LANCZOS)
        image.alpha_composite(art, ((816 - art.width) // 2, 624 - art.height - 40))
    save(image, "img", "titles1", "DemoTitle.png")


def system_images():
    save(window_skin(), "img", "system", "Window.png")
    save(icon_set(), "img", "system", "IconSet.png")
    blank = lambda w, h: Image.new("RGBA", (w, h), (0, 0, 0, 0))
    save(blank(384, 720), "img", "system", "Balloon.png")
    shadow = blank(48, 48)
    ImageDraw.Draw(shadow).ellipse([10, 38, 38, 46], fill=(0, 0, 0, 90))
    save(shadow, "img", "system", "Shadow1.png")
    save(shadow, "img", "system", "Shadow2.png")
    save(blank(320, 320), "img", "system", "Damage.png")
    save(blank(96, 96), "img", "system", "States.png")
    for n in (1, 2, 3):
        save(blank(576, 576), "img", "system", f"Weapons{n}.png")
    save(blank(336, 48), "img", "system", "ButtonSet.png")
    save(blank(816, 624), "img", "system", "GameOver.png")
    save(blank(816, 624), "img", "system", "Loading.png")
    icon = Image.new("RGBA", (64, 64), rgba(NAVY))
    ImageDraw.Draw(icon).polygon([(32, 6), (52, 32), (32, 58), (12, 32)], fill=rgba(GOLD), outline=rgba(INK))
    save(icon, "icon", "icon.png")


# MARK: - Sounds

SOUNDS = {
    # name: list of (frequency Hz, seconds)
    "Cursor": [(1320, 0.04)],
    "Decision": [(880, 0.05), (1320, 0.07)],
    "Cancel": [(660, 0.05), (440, 0.08)],
    "Buzzer": [(160, 0.18)],
    "Save": [(784, 0.08), (988, 0.08), (1319, 0.16)],
    "Chest": [(523, 0.07), (659, 0.07), (784, 0.07), (1047, 0.2)],
    "Step": [(220, 0.02)],
}


def sounds():
    folder = os.path.join(GAME, "audio", "se")
    os.makedirs(folder, exist_ok=True)
    for name, notes in SOUNDS.items():
        parts = "".join(
            f"sine=frequency={freq}:duration={duration}:sample_rate=44100[s{i}];" for i, (freq, duration) in enumerate(notes)
        )
        inputs = "".join(f"[s{i}]" for i in range(len(notes)))
        # Square-ish tone: overdrive the sine and limit it, for an 8-bit feel.
        graph = f"{parts}{inputs}concat=n={len(notes)}:v=0:a=1,volume=3,alimiter=limit=0.35,apad=pad_dur=0.03[out]"
        # ffmpeg's built-in Vorbis encoder (no libvorbis needed) only writes stereo.
        for extension, codec in (("ogg", ["-c:a", "vorbis", "-strict", "-2", "-ac", "2"]), ("m4a", ["-c:a", "aac", "-b:a", "96k"])):
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-filter_complex", graph, "-map", "[out]", *codec,
                 os.path.join(folder, f"{name}.{extension}")],
                check=True,
            )
    for kind in ("bgm", "bgs", "me"):
        os.makedirs(os.path.join(GAME, "audio", kind), exist_ok=True)


# MARK: - Data

def audio(name="", volume=90):
    return {"name": name, "pan": 0, "pitch": 100, "volume": volume}


def page(image=None, commands=(), trigger=0, move_type=0, priority=1, step_anime=False, condition=None, direction_fix=False):
    conditions = {
        "actorId": 1, "actorValid": False, "itemId": 1, "itemValid": False,
        "selfSwitchCh": "A", "selfSwitchValid": False,
        "switch1Id": 1, "switch1Valid": False, "switch2Id": 1, "switch2Valid": False,
        "variableId": 1, "variableValid": False, "variableValue": 0,
    }
    if condition == "A":
        conditions["selfSwitchValid"] = True
    image = image or {}
    return {
        "conditions": conditions,
        "directionFix": direction_fix,
        "image": {
            "characterIndex": 0,
            "characterName": image.get("name", ""),
            "direction": image.get("direction", 2),
            "pattern": image.get("pattern", 1),
            "tileId": 0,
        },
        "list": list(commands) + [{"code": 0, "indent": 0, "parameters": []}],
        "moveFrequency": 3,
        "moveRoute": {"list": [{"code": 0, "parameters": []}], "repeat": True, "skippable": False, "wait": False},
        "moveSpeed": 3,
        "moveType": move_type,
        "priorityType": priority,
        "stepAnime": step_anime,
        "through": False,
        "trigger": trigger,
        "walkAnime": True,
    }


def text(*lines, face=""):
    commands = [{"code": 101, "indent": 0, "parameters": [face, 0, 0, 2]}]
    commands += [{"code": 401, "indent": 0, "parameters": [line]} for line in lines]
    return commands


def se(name):
    return {"code": 250, "indent": 0, "parameters": [audio(name)]}


def event(event_id, name, x, y, pages):
    return {"id": event_id, "name": name, "note": "", "pages": pages, "x": x, "y": y}


def build_map(names):
    width, height = 17, 13
    ground = [[names["grass"]] * width for _ in range(height)]
    for x in range(width):
        ground[0][x] = ground[height - 1][x] = names["tree"]
    for y in range(height):
        ground[y][0] = ground[y][width - 1] = names["tree"]
    for y in range(1, height - 1):  # path down the middle
        ground[y][8] = names["path"]
    for x in range(3, 14):  # crossing path
        ground[6][x] = names["path"]
    for y in range(5, 8):
        for x in range(7, 10):
            ground[y][x] = names["plaza"]
    for y, x in [(2, 2), (2, 3), (3, 2), (3, 3), (2, 4)]:  # pond
        ground[y][x] = names["water"]
    for x in range(11, 15):
        ground[2][x] = names["fence"]
    for y, x in [(9, 3), (10, 5), (4, 12), (9, 12), (10, 13), (8, 2)]:
        ground[y][x] = names["flowers"]
    for y, x in [(9, 10), (3, 6)]:
        ground[y][x] = names["tree"]

    data = []
    for layer in range(6):
        for y in range(height):
            for x in range(width):
                data.append(1536 + ground[y][x] if layer == 0 else 0)

    guide_talk = text(
        "Welcome to the RPG Deck demo!",
        "Walk with the direction pad. Press A to talk,",
        "check things and confirm. B goes back.",
    ) + text(
        "Press Menu (or B) to open the menu.",
        "The golden crystal saves your game,",
        "and the chest over there is yours to open.",
    )
    events = [
        None,
        event(1, "Guide", 10, 5, [page({"name": "$DemoSage"}, guide_talk, move_type=1)]),
        event(2, "Chest", 13, 4, [
            page({"name": "$!DemoChest", "direction": 2}, [se("Chest")] + text("You found a Star Shard!") + [
                {"code": 126, "indent": 0, "parameters": [3, 0, 0, 1]},
                {"code": 123, "indent": 0, "parameters": ["A", 0]},
            ], direction_fix=True),
            page({"name": "$!DemoChest", "direction": 8}, text("The chest is empty."), condition="A", direction_fix=True),
        ]),
        event(3, "Crystal", 5, 6, [
            page({"name": "$!DemoCrystal"}, text("A warm light fills you.", "Save your progress?") + [
                se("Save"),
                {"code": 352, "indent": 0, "parameters": []},
            ], step_anime=True),
        ]),
        event(4, "Sign", 8, 9, [
            page({"name": "$!DemoSign"}, text(
                "RPG Deck Demo",
                "Made for the RPG Deck app. Free to share:",
                "see LICENSES.txt in the game folder.",
            )),
        ]),
    ]
    return {
        "autoplayBgm": False, "autoplayBgs": False,
        "battleback1Name": "", "battleback2Name": "",
        "bgm": audio(), "bgs": audio(),
        "disableDashing": False, "displayName": "Starlight Glade",
        "encounterList": [], "encounterStep": 30,
        "height": height, "note": "",
        "parallaxLoopX": False, "parallaxLoopY": False, "parallaxName": "", "parallaxShow": True,
        "parallaxSx": 0, "parallaxSy": 0,
        "scrollType": 0, "specifyBattleback": False, "tilesetId": 1, "width": width,
        "data": data, "events": events,
    }


def data_files(names, passable):
    params = [[p] * 100 for p in (120, 30, 18, 16, 14, 14, 16, 12)]
    write_json([None, {
        "id": 1, "battlerName": "", "characterIndex": 0, "characterName": "$DemoHero", "classId": 1,
        "equips": [0, 0, 0, 0, 0], "faceIndex": 0, "faceName": "", "traits": [],
        "initialLevel": 1, "maxLevel": 99, "name": "Ren", "nickname": "Wanderer", "note": "",
        "profile": "A traveler who carries every story in a pocket-sized deck.",
    }], "data", "Actors.json")
    write_json([None, {
        "id": 1, "expParams": [30, 20, 30, 30], "learnings": [], "name": "Wanderer", "note": "", "params": params,
        "traits": [
            {"code": 23, "dataId": 0, "value": 1}, {"code": 22, "dataId": 0, "value": 0.95},
            {"code": 22, "dataId": 1, "value": 0.05}, {"code": 51, "dataId": 1, "value": 0},
            {"code": 52, "dataId": 1, "value": 0},
        ],
    }], "data", "Classes.json")

    def item(item_id, name, icon, description, key=False):
        return {
            "id": item_id, "animationId": 0, "consumable": not key,
            "damage": {"critical": False, "elementId": 0, "formula": "0", "type": 0, "variance": 20},
            "description": description,
            "effects": [] if key else [{"code": 11, "dataId": 0, "value1": 0, "value2": 50}],
            "hitType": 0, "iconIndex": icon, "itypeId": 2 if key else 1, "name": name, "note": "",
            "occasion": 3 if key else 0, "price": 0 if key else 20, "repeats": 1, "scope": 0 if key else 7,
            "speed": 0, "successRate": 100, "tpGain": 0,
        }

    write_json([None,
                item(1, "Potion", 1, "Restores 50 HP."),
                item(2, "Old Key", 2, "It opens nothing yet.", key=True),
                item(3, "Star Shard", 3, "Proof that you played the demo.", key=True)], "data", "Items.json")
    for name in ("Skills", "Weapons", "Armors", "Enemies", "Troops", "Animations"):
        write_json([None], "data", name + ".json")
    write_json([None, {
        "id": 1, "autoRemovalTiming": 0, "chanceByDamage": 100, "iconIndex": 0, "maxTurns": 1,
        "message1": " falls!", "message2": " falls!", "message3": "", "message4": " gets up!",
        "minTurns": 1, "motion": 3, "name": "Knockout", "note": "", "overlay": 0, "priority": 100,
        "releaseByDamage": False, "removeAtBattleEnd": False, "removeByDamage": False,
        "removeByRestriction": False, "removeByWalking": False, "restriction": 4, "stepsToRemove": 100,
        "traits": [{"code": 23, "dataId": 9, "value": 0}],
    }], "data", "States.json")
    write_json([None], "data", "CommonEvents.json")

    flags = [0] * 8192
    flags[0] = 0x10
    for index, can_pass in passable.items():
        flags[1536 + index] = 0 if can_pass else 0x0F
    write_json([None, {
        "id": 1, "flags": flags, "mode": 1, "name": "Demo", "note": "",
        "tilesetNames": ["", "", "", "", "Demo_A5", "", "", "", ""],
    }], "data", "Tilesets.json")
    write_json([None, {"id": 1, "expanded": False, "name": "Starlight Glade", "order": 1, "parentId": 0,
                       "scrollX": 0, "scrollY": 0}], "data", "MapInfos.json")
    write_json(build_map(names), "data", "Map001.json")

    messages = {
        "actionFailure": "There was no effect on %1!", "actorDamage": "%1 took %2 damage!",
        "actorDrain": "%1 was drained of %2 %3!", "actorGain": "%1 gained %2 %3!", "actorLoss": "%1 lost %2 %3!",
        "actorNoDamage": "%1 took no damage!", "actorNoHit": "Miss! %1 took no damage!",
        "actorRecovery": "%1 recovered %2 %3!", "alwaysDash": "Always Dash", "bgmVolume": "Music Volume",
        "bgsVolume": "Ambience Volume", "buffAdd": "%1's %2 went up!", "buffRemove": "%1's %2 returned to normal!",
        "commandRemember": "Command Remember", "counterAttack": "%1 counterattacked!",
        "criticalToActor": "A painful blow!!", "criticalToEnemy": "An excellent hit!!",
        "debuffAdd": "%1's %2 went down!", "defeat": "%1 was defeated.", "emerge": "%1 appeared!",
        "enemyDamage": "%1 took %2 damage!", "enemyDrain": "%1 was drained of %2 %3!",
        "enemyGain": "%1 gained %2 %3!", "enemyLoss": "%1 lost %2 %3!", "enemyNoDamage": "%1 took no damage!",
        "enemyNoHit": "Miss! %1 took no damage!", "enemyRecovery": "%1 recovered %2 %3!",
        "escapeFailure": "However, it was unable to escape!", "escapeStart": "%1 has started to escape!",
        "evasion": "%1 evaded the attack!", "expNext": "To Next %1", "expTotal": "Current %1", "file": "File",
        "levelUp": "%1 is now %2 %3!", "loadMessage": "Load which file?", "magicEvasion": "%1 nullified the magic!",
        "magicReflection": "%1 reflected the magic!", "meVolume": "Jingle Volume", "obtainExp": "%1 %2 received!",
        "obtainGold": "%1\\G found!", "obtainItem": "%1 found!", "obtainSkill": "%1 learned!",
        "partyName": "%1's Party", "possession": "Possession", "preemptive": "%1 got the upper hand!",
        "saveMessage": "Save to which file?", "seVolume": "Sound Volume", "substitute": "%1 protected %2!",
        "surprise": "%1 was surprised!", "useItem": "%1 uses %2!", "victory": "%1 was victorious!",
    }
    sound_names = ["Cursor", "Decision", "Cancel", "Buzzer", "Decision", "Save", "Decision", "", "", "", "",
                   "", "", "", "Buzzer", "", "", "", "", "", "", "", "", ""]
    vehicle = {"bgm": audio(), "characterIndex": 0, "characterName": "", "startMapId": 0, "startX": 0, "startY": 0}
    write_json({
        "airship": vehicle, "boat": vehicle, "ship": vehicle,
        "armorTypes": ["", "General Armor"], "weaponTypes": ["", "Staff"],
        "attackMotions": [{"type": 0, "weaponImageId": 0}, {"type": 1, "weaponImageId": 1}],
        "battleBgm": audio(), "battleback1Name": "", "battleback2Name": "", "battlerHue": 0, "battlerName": "",
        "currencyUnit": "G", "defeatMe": audio(), "editMapId": 1,
        "elements": ["", "Physical"], "equipTypes": ["", "Weapon", "Shield", "Head", "Body", "Accessory"],
        "gameTitle": "RPG Deck Demo", "gameoverMe": audio(), "locale": "en_US", "magicSkills": [],
        "menuCommands": [True, False, False, True, True, True],
        "optDisplayTp": False, "optDrawTitle": True, "optExtraExp": False, "optFloorDeath": False,
        "optFollowers": False, "optSideView": False, "optSlipDeath": False, "optTransparent": False,
        "partyMembers": [1], "skillTypes": ["", "Magic"],
        "sounds": [audio(name) for name in sound_names],
        "startMapId": 1, "startX": 8, "startY": 8,
        "switches": ["", ""], "variables": ["", ""],
        "terms": {
            "basic": ["Level", "Lv", "HP", "HP", "MP", "MP", "TP", "TP", "EXP", "EXP"],
            "commands": ["Fight", "Escape", "Attack", "Guard", "Item", "Skill", "Equip", "Status", "Formation",
                         "Save", "Game End", "Options", "Items", "Weapons", "Key Items", "Equip", "Optimize",
                         "Clear", "New Game", "Continue", None, "To Title", "Cancel", None, "Buy", "Sell"],
            "params": ["Max HP", "Max MP", "Attack", "Defense", "M.Attack", "M.Defense", "Agility", "Luck",
                       "Hit", "Evasion"],
            "messages": messages,
        },
        "testBattlers": [], "testTroopId": 0,
        "title1Name": "DemoTitle", "title2Name": "", "titleBgm": audio(),
        "versionId": 20260930, "victoryMe": audio(),
        "windowTone": [0, 0, 0, 0],
    }, "data", "System.json")


# MARK: - Assembly

def copy_runtime():
    shutil.copytree(os.path.join(RUNTIME, "js"), os.path.join(GAME, "js"))
    os.makedirs(os.path.join(GAME, "js", "plugins"), exist_ok=True)
    with open(os.path.join(GAME, "js", "plugins.js"), "w") as file:
        file.write("// No plugins.\nvar $plugins = [];\n")
    os.makedirs(os.path.join(GAME, "fonts"), exist_ok=True)
    shutil.copy(os.path.join(RUNTIME, "fonts", "PixelifySans.ttf"), os.path.join(GAME, "fonts"))
    with open(os.path.join(GAME, "fonts", "gamefont.css"), "w") as file:
        file.write('@font-face {\n    font-family: GameFont;\n    src: url("PixelifySans.ttf");\n}\n')
    with open(os.path.join(RUNTIME, "index.html")) as file:
        html = file.read().replace("<title></title>", "<title>RPG Deck Demo</title>")
    with open(os.path.join(GAME, "index.html"), "w") as file:
        file.write(html)
    shutil.copy(os.path.join(HERE, "LICENSES.txt"), os.path.join(GAME, "LICENSES.txt"))
    with open(os.path.join(GAME, "package.json"), "w") as file:
        json.dump({"name": "rpg-deck-demo", "main": "index.html", "window": {"title": "RPG Deck Demo", "width": 816, "height": 624}}, file, indent=2)


def main():
    shutil.rmtree(os.path.join(HERE, "build"), ignore_errors=True)
    os.makedirs(GAME)
    copy_runtime()
    system_images()
    title_image()
    names, passable = tiles()
    character(person(hair=(120, 70, 35), body=(60, 90, 190), cape=(200, 40, 40)), "$DemoHero")
    character(person(hair=(220, 220, 230), body=(40, 60, 150), hat=(50, 70, 170)), "$DemoSage")
    character(chest_frame, "$!DemoChest")
    character(crystal_frame, "$!DemoCrystal")
    character(sign_frame, "$!DemoSign")
    sounds()
    data_files(names, passable)

    os.makedirs(os.path.dirname(ZIP_OUT), exist_ok=True)
    with zipfile.ZipFile(ZIP_OUT, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for root, _, files in os.walk(GAME):
            for name in sorted(files):
                if name == ".DS_Store":
                    continue
                path = os.path.join(root, name)
                archive.write(path, os.path.relpath(path, os.path.dirname(GAME)))
    print(f"Built {GAME}")
    print(f"Wrote {os.path.normpath(ZIP_OUT)} ({os.path.getsize(ZIP_OUT) // 1024} KB)")


if __name__ == "__main__":
    main()
