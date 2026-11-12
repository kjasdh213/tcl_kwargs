# ============================================================================
# kwargs - 在 Tcl 8.5+ 中模拟关键字参数 (keyword arguments) 传参
#
# Copyright (c) 2026 kjasdh213 <https://github.com/kjasdh213>
#
# Licensed under the MIT License.
# License: https://opensource.org/licenses/MIT
# Full text: see the LICENSE file in this repository.
# ============================================================================

# 提供包版本信息，支持 `package require kwargs` 语法
package provide kwargs 1.0.0

package require struct::set ; # 来自 tcllib


namespace eval ::kwargs {
    # 控制是否执行形参检查（默认开启）。
    # - 形参通常不可变，只需检查一次就能保证运行时形参永远正确。
    # - 形参检查应在测试阶段完成。测试用例应覆盖所有使用了`kwargs`包的函数。
    # - 正式上线阶段应假设形参正确（因为已通过测试），不再检查，避免重复开销。
    # - 实参是不可靠的，所以总是检查实参。实参检查不受该变量控制。
    variable debug_mode 1

    # 关键字格式的正则表达式。
    # 关键字去除`-`之后用作变量名。
    # 按照最佳实践，变量名应该匹配 {^\w+$} ，不应支持奇形怪状的变量名。
    # 所有关键字都必须匹配此正则表达式，但 `::kwargs::fake_wrap` 中的伪关键字不受此约束。
    variable _keyword_regexp {^-\w+$}
}


proc ::kwargs::fake_wrap {cmd args} {
    # """伪关键字参数包装器。
    #
    # 将“按位置传参的函数调用”包装成伪关键字传参的样式：
    # - 接收一个命令 cmd 和一个字典格式的参数列表 args
    # - 使用 `dict values $args` 提取字典的所有值（忽略键）
    # - 将这些值按位置传递给 $cmd
    #
    # 在调用时使用，不需要修改被调用函数的定义。
    # 用于文档化代码，提供参数含义，但牺牲性能。
    # Tcl 原生不支持关键字传参，所以才需要这种奇技淫巧。
    # 该函数提供了不够好用但轻量的解决方案。
    #
    # 函数名已极其明确地表示这是假的！本质上仍是位置传参，不是真的关键字参数！
    # - 参数顺序仍然重要，不能交换
    # - 不能省略必选参数
    # - 伪关键字只是注释，没有其他用途
    #
    # 伪关键字可以是任意字符串，但建议(非强制)以单个`-`开头，模仿tk的关键字传参风格。
    #
    # 如果要实现真正的关键字传参，请使用`::kwargs::inject`。
    #
    # Args:
    #     cmd: 要调用的命令（proc 名称或命令列表）
    #     args: 字典，伪关键字-值，格式为 { -key1 val1 -key2 val2 ... }
    #
    # Returns:
    #     透传 cmd 的返回值
    #
    # Errors:
    #     仅当`debug_mode`为真时，检查:
    #     - `cmd`为空时报错。
    #     - `args`为空时报错。
    #     - `args`的元素数量不是偶数(不是字典)时报错。
    #     - `args`键重复时报错。
    #
    # Examples:
    #     ```tcl
    #     # 参数繁多的文件导出函数
    #     proc ::export_report {file_path format encoding header_footer
    #         include_metadata page_size orientation margin_dpi
    #         compression_level watermark password
    #     } {
    #         puts "导出到: $file_path"
    #         puts "格式: $format, 编码: $encoding"
    #         puts "页边距: $margin_dpi, 方向: $orientation"
    #     }
    #
    #     # 调用时，伪关键字让参数清晰可读
    #     ::kwargs::fake_wrap ::export_report \
    #         -file_path "/var/reports/Q3_2026.pdf" \
    #         -format "pdf" \
    #         -encoding "utf-8" \
    #         -header_footer "true" \
    #         -include_metadata "true" \
    #         -page_size "A4" \
    #         -orientation "landscape" \
    #         -margin_dpi 72 \
    #         -compression_level 9 \
    #         -watermark "CONFIDENTIAL" \
    #         -password "secure123"
    #     ```
    # """

    variable debug_mode

    if {$debug_mode} {
        if {$cmd eq ""} {
            error "cmd 为空"
        }

        if {$args eq ""} {
            error "args 为空。这不是逻辑错误，\
                但如果没有参数要传递，使用伪关键字包装就毫无意义。请直接调用 cmd\
            "
        }

        if {[llength $args] % 2 != 0} {
            error "args 的元素数量必须为偶数，否则无法视为字典。实际有 [llength $args] 个元素"
        }

        set fake_keywords {}
        # 经测试发现，用 for + lindex 取偶数索引遍历键，比 `dict for` 和 `foreach` 方案更快。
        # `dict for`方案不能用在这里，因为它会自动去除重复键，掩盖键重复问题。
        for {set i 0} {$i < [llength $args]} {incr i 2} {
            lappend fake_keywords [lindex $args $i]
        }
        if {[::kwargs::_has_duplicates $fake_keywords]} {
            error "args 参数的伪关键字(字典键)禁止重复. args = {$args}"
        }
    }

    {*}$cmd {*}[dict values $args]
}


proc ::kwargs::inject {caller_args required_keywords optional_kw_default_dict {strict 0}} {
    # """真正的关键字传参。
    #
    # 以"关键字-值"对的形式解析`caller_args`实参，并注入为调用者上下文的局部变量。
    # 请在调用者的开头执行该函数，否则会覆盖已有变量。
    #
    # Args:
    #     caller_args: 实际传入的关键字-值对字典（实参），
    #         格式为 {-key1 val1 -key2 val2}，
    #         当只有可选关键字且都用默认值时可以为空
    #
    #     required_keywords: 必选关键字列表（形参），
    #         如 {-name -email}，当只有可选关键字时可以为空
    #
    #     optional_kw_default_dict: 可选关键字-默认值字典（形参），
    #         如 {-age "未知" -city "未知"}，当只有必选关键字时可以为空
    #
    #     strict: 可选，布尔值，默认为假。
    #         如果为真，则总是执行形参检查，不受`debug_mode`影响。
    #         适用场景: 如果函数的形参是运行时决定的（变参函数、高阶函数），就需要总是检查形参。
    #
    # Returns:
    #     {}
    #
    # Errors:
    #     总是检查`caller_args`:
    #     - `caller_args`不是字典时报错(当元素数量为偶数时才能视为字典)。
    #     - `caller_args`的关键字不匹配正则表达式`_keyword_regexp`时报错。
    #     - `caller_args`有重复关键字时报错。
    #     - `caller_args`未提供所有必选关键字时报错。
    #     - `caller_args`提供了未知关键字时报错。
    #
    #     仅当`strict`或`debug_mode`为真时，
    #     检查`required_keywords`和`optional_kw_default_dict`:
    #     - `required_keywords`的关键字不匹配正则表达式`_keyword_regexp`时报错。
    #     - `required_keywords`有重复关键字时报错。
    #     - `optional_kw_default_dict`不是字典时报错(当元素数量为偶数时才能视为字典)。
    #     - `optional_kw_default_dict`的关键字不匹配正则表达式`_keyword_regexp`时报错。
    #     - `optional_kw_default_dict`有重复关键字时报错。
    #     - `required_keywords`与`optional_kw_default_dict`的关键字有交集时报错。
    #     - `required_keywords`与`optional_kw_default_dict`都为空时报错。
    #
    # Note:
    #     在调用上下文中创建变量 (变量名 = 关键字去除`-`)
    #
    # Examples:
    #     ```tcl
    #     proc ::greet {args} {
    #         ::kwargs::inject $args {-name -email} {-age "未知" -city "未知"}
    #         return "姓名: $name, 邮箱: $email, 年龄: $age, 城市: $city"
    #     }
    #
    #     ::greet -city 北京 -name 张三 -email test@test.com
    #     -> "姓名: 张三, 邮箱: test@test.com, 年龄: 未知, 城市: 北京"
    #     ```
    # """

    variable debug_mode
    variable _keyword_regexp

    if {$strict || $debug_mode} {
        ::kwargs::_check_formal_parameters $required_keywords $optional_kw_default_dict
    }

    if {[llength $caller_args] % 2 != 0} {
        error "caller_args 的元素数量必须为偶数，否则无法视为字典。\
            但实际有 [llength $caller_args] 个元素\
        "
    }

    set args_keywords {}
    for {set i 0} {$i < [llength $caller_args]} {incr i 2} {
        set keyword [lindex $caller_args $i]
        if { ! [regexp $_keyword_regexp $keyword]} {
            error "caller_args 参数中的关键字 {$keyword} 格式错误，\
                必须匹配正则表达式 {$_keyword_regexp}\
            "
        }
        lappend args_keywords $keyword
    }

    if {[::kwargs::_has_duplicates $args_keywords]} {
        error "关键字不能重复. caller_args = {$caller_args}"
    }

    # 经测试发现，字符串拼接方案比列表拼接方案更快。
    # 如果两者其一为空，则空值在双引号中会直接消失，
    # 结果列表中不会多出一个错误的“空元素”，所以这么写没有问题。
    # 比如：
    # ```tcl
    # set a {}
    # set b {1 2 3}
    # set a_and_b "$a $b"
    # llength $a_and_b
    # => 3
    # puts $a_and_b
    # =>  1 2 3
    # ```
    set valid_keywords "$required_keywords [dict keys $optional_kw_default_dict]"

    foreach keyword $args_keywords {
        if {$keyword ni $valid_keywords} {
            error "caller_args 提供了未知关键字: {$keyword} ，\
                合法关键字为: [join $valid_keywords {, }]\
            "
        }
    }

    # 经测试发现，采用数组方案来保存最终键值对，速度比字典更快
    array set kv $optional_kw_default_dict
    array set kv $caller_args

    foreach keyword $required_keywords {
        if { ! [info exists kv($keyword)]} {
            error "caller_args 缺少必选关键字: $keyword"
        }
    }

    set values {}
    set varnames {}
    foreach keyword $valid_keywords {
        lappend values $kv($keyword)
        lappend varnames [string trimleft $keyword {-}]
    }

    uplevel 1 [list lassign $values {*}$varnames]
}


proc ::kwargs::_check_formal_parameters {required_keywords optional_kw_default_dict} {
    # """检查`::kwargs::inject`的形参，如果不通过就报错。
    #
    # 这是开发期的工具，上线后应通过命名空间变量`debug_mode`关闭形参检查，加快执行速度。
    #
    # Args:
    #     required_keywords: 必选关键字列表（形参），
    #         如 {-name -email}，当全是可选关键字时可以为空
    #
    #     optional_kw_default_dict: 可选关键字-默认值字典（形参），
    #         如 {-age "未知" -city "未知"}，当全是必选关键字时可以为空
    #
    # Returns:
    #     {}
    #
    # Errors:
    #     - `required_keywords`的关键字不匹配正则表达式`_keyword_regexp`时报错。
    #     - `required_keywords`有重复关键字时报错。
    #
    #     - `optional_kw_default_dict`不是字典时报错(当元素数量为偶数时才能视为字典)。
    #     - `optional_kw_default_dict`的关键字不匹配正则表达式`_keyword_regexp`时报错。
    #     - `optional_kw_default_dict`有重复关键字时报错。
    #
    #     - `required_keywords`与`optional_kw_default_dict`的关键字有交集时报错。
    #     - `required_keywords`与`optional_kw_default_dict`都为空时报错。
    # """

    variable _keyword_regexp

    if {$required_keywords eq "" && $optional_kw_default_dict eq ""} {
        error "必选和可选关键字都为空，如果没有形参可供 ::kwargs::inject 解析，请勿使用该函数！"
    }

    # 字典的元素数量应该为偶数
    if {[llength $optional_kw_default_dict] % 2 != 0} {
        error "optional_kw_default_dict 的元素数量必须为偶数，否则无法视为字典。\
            但实际有 [llength $optional_kw_default_dict] 个元素\
        "
    }

    # 检查 optional_kw_default_dict 关键字格式
    set optional_keywords {}
    for {set i 0} {$i < [llength $optional_kw_default_dict]} {incr i 2} {
        set keyword [lindex $optional_kw_default_dict $i]
        if { ! [regexp $_keyword_regexp $keyword]} {
            error "optional_kw_default_dict 参数的关键字 {$keyword} 格式错误，\
                必须匹配正则表达式 {$_keyword_regexp}\
            "
        }
        lappend optional_keywords $keyword
    }

    # 检查 required_keywords 关键字格式
    foreach keyword $required_keywords {
        if { ! [regexp $_keyword_regexp $keyword]} {
            error "required_keywords 参数的关键字 {$keyword} 格式错误，\
                必须匹配正则表达式 {$_keyword_regexp}\
            "
        }
    }

    # 检查关键字重复
    if {[::kwargs::_has_duplicates $required_keywords]} {
        error "关键字不能重复. required_keywords = {$required_keywords}"
    }
    if {[::kwargs::_has_duplicates $optional_keywords]} {
        error "关键字不能重复. optional_kw_default_dict = {$optional_kw_default_dict}"
    }

    # 检查必选、可选的交集
    set intersection [::struct::set intersect $required_keywords $optional_keywords]
    if {$intersection ne ""} {
        error "必须关键字和可选关键字的交集: {$intersection}. \
            关键字不能既是必选又是可选. \
            required_keywords = {$required_keywords}, \
            optional_kw_default_dict = {$optional_kw_default_dict}\
        "
    }
}


proc ::kwargs::_has_duplicates {input_list} {
    # """检查给定列表中是否有重复项。
    #
    # 该函数的效率比较高，适合高频使用。
    # 缺点是，无法找出重复项，只能返回布尔值。
    # """
    return [expr {[llength $input_list] != [llength [lsort -unique $input_list]]}]
}


namespace eval ::kwargs {
    # 批量导出所有公开函数（不以 _ 开头），隐藏私有函数
    # 导出逻辑应该写在最后，此时所有函数都已定义
    foreach proc_name [info procs [namespace current]::*] {
        # 提取函数名的最后一部分（去掉命名空间前缀）
        set proc_short_name [namespace tail $proc_name]
        if {[string index $proc_short_name 0] ne "_"} {
            namespace export $proc_short_name
        }
    }
}
