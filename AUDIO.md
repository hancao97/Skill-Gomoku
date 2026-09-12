# 声音与混音 · 2.4

保留实录的触盘、放弦、鼓击和雷声，让短促触感、蓄势与落点有不同的动态。避免通过削平波形来制造响度。

- 短音效：13 段 48 kHz / 16 bit / 双声道 PCM，Godot 导入压缩关闭；统一预加载。4 倍 sinc 重建检查素材真峰值不超过 −2 dBTP。
- 雨声：60 秒立体声，4 秒等功率交叉淡化；背景乐维持原有独立开关。两条环境音从静音渐入，避免读取保存设置前出声。
- 路由：Music、Rain、Effects 分组；Thunder 送入 Effects。Master 先清理 25 Hz 以下的能量，再用预读限幅器保护输出，预增益 −2 dB、上限 −2 dBFS、释放 120 ms。常规音量保留余量，仅过大的叠加触发限幅。
- 手势取消与换局：45 ms 音量淡出后停止播放；连续雷声交接 120 ms。雷声切入技能使用引擎的采样插值停止，并为新的技能声音保留 45 ms 间隔。取消尚未发声的手势也会取消延迟播放。
- 设置：雨声 180 ms、音乐 240 ms 渐变；设置增益与技能避让相乘，避让恢复不会覆盖静音。停止已有音效，重新打开时不会恢复旧的大招尾声。
- 退出：先淡出，再停止循环并等待混音线程释放。静音收尾不会保存成用户的声音偏好。
- 震子落回：整组共用一次 −16 dB 的触盘声，不为每颗棋子单独叠加声音；取消震动时不补播落回声。长按蓄力超过音效时长后，释放或取消仍会清理已经结束的声音引用。

限幅采用 Godot 的 [AudioEffectHardLimiter](https://docs.godotengine.org/en/stable/classes/class_audioeffecthardlimiter.html)。声音处理与测量工具位于 `tools/build_audio_v2.py`、`tools/build_thunder.py`、`tools/audio_dsp.py`、`tools/verify_audio.py`；素材许可见 `assets/licenses/audio-v2.txt`。

## 验证

`verification/v2.4/audio-measurements.json` 包含 15 份活跃素材的峰值、直流偏移、起止与循环接缝检查，以及引擎实际 Master 输出的 4 倍重建真峰值和削波样本数。测试输出不做增益归一化。

`tests/playback_audio.gd` 在真实游戏场景中触发普通落子、第三局雷鸣、拉弓、白棋 5×5、天地大同、胜利、取消手势、快速静音和循环接缝；另设明确隔离的过载段，叠加 8 个重击和 4 个雷声来验证输出保护。这种叠加只存在于测试中。记录直接取自 Godot Master 总线，使用音频采样时钟标记分段；Dummy 驱动避免测试音频打扰正在使用电脑的人。

`tests/playback_effect_priority.gd` 检查雷电和技能的互斥；`tests/playback_feedback.gd` 检查悬浮、震子与蓄力光束；`tests/test_rules.gd` 检查棋形、回合、归属和棋盘转换。设置、声音及互斥回放按当前工程版本建立输出目录。当前结果见 [VERIFICATION.md](VERIFICATION.md)，这些本地测试产物均由 Git 忽略。
