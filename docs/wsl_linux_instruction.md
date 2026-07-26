# Codex 访问 WSL Linux 系统指南

本文说明在 Windows + WSL 环境中，如何让 Codex 协助检查、修改并运行 WSL 内的项目。

## 1. 先判断能否直接访问

在 Codex 所在的 Windows 执行环境中运行：

```powershell
wsl -l -v
wsl -d <发行版名> -- bash -lc "pwd && id"
```

如果能列出目标发行版，并能执行 Linux 命令，Codex 可以直接通过 `wsl -d` 操作项目，例如：

```powershell
wsl -d Rocky-8.10 -- bash -lc "cd /home/ray/ic/project && ls -la"
```

## 2. 常见问题：终端能进 WSL，但 Codex 看不到发行版

WSL 发行版的注册信息与交互会话可能属于另一个 Windows 用户或执行上下文。此时用户终端中可见：

```text
ray@HOST:~$
```

但 Codex 侧执行：

```powershell
wsl -d Rocky-8.10
```

可能返回：

```text
WSL_E_DISTRO_NOT_FOUND
```

这不代表 WSL 镜像损坏，只表示 Codex 不能直接附着到该用户的 WSL 发行版或终端。

不要重复执行 `wsl --import-in-place`。如果 Windows 提示 `ERROR_ALREADY_EXISTS`，说明发行版已经注册。

## 3. 推荐方式：使用 F 盘共享目录桥接

Windows 磁盘通常会自动挂载到 WSL，例如：

```text
F:\                  -> /mnt/f
```

可以在 WSL 中启动一个桥接脚本。Codex 将命令写入 F 盘；桥接脚本在 WSL 内、以当前 Linux 用户身份执行命令，并把结果写回 F 盘。

### 3.1 目录约定

```text
F:\tsmc40_bridge\command.sh     # Codex 下发的单次命令
F:\tsmc40_bridge\result.log     # Linux 执行输出
F:\tsmc40_bridge\status.txt     # bridge 状态
F:\tsmc40_bridge\STOP           # 停止标记
F:\tsmc40_bridge.sh              # bridge 程序
```

### 3.2 启动 bridge

在目标 WSL 终端中启动一次：

```bash
nohup bash /mnt/f/tsmc40_bridge.sh > /mnt/f/tsmc40_bridge_host.log 2>&1 &
```

确认状态：

```bash
cat /mnt/f/tsmc40_bridge/status.txt
```

正常状态应包含：

```text
ready
project=/home/<linux-user>/<project-path>
pid=<pid>
```

启动后，Codex 可以通过共享目录进行非交互式调度。它并不是远程桌面，也不能直接看到或控制用户的终端窗口。

### 3.3 停止 bridge

完成工作后，在 WSL 中运行：

```bash
touch /mnt/f/tsmc40_bridge/STOP
```

确认：

```bash
cat /mnt/f/tsmc40_bridge/status.txt
```

应显示 `stopped`。下次需要时重新执行启动命令即可。

## 4. bridge 的适用范围与安全要求

bridge 内执行的命令拥有启动它的 Linux 用户权限。因此：

- 仅在自己信任的 Codex 会话中启动。
- 将工作目录固定在明确的项目目录，例如 `/home/ray/ic/project`。
- 不要把 bridge 配置为 root 运行。
- 不要让它执行来自不可信共享目录或不可信网络位置的命令。
- 对删除、覆盖、重新导入 WSL 镜像等操作，先要求 Codex说明目标和影响。
- 使用独立输出目录，例如 `results/`、`logs/`，不要直接覆盖已验证结果。

## 5. EDA/数字 IC 项目的建议环境检查

连接成功后，优先检查：

```bash
pwd
id
command -v dc_shell pt_shell icc2_shell calibre
env | grep -E 'LM_LICENSE_FILE|SNPSLMD_LICENSE_FILE|PDK|TSMC'
find . -maxdepth 2 -type f | sort
```

建议按如下顺序调通：

1. 综合：标准单元 `.db/.lib` 可被 DC 加载并映射。
2. 物理库：NDM 或 LEF、技术文件和 TLU+ 可被 ICC2 加载。
3. 后端：floorplan、placement、CTS、routing。
4. 提取与 STA：SPEF 可被 PrimeTime 读取。
5. 导出：GDS stream-out 与规则检查。

对于 SRAM、ROM、PLL、IO 等 macro，除了逻辑模型外必须确认物理和时序交付件齐全：`.db/.lib`、Verilog、LEF/NDM、GDS，以及需要时的 CDL/SPICE。

## 6. 故障排查

| 现象 | 原因与处理 |
| --- | --- |
| `WSL_E_DISTRO_NOT_FOUND` | Codex 所在执行上下文看不到用户的 WSL 发行版；使用 bridge。 |
| `ERROR_ALREADY_EXISTS` | 发行版已注册；不要重复导入。 |
| `WSL_E_WSL2_NEEDED` | Windows 尚未启用 WSL2/Virtual Machine Platform，需管理员启用并重启。 |
| `command.sh` 长时间未被处理 | bridge 已退出；查看 `status.txt` 和 `/mnt/f/tsmc40_bridge_host.log`，然后重新启动。 |
| 同时启动多个 bridge | 可能重复执行同一任务；保留一个进程即可。 |
| EDA 工具在用户终端可用、bridge 中不可用 | 检查 `.bashrc`、module setup、许可证变量和工具 PATH；bridge 的 `nohup` 环境可能较精简。 |

## 7. 最小工作流

1. 将项目放在 WSL 的 Linux 文件系统中，例如 `/home/ray/ic/project`。
2. 确认 Windows 共享盘在 WSL 中为 `/mnt/f`。
3. 在 WSL 启动 bridge。
4. 告知 Codex 项目绝对路径与目标。
5. Codex 先做只读诊断，再修改脚本并逐阶段运行。
6. 完成后检查 `results/`、`reports/` 和日志；停止 bridge。
