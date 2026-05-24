# 单词对对碰 (Match Madness)

一款 Duolingo 风格的英语单词匹配游戏，Android 平台，Flutter 构建。

在限时内将英文单词与中文释义配对。支持导入自定义词库、追踪错题、基于艾宾浩斯遗忘曲线的智能复习。

## 功能

- **限时匹配游戏** — 4 档难度可选（1:00 / 1:30 / 2:00 / 3:00），在时间压力下匹配英文单词和中文释义。
- **智能选词** — 根据艾宾浩斯遗忘曲线算法，优先选出你最容易错的单词。
- **音效 & 朗读** — 程序生成的配对成功/失败音效。配对成功时自动朗读英文单词。
- **计分系统** — 基础分 + 时间奖励 + 难度倍率，每局结束后展示详细统计。
- **粘贴导入** — 粘贴英文单词列表，自动调用有道词典 API 查询释义，导入前可自由编辑。
- **JSON 导入** — 从 JSON 文件导入单词对。
- **词库管理** — 浏览、编辑、添加、删除单词。可为每个单词添加详细注释（例句、用法等）。
- **备份与恢复** — 通过系统保存对话框导出词库到任意位置，重装后可从文件恢复。
- **错题复习** — 集中复习游戏中出错的单词，可逐条删除或一键清空。
- **离线可用** — 内置 30+ 常用词对，无网络也可直接游戏。API 查询作为补充。

## 截图

（可在此添加截图）

## 系统要求

- Android 5.0 (API 21) 及以上
- 需要网络连接（仅词典查询时需要）

## 下载

从 [Releases](https://github.com/yourusername/match_madness/releases) 页面获取最新 APK。

## 自行构建

### 前置条件

- Flutter SDK 3.0+
- Android SDK
- Java 17

### 构建步骤

```bash
# 克隆仓库
git clone https://github.com/yourusername/match_madness.git
cd match_madness

# 安装依赖
flutter pub get

# 构建 release APK
flutter build apk --release
```

APK 文件在 `build/app/outputs/flutter-apk/app-release.apk`。

### 环境变量（Windows）

```powershell
$env:ANDROID_HOME = "path\to\android-sdk"
$env:JAVA_HOME = "path\to\jdk-17"
```

## 项目结构

```
lib/
├── main.dart                          # 入口
├── models/
│   ├── word_pair.dart                 # 单词对数据模型（含可选注释）
│   ├── game_config.dart               # 游戏难度配置
│   ├── dictionary_result.dart         # API 查询结果包装
│   ├── session_result.dart            # 游戏结果
│   └── word_stats.dart                # 艾宾浩斯曲线单词统计
├── game/
│   ├── word_pool.dart                 # 词库加载、去重、优先级排序
│   ├── game_phase.dart                # 游戏状态机枚举
│   └── scoring.dart                   # 计分公式
├── screens/
│   ├── home_screen.dart               # 主菜单：难度选择、各功能入口
│   ├── game_screen.dart               # 核心游戏界面
│   ├── result_screen.dart             # 结果统计页
│   ├── import_screen.dart             # JSON 文件导入
│   ├── paste_import_screen.dart       # 粘贴 + API 查词导入
│   ├── review_screen.dart             # 错题复习
│   └── word_manager_screen.dart       # 词库管理
├── widgets/
│   ├── match_card.dart                # 配对卡片组件
│   ├── timer_widget.dart              # 倒计时组件
│   └── score_display.dart             # 分数显示
└── services/
    ├── storage_service.dart           # 持久化：文件 + SharedPreferences + 备份
    ├── dictionary_service.dart        # 有道词典 API 集成
    └── sound_service.dart             # TTS + 程序生成 WAV 音效
```

## 数据持久化

词库通过三层策略保存：

1. **应用文档目录** — 主存储
2. **SharedPreferences** — 快速缓存
3. **手动备份** — 「导出」通过系统保存对话框将词库保存到用户选择的位置；「恢复」从用户选择的文件读取

在国产 Android ROM 上，自动的 MediaStore 持久化不可靠。卸载前建议使用手动备份功能。

## 技术栈

- **框架**: Flutter / Dart
- **语音朗读**: flutter_tts
- **音效**: audioplayers（程序生成 WAV 波形）
- **词典 API**: 有道词典 (`dict.youdao.com/jsonapi_s`)
- **文件操作**: file_picker, path_provider
- **持久化**: shared_preferences

## 许可证

MIT