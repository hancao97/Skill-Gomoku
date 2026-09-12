# 资源重建

克隆仓库后，使用已有 `assets/` 即可运行游戏。以下步骤仅用于重新制作资源。

## Blender 模型

源文件 `art/source/rainfall_sanctuary.blend` 包含棋盘、棋碗、灯、石台、树木与植被；`art/source/stones.blend` 包含黑白棋子。运行时加载对应的 `assets/models/*.glb`。

使用 Blender 5.2 LTS 打开源文件即可编辑。全量重建脚本会重新生成模型、纹理与基础环境音频：

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --python tools/build_art.py
```

脚本会覆盖其生成资源，修改过的美术源文件应先提交 Git。生成后在 Godot 中重新导入资源。

## 声音

工具使用 Python、NumPy 和可从 `PATH` 调用的 FFmpeg：

```sh
python3 -m venv .venv
. .venv/bin/activate
python -m pip install -r tools/requirements.txt
```

重制声音所需的原始录音存放于 `art/source/`，该目录的 MP3 下载由 `.gitignore` 排除。按原作者页面取得录音并使用下表中的本地文件名：

| 本地文件名 | 原始素材及来源 |
| --- | --- |
| `forest-rain-673951.mp3` | Félix Blume，Rain under a tree in the forest：[Freesound 673951](https://freesound.org/people/felix.blume/sounds/673951/)，CC0。 |
| `bow-release-384915.mp3` | Ali_6868，Bow Release：[Freesound 384915](https://freesound.org/people/Ali_6868/sounds/384915/)，CC0。 |
| `komori-go-stone.mp3` | 小森平 `a_Go_stone.mp3`：[乐器与游戏录音](https://taira-komori.net/playing01.html)。 |
| `komori-drum.mp3` | 同页 `large_drum1.mp3`。 |
| `komori-drum-finish.mp3` | 同页 `large_drum3.mp3`。 |
| `komori-lightning1.mp3` | 小森平 `lightning1.mp3`：[自然与雷雨录音](https://taira-komori.net/nature01cn.html)。 |
| `komori-lightning2.mp3` | 同页 `lightning2.mp3`。 |
| `komori-thunder.mp3` | 同页 `thunder1.mp3`。 |
| `magic-whoosh-715784.mp3` | DustyWind，Magic Whoosh：[Freesound 715784](https://freesound.org/people/DustyWind/sounds/715784/)，CC0。 |
| `icy-cast-691005.mp3` | DustyWind，Icy Magic Cast：[Freesound 691005](https://freesound.org/people/DustyWind/sounds/691005/)，CC0。 |
| `riser-691006.mp3` | DustyWind，Scifi Riser Tension：[Freesound 691006](https://freesound.org/people/DustyWind/sounds/691006/)，CC0。 |
| `slam-691626.mp3` | DustyWind，Reverberant Slam Hit Far：[Freesound 691626](https://freesound.org/people/DustyWind/sounds/691626/)，CC0。 |
| `cinematic-impact-814885.mp3` | AudioPapkin，Sound Design Elements Impact SFX PS 091：[Freesound 814885](https://freesound.org/people/AudioPapkin/sounds/814885/)，CC0。 |

小森平允许音频编辑、格式转换与游戏内嵌使用，禁止将音效素材本身未经许可再分发或出售。请遵循 [作者条款](https://taira-komori.net/welcome.html) 与项目内的 [音频署名](../assets/licenses/audio-v2.txt)。

在项目根目录执行：

```sh
python tools/build_audio_v2.py
python tools/build_thunder.py
python tools/build_skill_audio.py

GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --editor --path . --import --quit
"$GODOT_BIN" --path . --audio-driver Dummy -- --verify --audio-check
python tools/verify_audio.py
python tools/preview_skill_audio.py
```

声音脚本生成短音效和雨声循环，维持未压缩 PCM 导入配置并记录峰值；验证脚本分析素材以及实际 Master 混音。仅分析现有素材时，可直接运行 `python tools/verify_audio.py`，无需重新下载录音；实际录音缺失时报告会注明待录制。

`build_skill_audio.py` 只重制技能与胜利声音，可以单独运行；全量重建时应放在旧版构建脚本之后。当前版本使用 Freesound 页面公开的高质量 MP3 预览，源文件摘要记入本地 `verification/v2.6/skill-audio-build.json`。脚本生成的张力和聚气循环区间与 `scripts/effects_v2.gd` 中的 `GESTURE_LOOPS` 对应，修改区间后须同时更新音频测量脚本并重跑声音回放。

设置、声音和互斥回放默认写入当前版本的测试目录，例如 2.5 对应 `verification/v2.5/`；音频分析器也默认读取该目录。分析旧版录音可显式传入 `python tools/verify_audio.py --output-dir verification/v2.4`。

旧版 `tools/build_audio.py` 和 `tests/playback.gd` 保留作早期版本参考，不属于当前默认构建与验证流程。当前回放入口是 `tests/playback_v2.gd` 及其派生脚本。悬浮、震子和墨色蓄力通过 `--verify --feedback-check` 验证。
