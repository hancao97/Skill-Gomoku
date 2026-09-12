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

小森平允许音频编辑、格式转换与游戏内嵌使用，禁止将音效素材本身未经许可再分发或出售。请遵循 [作者条款](https://taira-komori.net/welcome.html) 与项目内的 [音频署名](../assets/licenses/audio-v2.txt)。

在项目根目录执行：

```sh
python tools/build_audio_v2.py
python tools/build_thunder.py

GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot
"$GODOT_BIN" --headless --editor --path . --import --quit
"$GODOT_BIN" --path . --audio-driver Dummy -- --verify --audio-check
python tools/verify_audio.py
```

声音脚本生成短音效和雨声循环，维持未压缩 PCM 导入配置并记录峰值；验证脚本分析素材以及实际 Master 混音。仅分析现有素材时，可直接运行 `python tools/verify_audio.py`，无需重新下载录音；实际录音缺失时报告会注明待录制。

旧版 `tools/build_audio.py` 和 `tests/playback.gd` 保留作早期版本参考，不属于 2.3 的默认构建与验证流程。当前回放入口是 `tests/playback_v2.gd` 及其派生脚本。
