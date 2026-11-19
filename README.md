# kurasagi

`kurasagi` 是一个面向 Windows 24H2 - 25H2 的 PatchGuard 绕过完整 POC（Proof of Concept）。

关于绕过原理的详细说明，请参阅 `product` 分支中的 PDF 论文。

**如果出现与 `CRITICAL_STRUCTURE_CORRUPTION`（PatchGuard）相关的蓝屏，欢迎提交 issue。**

## 免责声明

1. **本项目仅限教育与安全研究用途！**
2. 运行前请勿开启基于虚拟化的安全功能（VBS / HVCI / 内存完整性 / Hyper-V 等），否则会蓝屏！
3. 驱动建议使用 [KDU](https://github.com/hfiref0x/KDU) 加载，也兼容 [kdmapper](https://github.com/TheCruZ/kdmapper)。
4. 经实测发现：驱动加载后，使用 `NonPagedPoolExecute`（或 `NonPagedPool`，两者表现相同）分配的池内存不可执行。该问题与驱动加载无关，修复进展会在此更新。

## 环境要求

- Windows 10/11 x64（目标为 24H2 - 25H2）
- Visual Studio 2022（含「使用 C++ 的桌面开发」工作负载）
- Windows Driver Kit（WDK），且必须完整安装（需要 `WindowsDriver.common.targets` 与 `Microsoft.DriverKit.Build.Tasks.*.dll`）

## 编译

在项目根目录双击运行 `build.bat` 即可一键编译（默认 `Release | x64`）：

```bat
build.bat                       :: 默认 Release x64
build.bat Debug x64             :: 调试版
build.bat Release ARM64         :: ARM64
build.bat Release x64 nopause   :: 不暂停（适合 CI）
```

编译产物位于 `x64\Release\kurasagi.sys`。

脚本会自动完成：

- 定位 Visual Studio 的 MSBuild（优先选择带 `WindowsKernelModeDriver10.0` 驱动工具集的实例）
- 校验 WDK 头文件与 DriverKit 构建任务是否完整，自动跳过损坏的 WDK 版本
- 编译整个解决方案并输出完整日志 `build.log`，失败时生成环境诊断 `build.diag.txt`

## 加载

以管理员权限运行 KDU，手动映射驱动：

```bat
kdu.exe -map C:\path\to\x64\Release\kurasagi.sys
```

如自动选择 provider 失败，可用 `-prv <ProviderID>` 指定。

驱动已按 KDU 的「driverless」要求配置：

- 驱动类型为 **WDM**（不依赖 KMDF / WDFLDR）
- 关闭 `/GS`，入口点为 `DriverEntry`（非 `GsDriverEntry`）
- 关闭 CFG，仅导入 `ntoskrnl.exe`，不使用 SEH
- `DriverEntry` 忽略加载器传入的参数，不依赖 `DriverObject` / `RegistryPath`
- 未注册 `DriverUnload`（映射加载无法卸载）

加载前可以自行确认产物：

```bat
dumpbin /headers x64\Release\kurasagi.sys | findstr /i entry
dumpbin /imports x64\Release\kurasagi.sys
```

## 注意事项

- 手动映射的驱动**无法卸载**，请务必在虚拟机中测试
- 映射驱动不在 `PsLoadedModulesList` 中，PatchGuard 相关结构被修改后仍可能触发检测，属于该 POC 本身的实验性风险
- 使用前请创建快照；出现蓝屏时记录 dump 并提交 issue

## 运行截图

![proof](assets/proof.png)

## 项目结构

```
kurasagi.sln            解决方案
build.bat               一键编译脚本
kurasagi/               主驱动：PatchGuard 绕过
  Entry.cpp             驱动入口
  Global.*              运行时变量与特征码定义
  Module/               Timer / Context7 / Misc / Barricade 各绕过模块
  Util/                 内存操作、算术与 PE 解析工具
VerifyPg/               用于验证的测试驱动
assets/                 图片资源
```

## 致谢

以下是完成本项目过程中参考的资料与思路，感谢作者们的分享：

+ https://blog.tetrane.com/downloads/Tetrane_PatchGuard_Analysis_RS4_v1.01.pdf
+ https://blog.can.ac/2024/06/28/pgc-garbage-collecting-patchguard/
+ https://shhoya.github.io/windows_pgintro.html
