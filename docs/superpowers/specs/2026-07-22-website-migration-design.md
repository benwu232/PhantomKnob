# 2026-07-22 PhantomKnob 官网迁移与分发部署设计规格说明书

本文档规定了将官网代码（静态网站）从开发仓库 `phantom_knob_mac` 迁移至公共分发仓库 `PhantomKnob` 的设计方案、步骤和发布机制，实现开发库与分发对外资产的物理解耦。

---

## 1. 目标

* **仓库解耦**：将开发仓库 [phantom_knob_mac](file:///Users/wb/work/phantom_knob_mac) 与官网静态文件解耦，开发库只聚焦于 Swift macOS 客户端源码及相关构建脚本。
* **分发库自包含**：将静态官网移至公共分发库 [PhantomKnob](file:///Users/wb/work/PhantomKnob)，支持通过该仓库的 GitHub Pages 服务直接免费部署，并支持绑定自定义域名 `phantomknob.com`。
* **路径与下载链接更新**：在迁移后的静态落地页中，将下载路径由原有的本地相对路径更新为分发库固定的最新版本 DMG 链接。

---

## 2. 迁移方案设计 (A1 彻底迁移)

### 2.1 文件转移矩阵

将开发库中现有的网站静态资源彻底移动到分发库的根目录：

| 源路径 (在开发库 `phantom_knob_mac` 中) | 目标路径 (在分发库 `PhantomKnob` 中) | 职责说明 |
|:---|:---|:---|
| `website/index.html` | `index.html` | 官网落地页主 HTML |
| `website/style.css` | `style.css` | 落地页样式表 |
| `website/privacy.html` | `privacy.html` | 隐私政策合规页 |
| `website/terms.html` | `terms.html` | 服务条款合规页 |
| `website/icon_compare.html` | `icon_compare.html` | 图标对比展示页 |
| `website/assets/` | `assets/` | Logo、演示图、界面截图等媒体资源文件夹 |
| *无* | `CNAME` | 用于配置 GitHub Pages 自定义域名的纯文本文件 |

> [!NOTE]
> 迁移后，开发库 `phantom_knob_mac` 中的 `website/` 目录将直接使用 `git rm -r` 删除。

### 2.2 官网代码适配调整

#### 2.2.1 下载直链接管
由于分发包不会以相对路径方式存放在网站项目下，必须将官网下载按钮链接替换为 GitHub 最新 Release 发布件的固定地址。
* **修改位置**：`index.html` 中 `id="free-download-btn"` 的按钮链接，以及 hero 部分的 `Download Free Edition` 链接。
* **新链接地址**：
  `https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg`

#### 2.2.2 隐私与条款链接适配
由于网站迁移到了根目录，原本在 `index.html` 中指向 `privacy.html` 和 `terms.html` 的链接保持 `privacy.html` 和 `terms.html` 相对引用即可，无需修改。

---

## 3. GitHub Pages 部署设计

在 GitHub 网页控制台针对 `benwu232/PhantomKnob` 仓库进行如下配置：
1. **GitHub Pages 激活**：在仓库设置的 `Pages` 选项卡中启用服务。
2. **源分支设置**：
   * Source: `Deploy from a branch`
   * Branch: `main`
   * Folder: `/ (root)`
3. **访问地址**：
   * 默认部署地址为：`https://benwu232.github.io/PhantomKnob/`
   * 暂不新增 `CNAME` 文件，后续有自定义域名需求时再进行配置。

---

## 4. 验证计划

### 4.1 迁移准确性验证
* 确认分发库根目录下所有资产与开发库原 `website/` 目录哈希完全一致。
* 检查 `index.html` 中所有的相对路径引用（如 `assets/logo.png`、`style.css`、`privacy.html`）在目录层级扁平化移动后依然能够正确加载。

### 4.2 链接有效性校验
* 验证下载按钮在浏览器中能正确拉起并跳转 to `https://github.com/benwu232/PhantomKnob/releases/latest/download/PhantomKnob.dmg`。

### 4.3 开发库纯洁性验证
* 确认开发库 `phantom_knob_mac` 中的 `website/` 文件夹已被干净删除。
* 运行 `git status` 确认开发库无 website 的残留追踪。
