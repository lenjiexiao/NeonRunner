# 霓虹快跑 Neon Runner

一个赛博朋克风的单键跑酷游戏，纯代码实现（美术用绘图指令、音效用 PCM 合成、背景用着色器），零外部素材。

## 怎么玩

双击桌面「霓虹快跑」快捷方式，或用 Godot 4.7 打开本项目按 F5。

| 按键 | 作用 |
|------|------|
| 空格 / ↑ / W / 鼠标左键 | 跳跃（空中可再跳一次 = 二段跳）|
| R | 重新开始 |
| Esc | 退出 |

**规则**：越跑越快，撞到障碍就结束。
- 🟣 尖刺 / 🟧 方块 → 跳过去
- 🟥 高柱 → 需要二段跳
- 🟪 浮空横梁 → 贴地钻过去（千万别跳！）
- ✦ 能量球 → 每颗 +10 m

## 操作手感

- 土狼时间（离地 0.12s 内仍可起跳）
- 输入缓冲（落地前 0.12s 按的跳不会丢）
- 可变跳跃高度（提前松手 = 跳矮些）
- squash & stretch 弹性动画、慢动作死亡定格、镜头震动

## 文件结构

```
project.godot            项目配置
scenes/Main.tscn         唯一场景（其余全部代码构建）
scripts/main.gd          主控制器：流程/关卡生成/UI/特效/存档
scripts/player.gd        玩家：跳跃手感三件套
scripts/obstacle.gd      障碍物：尖刺/方块/高柱/横梁
scripts/orb.gd           能量球
scripts/audio_synth.gd   音效合成（16 位 PCM）
shaders/neon_bg.gdshader 合成波背景：星空/落日/透视网格
```

最高纪录存在 `user://neon_runner.cfg`（`%APPDATA%\Godot\app_userdata\霓虹快跑 Neon Runner\`）。
