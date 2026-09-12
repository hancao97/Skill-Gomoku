# 书法素材

## 2.7 神之一手

使用内置 `image_gen.imagegen` 生成，最终贴图为 `assets/calligraphy/divine_hand.png`，2172×724、真实透明 alpha。运行时用与白棋相同的银白色显露笔触。实机确认四字顺序为「神之一手」。巨手本身由 `scripts/divine_hand.gd` 驱动真实棋子模型组成；贴图只用于题字。

提示词：

```text
Use case: stylized-concept. Asset type: transparent PNG calligraphy title texture for a Chinese martial-arts game finishing move. Primary request: create ONLY the four Chinese characters "神之一手", in exactly this order, in one horizontal line. Style: masterful bold running-cursive brush calligraphy 行草, powerful angular starts, sweeping tapered strokes, dry-brush flying-white details 飞白, dramatic irregular baseline while remaining clearly readable. Color palette: near-black ink; the game shader will turn this alpha mask silver-white. Composition: wide horizontal 3:1 aspect, large isolated characters, 7% safe margins, no clipping. Scene/backdrop: actual transparent alpha, no paper, no baked checkerboard, no solid background. No extra text, seals, logos, circles, gold bevel, shadows or scene mockup. Production-ready isolated brush texture.
```

## 2.0 原有三招

生成模式：内置 image_gen.imagegen。用途：游戏招式标题，透明背景墨迹；运行时由着色器显露笔触与着色。

输出：assets/calligraphy/bow.png、moon.png、cosmos.png。

完整提示词记录：

```json
{
  "bow": "Use case: stylized-concept. Asset type: transparent PNG calligraphy title texture for a premium Chinese martial-arts game special move. Create ONLY the Chinese calligraphy \"会挽雕弓如满月\" (exactly these characters in this exact left-to-right order), in one horizontal line. Very bold, masterful Chinese running-cursive brushwork 行草, aggressive angular starts, strong flowing connections, beautiful dry-brush flying-white texture 飞白, sharply tapered sweeping strokes, variation in character size and baseline that feels hand-painted. Pure near-black sumi ink. Main text large and legible, elegantly dramatic, fitting within the canvas with 7% safety margins. Wide landscape composition, no perspective. Transparent background with real alpha, isolated strokes; no parchment, no gray checkerboard baked in, no solid backdrop. No secondary text, no subtitle, no Latin letters, no seal, no gold bevel, no drop shadow, no circles or runes. This is a final production texture, not a scene or mockup. It should feel like a powerful master swordsman's handwritten finishing stroke, not a cute or rounded font.",
  "moon": "Use case: stylized-concept. Asset type: transparent PNG calligraphy title texture for a premium Chinese martial-arts game special move. Create ONLY the Chinese calligraphy \"遥遥领先\" (exactly these characters in this exact left-to-right order), in one horizontal line. Very bold, masterful Chinese running-cursive brushwork 行草, aggressive angular starts, strong flowing connections, beautiful dry-brush flying-white texture 飞白, sharply tapered sweeping strokes, variation in character size and baseline that feels hand-painted. Pure near-black sumi ink. Main text large and legible, elegantly dramatic, fitting within the canvas with 7% safety margins. Wide landscape composition, no perspective. Transparent background with real alpha, isolated strokes; no parchment, no gray checkerboard baked in, no solid backdrop. No secondary text, no subtitle, no Latin letters, no seal, no gold bevel, no drop shadow, no circles or runes. This is a final production texture, not a scene or mockup. It should feel like a powerful master swordsman's handwritten finishing stroke, not a cute or rounded font.",
  "cosmos": "Use case: stylized-concept. Asset type: transparent PNG calligraphy title texture for a premium Chinese martial-arts game special move. Create ONLY the Chinese calligraphy \"天地大同\" (exactly these characters in this exact left-to-right order), in one horizontal line. Very bold, masterful Chinese running-cursive brushwork 行草, aggressive angular starts, strong flowing connections, beautiful dry-brush flying-white texture 飞白, sharply tapered sweeping strokes, variation in character size and baseline that feels hand-painted. Pure near-black sumi ink. Main text large and legible, elegantly dramatic, fitting within the canvas with 7% safety margins. Wide landscape composition, no perspective. Transparent background with real alpha, isolated strokes; no parchment, no gray checkerboard baked in, no solid backdrop. No secondary text, no subtitle, no Latin letters, no seal, no gold bevel, no drop shadow, no circles or runes. This is a final production texture, not a scene or mockup. It should feel like a powerful master swordsman's handwritten finishing stroke, not a cute or rounded font."
}
```
