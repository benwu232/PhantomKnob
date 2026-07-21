<p align="center">
  <a href="https://github.com/benwu232/PhantomKnob">
    <picture>
      <source srcset="README_assets/logo-dark.svg" media="(prefers-color-scheme: dark)">
      <source srcset="README_assets/logo-light.svg" media="(prefers-color-scheme: light)">
      <img src="README_assets/logo-light.svg" alt="PhantomKnob Logo" width="128">
    </picture>
  </a>
</p>

<p align="center"><b>PhantomKnob</b> - Smooth physical-dial simulation using trackpad rotation gestures on macOS.</p>

<p align="center">
  <a href="README.md">English</a> |
  <a href="README_zh.md">简体中文</a>
</p>

<p align="center">
  <a href="https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg">
    <img alt="Download DMG" src="https://img.shields.io/badge/Download-macOS%20DMG-blue?logo=apple&style=for-the-badge" />
  </a>
  <a href="https://github.com/benwu232/PhantomKnob/actions"><img alt="Build status" src="https://img.shields.io/github/actions/workflow/status/benwu232/phantom_knob_mac/release.yml?style=flat-square&label=build" /></a>
</p>

<p align="center">
  <!-- Users can place their own demonstration screen recording here -->
  <img src="README_assets/screenshot.png" alt="PhantomKnob Interface" width="600" style="max-width: 100%; border-radius: 8px; box-shadow: 0 4px 12px rgba(0,0,0,0.15);" />
</p>

---

### Key Features
*   🎛️ **Physical Knob Simulation:** Uses absolute 2-finger touch locations on trackpads to detect rotational gestures.
*   🌍 **Global Accessibility Control:** Hotkey-triggered overlay helps you control sliders (Volume, Brightness, scrollbars) anywhere under your mouse cursor.
*   ⚡ **Intelligent Detection Mode:** Active vibration feedback and smart detection sequence ensure hardware compatibility.

### Installation

#### One-Click Install (Via Terminal)
```bash
curl -fsSL https://raw.githubusercontent.com/benwu232/PhantomKnob/master/install.sh | bash
```

#### Manual Download
1.  **Download** the latest `.dmg` install package from the badge above.
2.  **Drag and drop** `PhantomKnob.app` to your `/Applications` folder.
3.  **Launch** it and grant **Accessibility Permissions** (辅助功能权限) in System Settings when prompted.

### License
This software is released under the [MIT License](LICENSE).
