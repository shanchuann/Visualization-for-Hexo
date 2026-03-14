<p align="center">
	<img src="https://files.seeusercontent.com/2026/03/14/Fqj9/pasted-image-1773481026362.webp" alt="Visualization for Hexo" />
</p>

<p align="center">
	<img src="https://img.shields.io/badge/project-Visualization_for_Hexo-4c566a" alt="project" />
	<img src="https://img.shields.io/badge/stack-Qt%20%2B%20QML-0f766e" alt="qt-qml" />
	<img src="https://img.shields.io/badge/blog-Hexo-2563eb" alt="hexo" />
	<img src="https://img.shields.io/badge/platform-Windows-0ea5e9" alt="windows" />
	<img src="https://img.shields.io/badge/language-C%2B%2B17-16a34a" alt="cxx17" />
</p>


一个基于 Qt/QML 的 Hexo 可视化管理工具，面向本地博客内容编辑与发布流程。

## 功能概览

- 文章列表浏览与切换
- Markdown 编辑与预览联动
- Front Matter 解析增强（title/date/categories/tags/views/cover/description）
- 缺失 description 时可自动调用 GLM-4.7-flash 生成摘要
- Hexo 常用命令集成（构建、发布等）
- 多博客管理支持

## 技术栈

- C++17
- Qt 6（QML + Qt Quick）
- MSBuild（Visual Studio 工具链）
- PowerShell（构建与打包脚本）

## 环境要求

- Windows 10/11
- Visual Studio 2022（建议包含 MSVC x64 编译工具）
- Qt 6.8+（MSVC 2022 64-bit，Qt/MSBuild 集成）
- 可选：Node.js、Hexo CLI、Git（用于实际博客流程）

## 如何使用

直接下载预编译版本（Release 页面）并解压运行exe文件即可，或者按照下面的快速开始指南从源代码构建。

## 快速开始

1. 克隆仓库

```powershell
git clone https://github.com/shanchuann/Visualization-for-Hexo.git
cd Visualization-for-Hexo
```

2. 调试构建

```powershell
& ".\Visualization for Hexo\scripts\build.ps1"
```

3. 运行程序

```powershell
& ".\Visualization for Hexo\x64\Debug\Visualization for Hexo.exe"
```

> 说明：默认构建配置为 Debug，输出路径为 `Visualization for Hexo\x64\Debug`。你也可以指定 Release 构建（不推荐，Release 目录下，系统不会自动帮你补全依赖，必须用 windeployqt 或 package.ps1 复制 DLL，否则在没有全局 Qt 环境的机器上会缺少 DLL 无法运行。）。

1. GLM 自动描述（可选）

```powershell
$env:ZHIPUAI_API_KEY = "你的 API Key"
```

说明：当文章 front matter 没有 `description` 且正文不为空时，应用会默认调用 `glm-4.7-flash` 自动生成描述并写回文章头。

需要配置相关环境变量（例如 `ZHIPUAI_API_KEY`），并确保 `glm-4.7-flash` 可执行文件在系统 PATH 中。

## 构建与打包

- 调试构建脚本：`Visualization for Hexo/scripts/build.ps1`
- 发布构建/打包脚本：`Visualization for Hexo/scripts/package.ps1`

调试构建示例(把路径换成你本机 Qt 安装目录)：

```powershell
& ".\Visualization for Hexo\scripts\package.ps1" -Configuration Debug -QtInstall "D:\Qt\6.8.0\msvc2022_64"
```

发布构建示例：

```powershell
& ".\Visualization for Hexo\scripts\package.ps1" -Configuration Release -QtInstall "D:\Qt\6.8.0\msvc2022_64"
```

常用参数：

- `-QtInstall` 指定 Qt 安装目录（等价于设置 `QT_ROOT_DIR`）
- `-Toolset` 覆盖 `PlatformToolset`（例如 `v143`）
- `-Clean` 执行 Clean + Build
- `-DistRoot` 指定 dist 输出目录
- `-IncludePdb` 将 PDB 复制进包
- `-SkipKill` 跳过停止正在运行的应用

说明：

- `package.ps1` 会完成 Release 编译、`windeployqt` 依赖收集，并输出可分发 zip 包，同时拷贝 README 和 LICENSE。
- Debug 打包需要对应版本的 Qt Debug DLL（`Qt6* d.dll`），建议用 `-QtInstall` 或设置 `QT_ROOT_DIR` 来保证依赖版本一致。

## CI/CD

- Push 到 `main` 会执行 cppcheck 静态检查并生成 Windows 打包产物
- Push `main` 会自动发布 GitHub Release（预发布）
- Push `v*` tag 或手动触发工作流时，会发布 GitHub Release（tag 发布为正式版本，手动触发为预发布）
- GitHub Actions 使用 `install-qt-action` 并缓存 Qt，打包时会自动解析 `QT_ROOT_DIR` 以确保 `windeployqt` 版本匹配

## 目录结构

```text
Visualization for Hexo/
├── Visualization for Hexo.slnx
├── libs/
│   └── material-components-qml/      # QML 组件库（随仓库提交）
├── Visualization for Hexo/
│   ├── main.cpp
│   ├── main.qml
│   ├── src/
│   │   ├── core/
│   │   ├── adapters/
│   │   └── models/
│   ├── qml/
│   ├── components/
│   ├── web/
│   │   └── markdown-editor/
│   └── scripts/
│       ├── build.ps1
│       └── package.ps1
```

## 开发建议

- 优先使用脚本进行统一构建，避免手动参数不一致
- 提交前本地执行一次 Debug 构建，确保工程可编译
- 发布前建议在干净环境做一次解压即运行验证，确认依赖齐全

## 许可证

项目采用MIT许可证，详见根目录 LICENSE 文件。
`libs/material-components-qml` 及其子目录遵循各自上游许可证，请在对应目录查看 LICENSE 文件。
