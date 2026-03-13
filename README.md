# Visualization for Hexo

一个基于 Qt/QML 的 Hexo 可视化管理工具，面向本地博客内容编辑与发布流程。

## 功能概览

- 文章列表浏览与切换
- Markdown 编辑与预览联动
- Hexo 常用命令集成（构建、发布等）
- Git 操作能力封装（提交、状态查询等）
- QML 现代化界面与自定义无边框窗口

## 技术栈

- C++17
- Qt 6（QML + Qt Quick）
- MSBuild（Visual Studio 工具链）
- PowerShell（构建与打包脚本）

## 环境要求

- Windows 10/11
- Visual Studio 2022（建议包含 MSVC x64 编译工具）
- Qt 6.8以上（当前工程使用 Qt/MSBuild 集成）
- 可选：Node.js、Hexo CLI、Git（用于实际博客流程）

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

## 构建与打包

- 调试构建脚本：`Visualization for Hexo/scripts/build.ps1`
- 发布构建/打包入口：`Visualization for Hexo/scripts/package.ps1`

发布构建示例：

```powershell
& ".\Visualization for Hexo\scripts\package.ps1" -Configuration Release -Platform x64
```

说明：`package.ps1` 已完成 Release 编译、`windeployqt` 依赖收集，并输出可分发 zip 包。

## 目录结构

```text
Visualization for Hexo/
	Visualization for Hexo.slnx
	libs/material-components-qml/   # QML 组件库（随仓库提交）
	Visualization for Hexo/
		main.cpp
		main.qml
		src/
			core/
			adapters/
			models/
		qml/
		components/
		web/markdown-editor/
		scripts/
			build.ps1
			package.ps1
```

## 开发建议

- 优先使用脚本进行统一构建，避免手动参数不一致
- 提交前执行一次 Debug 构建，确保工程可编译
- 发布前建议在干净环境做一次解压即运行验证，确认依赖齐全

## 许可证

项目采用MIT许可证，详见根目录 LICENSE 文件。

`libs/material-components-qml` 及其子目录遵循各自上游许可证，请在对应目录查看 LICENSE 文件。
