#!/usr/bin/env python3
"""
PhantomKnob Automated Changelog Generator
Parses git commits since the last tag and generates categorized bilingual changelog.
"""

import subprocess
import sys
import re
import os

def run_cmd(cmd):
    result = subprocess.run(cmd, shell=True, capture_output=True, text=True)
    return result.stdout.strip()

def get_latest_tag():
    tag = run_cmd("git describe --tags --abbrev=0 2>/dev/null")
    return tag if tag else ""

def get_commits_since(tag):
    if tag:
        cmd = f'git log {tag}..HEAD --oneline --no-merges'
    else:
        cmd = 'git log --oneline --no-merges -n 20'
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

def categorize_commits(commits):
    categories = {
        'feat': {'zh': '🚀 新特性', 'en': 'Features', 'items': []},
        'fix': {'zh': '🐛 修复', 'en': 'Bug Fixes', 'items': []},
        'docs': {'zh': '📝 文档', 'en': 'Documentation', 'items': []},
        'refactor': {'zh': '⚡ 重构与优化', 'en': 'Refactoring & Optimization', 'items': []},
        'chore': {'zh': '🔧 构建与维护', 'en': 'Chore & Maintenance', 'items': []},
        'other': {'zh': '✨ 其他变更', 'en': 'Other Changes', 'items': []}
    }
    
    for commit in commits:
        match = re.match(r'^(feat|fix|docs|refactor|chore|style|test)(\(.*?\))?:?\s*(.*)', commit, re.IGNORECASE)
        if match:
            ctype = match.group(1).lower()
            msg = match.group(3).strip()
            if ctype in categories:
                categories[ctype]['items'].append(msg)
            else:
                categories['other']['items'].append(commit)
        else:
            categories['other']['items'].append(commit)
            
    return categories

def build_markdown(version, categories):
    from datetime import datetime
    today = datetime.now().strftime('%Y-%m-%d')
    clean_ver = version.lstrip('v')
    
    lines = [f"## [{clean_ver}] - {today}\n"]
    
    # Chinese section
    lines.append("### 🇨🇳 中文")
    has_zh = False
    for key, cat in categories.items():
        if cat['items']:
            has_zh = True
            lines.append(f"#### {cat['zh']}")
            for item in cat['items']:
                lines.append(f"- {item}")
    if not has_zh:
        lines.append("- 常规版本更新与优化")
        
    lines.append("\n---\n")
    
    # English section
    lines.append("### 🇺🇸 English")
    has_en = False
    for key, cat in categories.items():
        if cat['items']:
            has_en = True
            lines.append(f"#### {cat['en']}")
            for item in cat['items']:
                lines.append(f"- {item}")
    if not has_en:
        lines.append("- General updates and improvements")
        
    lines.append("")
    return "\n".join(lines)

def update_changelog_file(new_block, changelog_path="CHANGELOG.md"):
    if not os.path.exists(changelog_path):
        header = "# Changelog\n\nAll notable changes to PhantomKnob will be documented in this file.\n\n"
        existing = ""
    else:
        with open(changelog_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Split after header
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
    print(f"[INFO] Successfully updated {changelog_path}")

def main():
    version = sys.argv[1] if len(sys.argv) > 1 else "v0.9.1"
    last_tag = get_latest_tag()
    print(f"[INFO] Generating changelog for {version} since tag: '{last_tag}'")
    commits = get_commits_since(last_tag)
    print(f"[INFO] Found {len(commits)} commits")
    
    categories = categorize_commits(commits)
    markdown_block = build_markdown(version, categories)
    update_changelog_file(markdown_block)

if __name__ == '__main__':
    main()
