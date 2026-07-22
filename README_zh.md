<p align="center">
  <a href="https://github.com/benwu232/PhantomKnob">
    <picture>
      <source srcset="README_assets/logo-dark.svg" media="(prefers-color-scheme: dark)">
      <source srcset="README_assets/logo-light.svg" media="(prefers-color-scheme: light)">
      <img src="README_assets/logo-light.svg" alt="PhantomKnob Logo" width="128">
    </picture>
  </a>
</p>

<p align="center"><b>PhantomKnob</b> - 在 macOS 上通过触控板旋转手势模拟平滑的物理旋钮控制。</p>

<p align="center">
  <a href="README.md">English</a> |
  <a href="README_zh.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg">
    <img alt="下载 DMG" src="https://img.shields.io/badge/下载-macOS%20DMG-blue?logo=apple&style=for-the-badge" />
  </a>
  <a href="https://github.com/benwu232/PhantomKnob/actions"><img alt="构建状态" src="https://img.shields.io/github/actions/workflow/status/benwu232/phantom_knob_mac/release.yml?style=flat-square&label=构建" /></a>
</p>

<p align="center">
  <!-- 用户可以后续放置自己的手势录屏 GIF 动图 -->
  <img src="README_assets/screenshot.png" alt="PhantomKnob 界面" width="600" style="max-width: 100%; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);" />
</p>

---

### 核心特性
*   🎛️ **物理旋钮模拟：** 利用触控板上的双指绝对坐标触控，精确识别旋转手势。
*   🌍 **全局辅助功能控制：** 通过热键触发悬浮窗，在鼠标指针下顺滑调节任意滑块（如音量、亮度、浏览器进度条、滚动条等）。
*   ⚡ **智能检测模式：** 结合触觉震动反馈和科学的检测流，确保触控板硬件兼容性。

### 安装方法

#### 一键终端安装
```bash
curl -fsSL https://raw.githubusercontent.com/benwu232/PhantomKnob/main/install.sh | bash
```

#### 手动下载安装
1.  点击上方下载徽章**下载**最新的 `.dmg` 安装包。
2.  将 `PhantomKnob.app` **拖拽**至 `/Applications` 文件夹中。
3.  **启动**应用，并在系统设置提示时授予**辅助功能权限 (Accessibility Permissions)**（模拟系统按键和滑块控制必须使用此权限）。

### 开源协议
本软件基于 [MIT 协议](LICENSE) 开源。
