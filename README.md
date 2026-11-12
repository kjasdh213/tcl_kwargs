# kwargs

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)

在 Tcl 8.5 中模拟关键字参数 (keyword arguments) 传参。

Tcl 8.5 原生不支持关键字参数，所有参数都是位置参数。
当函数参数数量较多时，调用代码的可读性会变得很差。
`kwargs` 模块提供了 2 种方案来解决这个问题，各有优劣。

该 README 不会复述代码文档字符串的内容。

## 系统编码问题

`kwargs.tcl` 代码包含中文，且以 UTF-8 编码保存。
在 Windows 中文系统中，Tcl 解释器默认系统编码为 `cp936`。
直接执行 UTF-8 编码的 Tcl 脚本时，中文字符会因编码不匹配而变成乱码。

所以，在加载包前需要先处理系统编码问题。

```tcl
encoding system utf-8
```

这会修改整个 Tcl 进程的行为，但通常不会破坏任何功能。

另一种办法是把所有中文替换成英文。

## 依赖

- Tcl 8.5+
- `struct::set` 来自 tcllib
  用于计算必选关键字与可选关键字的交集（`::kwargs::_check_formal_parameters` 中调用）。

## 加载包

### 方案 1：加载包（推荐）

```tcl
lappend auto_path {/path/to/kwargs/dir}  ;# kwargs.tcl 所在目录，或其上级目录
package require kwargs
```

- `package require`：Tcl 的包管理机制，根据 [`pkgIndex.tcl`](pkgIndex.tcl) 自动定位并加载包。
  需要先将包所在目录添加到 `auto_path`。
- 适合作为正式包管理，推荐在正式项目中使用。

### 方案 2：直接执行

```tcl
source kwargs.tcl
```

- `source`：直接执行脚本文件。不依赖包管理机制。无需配置 `auto_path`，也无需 `pkgIndex.tcl`。
- 适合快速测试或临时使用。
- `::kwargs` 命名空间强制定义在全局（通过 `namespace eval ::kwargs`），所有内部函数调用均使用 `::kwargs::` 绝对路径，
  因此无论从哪个命名空间执行 `source`，都能正确加载和使用。

## 方案对比

| 特性 | `fake_wrap` | `inject` |
| --- | --- | --- |
| 真正的关键字参数 | 否（本质是位置传参） | 是 |
| 参数顺序无关 | 否 | 是 |
| 可选参数默认值 | 否 | 是 |
| 未知关键字检测 | 否 | 是 |
| 性能 | 快（约 5-6 倍于 inject） | 较慢 |
| 适用场景 | 快速文档化、性能敏感 | 正式 API、参数较多 |

## 与 tcllib tepam 的对比

[tepam](https://core.tcl-lang.org/tcllib/doc/trunk/embedded/md/tcllib/files/modules/tepam/tepam_introduction.md)
（TEPAM，全称 *Tcl's Enhanced Procedure and Argument Manager*，Tcl 增强过程与参数管理器）
是 tcllib 中另一套用于管理过程与参数的工具。
与 `kwargs` 的定位有本质区别：`kwargs` 是“不改变 `proc` 的前提下补足关键字传参”的轻量工具，
而 tepam 提供了一整套 *替代* `proc` 的过程声明框架。

```tcl
# kwargs：函数仍是普通 proc，仅在需要时借助 inject 解析 args
proc greet_user {args} {
    ::kwargs::inject $args {-name} {-greeting "你好" -suffix "!"}
    return "${greeting}, ${name}${suffix}"
}

# tepam：用 tepam::procedure 按新语法重新声明，参数在 attributes 中说明
tepam::procedure {greet_user} {
    -args {
        {-name   -type string -required}
        {-greeting -default "你好"}
        {-suffix    -default "!"}
    }
} {
    return "${greeting}, ${name}${suffix}"
}
```

### 设计理念不同

| 关注点 | `kwargs` | tepam |
| --- | --- | --- |
| 定位 | 轻量实用工具：给现有代码补上关键字传参 | 一整套替代 `proc` 的过程声明与参数管理框架 |
| 是否替代 `proc` | 否。`fake_wrap` 包装调用、`inject` 在函数体内解析 | 是。须用 `tepam::procedure` 重新声明过程 |
| 对已有函数的影响 | 函数定义几乎不用改；调用处按需包装即可 | 须按 tepam 语法重写声明才能获得关键字传参 |
| 真正的关键字参数 | `inject`：是 | 是 |
| 参数类型 / 取值范围 / 选择列表校验 | 无（只做存在性、默认值、未知关键字检查） | 有，并在 body 执行前自动校验 |
| 帮助 / usage 生成 | 无，靠代码内文档字符串 | 声明即文档，可自动生成 help |
| 交互式参数 GUI | 无 | 有 `tepam::argument_dialogbox` |
| 支持子命令(subcommand) | 无 | 是（过程名可含空格逐级生成） |
| 参数调用风格 | 仅关键字在前（Tcl/Tk 常规风格） | 可选 named-first 或 unnamed-first 两种风格，`--` 分隔 |
| 运行时开销 | `inject`/`fake_wrap` 各有一次额外封装 | 每次调用都执行一次参数管理器（校验+类型检查） |

### 取舍建议

- 若只想给现有代码**临时补上更清晰的关键字调用**、又不想重写函数声明，或在意与普通 `proc`
  工具链（如 VS Code 大纲识别、调试堆栈）的兼容性，`kwargs` 更贴合。
- 若需要**类型与取值范围校验、帮助文本、交互式参数表单**等“重”能力，并愿意采用整套新声明
  语法来管理参数，tepam 更合适。
- 二者是不同层面的方案：`kwargs` 强调最小侵入，tepam 强调声明式、自校验、自文档化。
  它们并非彼此替代的关系，可按“是否愿意改变函数定义方式”来选择。

## 完整使用示例

### 使用 `fake_wrap` 包装已有函数

```tcl
# 原始函数（位置传参）
proc create_user {name email age city} {
    return "用户: $name, 邮箱: $email, 年龄: $age, 城市: $city"
}

# 调用时用伪关键字标注参数含义
::kwargs::fake_wrap create_user \
    -name 张三 -email zhang@test.com -age 30 -city 上海
# -> "用户: 张三, 邮箱: zhang@test.com, 年龄: 30, 城市: 上海"
```

### 使用 `inject` 实现真正的关键字参数

```tcl
# 定义函数
proc greet_user {args} {
    ::kwargs::inject $args {-name} {-greeting "你好" -suffix "!"}
    return "${greeting}, ${name}${suffix}"
}

# 基本调用
greet_user -name 张三
# -> "你好, 张三!"

# 覆盖默认值
greet_user -name 李四 -greeting "Hello" -suffix ""
# -> "Hello, 李四"

# 关键字顺序无关
greet_user -suffix "~" -name 王五 -greeting "嗨"
# -> "嗨, 王五~"
```

### 计算器示例（全部必选参数）

```tcl
proc calculate {args} {
    ::kwargs::inject $args {-op -a -b} {}
    switch -- $op {
        add { return [expr {$a + $b}] }
        sub { return [expr {$a - $b}] }
        mul { return [expr {$a * $b}] }
        div {
            if {$b == 0} { error "除数不能为0" }
            return [expr {$a / $b}]
        }
        default { error "未知操作: $op" }
    }
}

calculate -op add -a 10 -b 20
# -> 30
```

### 配置函数示例（全部可选参数）

```tcl
proc configure {args} {
    ::kwargs::inject $args {} \
        {-host "localhost" -port 8080 -debug false -timeout 30}
    return "host=$host, port=$port, debug=$debug, timeout=${timeout}s"
}

# 全部使用默认值
configure
# -> "host=localhost, port=8080, debug=false, timeout=30s"

# 部分覆盖
configure -host "192.168.1.1" -port 3000
# -> "host=192.168.1.1, port=3000, debug=false, timeout=30s"
```

## 代码注入安全性

`kwargs` 模块在设计上考虑了代码注入安全性：

- `::kwargs::inject` 使用 `uplevel 1 [list lassign $values {*}$varnames]` 注入变量，
  值部分通过 `list` 命令安全引用，不会被当作命令执行。
- `::kwargs::fake_wrap` 在 `debug_mode` 开启时检查 `cmd` 为空的情况，防止 `args` 被意外当作命令执行。

```tcl
# inject 的值不会被当作命令执行
proc safe {args} {
    ::kwargs::inject $args {} {-cmd ""}
    return $cmd
}
safe -cmd {set malicious_code}
# -> 返回字符串 "set malicious_code"，不会执行该代码
```

## 测试

测试基于 Tcl 内置的 `tcltest` 包。

### 运行测试

```tcl
cd test
tclsh kwargs_test.tcl
```

或从任意目录：

```shell
tclsh path/to/kwargs/test/kwargs_test.tcl
```

### 测试覆盖

测试文件 [`test/kwargs_test.tcl`](test/kwargs_test.tcl) 覆盖以下内容：

| 测试组 | 覆盖范围 |
| --- | --- |
| `_has_duplicates` | 空列表、单元素、无重复、有重复、全部相同、非关键字字符串 |
| `fake_wrap` | 基本传参、关键字顺序、不以 `-` 开头的关键字、空 args、单参数、命令列表形式、错误处理、边界情况 |
| `_check_formal_parameters` | 只有必选、只有可选、混合、默认值类型、大量关键字、错误处理、边界情况 |
| `inject` | 基本注入、默认值、只有必选/可选、部分可选、值类型（字符串/数字/列表/布尔）、错误处理、边界情况、大量关键字 |
| `code_injection` | fake_wrap 空 cmd 保护、inject 值安全（命令/特殊字符/方括号） |
| `integration` | 完整场景：创建用户、问候、计算器、配置函数 |

## 性能

详见 [`benchmark/benchmark_kwargs.tcl`](benchmark/benchmark_kwargs.tcl) 的测试结果
（Tcl 8.5.9, Windows 10, 100,000 次迭代）。

### 2种关键字参数方案性能对比

| 测试项 | 每次耗时 (us/op) | 相对基准线 |
| --- | --- | --- |
| 直接位置传参（基准线） | 0.974 | 1.0x |
| `fake_wrap` (debug_mode=1, 10个参数) | 5.278 | 5.4x |
| `fake_wrap` (debug_mode=0, 10个参数) | 2.877 | 3.0x |
| `inject` (debug_mode=1, 10个必选) | 33.592 | 34.5x |
| `inject` (debug_mode=0, 10个必选) | 21.900 | 22.5x |
| `inject` (debug_mode=1, 5必选+5可选) | 38.533 | 39.6x |
| `inject` (debug_mode=0, 5必选+5可选) | 22.384 | 23.0x |
| `inject` (2个参数) | 16.453 | 16.9x |
| `inject` (5个参数) | 22.947 | 23.6x |
| `inject` (20个参数) | 54.372 | 55.8x |
| `inject` 全部可选 (提供全部) | 36.459 | 37.4x |
| `inject` 全部可选 (不提供) | 29.577 | 30.4x |
| `inject` 5必选+5可选 (提供全部) | 37.695 | 38.7x |
| `inject` 5必选+5可选 (只提供必选) | 34.421 | 35.3x |
| `_check_formal_parameters` (10个必选) | 10.846 | 11.1x |
| `_check_formal_parameters` (10个可选) | 11.029 | 11.3x |
| `_check_formal_parameters` (5必选+5可选) | 13.522 | 13.9x |
| `_has_duplicates` (10个元素, lsort -unique) | 1.353 | - |

性能影响因素

- 参数数量：参数越多，`inject` 的开销越大（近似线性增长）。2个参数约 16.9x，20个参数约 55.8x。
- 可选参数：可选参数不提供时，`inject` 性能略好（约节省 15-20% 开销）。
- 调试模式：关闭 `debug_mode` 可显著提升性能。`fake_wrap` 提升约 45%，`inject` 提升约 35-40%。
- `_check_formal_parameters` 开销：该函数本身开销约 10-14 us/op，建议只在开发阶段调用。
- `_has_duplicates` 开销：该函数开销极低（约 0.7-1.4 us/op），对整体性能影响可忽略。

### `_has_duplicates` 各实现方案性能对比

详见 [`benchmark/benchmark_has_duplicates.tcl`](benchmark/benchmark_has_duplicates.tcl) 的测试结果
（Tcl 8.6.13, Windows 10, 10,000 次迭代）。

| 方案 | 10元素 (us/op) | 100元素 (us/op) | 1000元素 (us/op) | 说明 |
| --- | --- | --- | --- | --- |
| `lsort -unique` (无重复) | 0.735 | 4.213 | 47.236 | 最快，C 实现的排序去重 |
| `lsort -unique` (有重复) | 0.644 | 2.642 | 26.691 | 有重复时更快（去重后元素少） |
| `seen+in` (无重复) | 1.438 | 41.283 | 2361.886 | 无重复时 O(n²)，极慢 |
| `seen+in` (有重复) | 0.546 | 0.527 | 0.548 | 有重复时极快（提前退出） |
| `array` (无重复) | 1.571 | 7.923 | 88.013 | 纯 Tcl array 操作 |
| `array` (有重复) | 1.125 | 6.412 | 57.337 | 有重复时略快 |
| `struct::set size` (无重复) | 1.517 | 10.242 | 106.940 | tcllib 实现 |
| `struct::set size` (有重复) | 1.334 | 9.442 | 93.539 | 有重复时略快 |
| `dict` (无重复) | 2.578 | 14.401 | 141.807 | 需 lmap 转换，最慢 |
| `dict` (有重复) | 2.358 | 14.437 | 140.098 | 有重复无优势 |

结论：当前 `::kwargs::_has_duplicates` 使用的 `lsort -unique` 方案在所有场景下都是最快的。
在`kwargs`模块中，关键字无重复情况更常见。
`seen+in` 方案在有重复时极快（可提前退出），但无重复时性能退化严重（O(n²)），不适合`kwargs`。

### 建议

关键字参数封装的开销与调用频率直接相关。
以最重的 `inject`（20个参数，debug_mode=1）为例：

| 调用频率 | 原本耗时 | 加封装后耗时 | 多出的时间 |
| --- | --- | --- | --- |
| 10 次/秒 | 1.00 秒 | 1.001 秒 | 0.001 秒 (0.1%) |
| 100 次/秒 | 1.00 秒 | 1.005 秒 | 0.005 秒 (0.5%) |
| 1,000 次/秒 | 1.00 秒 | 1.054 秒 | 0.054 秒 (5.4%) |
| 10,000 次/秒 | 1.00 秒 | 1.544 秒 | 0.544 秒 (54.4%) |

若允许额外耗时不超过 1%，各场景的安全调用频率上限为：

| 场景 | 安全频率上限 |
| --- | --- |
| `inject` (2个参数) | ≈ 600 次/秒 |
| `inject` (5个参数) | ≈ 430 次/秒 |
| `inject` (10个必选, debug_mode=0) | ≈ 450 次/秒 |
| `inject` (10个必选, debug_mode=1) | ≈ 300 次/秒 |
| `inject` (20个参数) | ≈ 180 次/秒 |

结论：
对于大多数 GUI 应用（如 Tk），事件驱动的调用频率通常在 1-100 次/秒级别，关键字参数封装的开销完全可以忽略。
仅在性能敏感的高频循环（如数值计算、批量数据处理）中才需要考虑避免使用。

## 作者

[kjasdh213](https://github.com/kjasdh213)
