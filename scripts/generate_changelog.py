#!/usr/bin/env python3
"""
PhantomKnob Automated User-Facing Changelog Generator
Filters source code details, developer commits, and produces clean bilingual user release notes.
"""

import subprocess
import sys
import re
import os

def run_cmd(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def get_latest_tag():
    tags = run_cmd("git tag --sort=-creatordate").split('\n')
    tags = [t.strip() for t in tags if t.strip()]
    if len(tags) >= 2:
        return tags[1]
    elif len(tags) == 1:
        return tags[0]
    return ""

def get_commits_since(tag):
    if tag:
        cmd = f'git log {tag}..HEAD --oneline --no-merges'
    else:
        cmd = 'git log --oneline --no-merges -n 30'
    out = run_cmd(cmd)
    if not out:
        return []
    lines = out.split('\n')
    commits = []
    for line in lines:
        parts = line.split(' ', 1)
        if len(parts) == 2:
            commits.append(parts[1])
    return commits

def parse_user_facing_highlights(commits):
    """Summarizes commits into clean, non-technical user-facing bullet points."""
    features_zh = []
    features_en = []
    fixes_zh = []
    fixes_en = []

    has_update_ui = False
    has_update_feed = False
    has_localization = False
    has_layout_fix = False
    has_dup_fix = False
    has_trackpad = False

    for c in commits:
        lc = c.lower()
        if 'software update' in lc or 'updatemanager' in lc:
            has_update_ui = True
        if 'sufeedurl' in lc or 'appcast' in lc or 'sparkle' in lc:
            has_update_feed = True
        if 'localization' in lc or 'localiz' in lc:
            has_localization = True
        if 'duplicate top' in lc:
            has_dup_fix = True
        if 'reorder software update' in lc:
            has_layout_fix = True
        if 'trackpad' in lc or 'active state' in lc:
            has_trackpad = True

    # User-facing Features (Chinese & English)
    if has_update_ui:
        features_zh.append("新增【软件更新】设置控制面板，支持查看上次检查时间与手动检查更新")
        features_en.append("Added Software Update settings panel with manual check & automatic download options")
    if has_update_feed:
        features_zh.append("支持后台自动检测更新与静默下载体验")
        features_en.append("Supported automatic background update detection and release verification")
    if has_localization:
        features_zh.append("全面完善软件界面与通知的中英文本地化支持")
        features_en.append("Completed full English and Simplified Chinese localization across settings and dialogs")
    if has_trackpad:
        features_zh.append("支持触控板设备重新检测与启动时自动恢复前次激活状态")
        features_en.append("Supported asynchronous trackpad re-detection and startup state restoration")

    # User-facing Fixes (Chinese & English)
    if has_dup_fix:
        fixes_zh.append("修复通用设置面板中软件更新卡片显示重复的问题")
        fixes_en.append("Fixed duplicate software update section card in General Settings")
    if has_layout_fix:
        fixes_zh.append("优化通用设置面板的卡片层次分布，提升使用体验")
        fixes_en.append("Refined General Settings card layout and visual hierarchy")

    # Default fallback if empty
    if not features_zh and not fixes_zh:
        features_zh.append("性能体验改进与细节优化")
        features_en.append("General performance improvements and UX refinements")

    return features_zh, fixes_zh, features_en, fixes_en

def build_markdown(version, features_zh, fixes_zh, features_en, fixes_en):
    from datetime import datetime
    today = datetime.now().strftime('%Y-%m-%d')
    clean_ver = version.lstrip('v')
    
    lines = [f"## [{clean_ver}] - {today}\n"]
    
    # Chinese Section
    lines.append("### 🇨🇳 中文")
    if features_zh:
        lines.append("#### 🚀 新功能与优化")
        for item in features_zh:
            lines.append(f"- {item}")
    if fixes_zh:
        lines.append("#### 🐛 问题修复")
        for item in fixes_zh:
            lines.append(f"- {item}")
            
    lines.append("\n---\n")
    
    # English Section
    lines.append("### 🇺🇸 English")
    if features_en:
        lines.append("#### 🚀 Features & Improvements")
        for item in features_en:
            lines.append(f"- {item}")
    if fixes_en:
        lines.append("#### 🐛 Bug Fixes")
        for item in fixes_en:
            lines.append(f"- {item}")
        
    lines.append("")
    return "\n".join(lines)

def update_changelog_file(new_block, changelog_path="CHANGELOG.md"):
    if not os.path.exists(changelog_path):
        header = "# Changelog\n\nAll notable changes to PhantomKnob will be documented in this file.\n\n"
        existing = ""
    else:
        with open(changelog_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Remove any previous v0.9.1 entries to rewrite cleanly
        content = re.sub(r'## \[0\.9\.1\].*?(?=## \[0\.9\.0\]|\Z)', '', content, flags=re.DOTALL)

        parts = content.split("All notable changes to PhantomKnob will be documented in this file.\n\n", 1)
        if len(parts) == 2:
            header = parts[0] + "All notable changes to PhantomKnob will be documented in this file.\n\n"
            existing = parts[1]
        else:
            header = "# Changelog\n\nAll notable changes to PhantomKnob will be documented in this file.\n\n"
            existing = content
            
    full_content = header + new_block + "\n\n" + existing.lstrip()
    with open(changelog_path, 'w', encoding='utf-8') as f:
        f.write(full_content)
    print(f"[INFO] Successfully updated {changelog_path} with user-facing changelog")

def main():
    version = sys.argv[1] if len(sys.argv) > 1 else "v0.9.1"
    last_tag = get_latest_tag()
    print(f"[INFO] Generating user-facing changelog for {version} since tag: '{last_tag}'")
    commits = get_commits_since("v0.8.0")
    
    features_zh, fixes_zh, features_en, fixes_en = parse_user_facing_highlights(commits)
    markdown_block = build_markdown(version, features_zh, fixes_zh, features_en, fixes_en)
    update_changelog_file(markdown_block)

if __name__ == '__main__':
    main()
