# 自动检测 project.yml 中的 MARKETING_VERSION 以供本地发布确认 规格说明

## 目的
优化 macOS 本地发布脚本 `scripts/local_release.sh`，使其在执行时能够自动提取 `PhantomKnob/project.yml` 里的当前 `MARKETING_VERSION`，并作为默认的 Git Tag (前缀 `v`) 供用户回车确认，减少人工输入及因拼写错误引入的版本号不一致风险。

## 规格要求
1. 在 `scripts/local_release.sh` 中添加自动读取 `PhantomKnob/project.yml` 中 `MARKETING_VERSION` 配置的逻辑。
2. 在输入版本 Tag 的交互环节，输出检测到的项目版本，并显示提示 `(默认: v<MARKETING_VERSION>，回车直接确认)`。
3. 若用户直接回车，脚本应当使用 `v<MARKETING_VERSION>` 作为 `TAG_VERSION`；若用户有其他输入，则以用户输入为准。
4. 对最终的版本 Tag 执行严格的正则匹配检查 `^v[0-9]+\.[0-9]+\.[0-9]+`，格式不匹配时报错并终止执行。
