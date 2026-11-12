# ============================================================================
# kwargs - 模块单元测试 (基于 tcltest)
#
# Copyright (c) 2026 kjasdh213 <https://github.com/kjasdh213>
#
# Licensed under the MIT License.
# License: https://opensource.org/licenses/MIT
# Full text: see the LICENSE file in this repository.
# ============================================================================


package require tcltest


namespace eval ::kwargs::test {
    # 注入目标变量。正常情况下应为空。
    # 如果注入成功，该变量值会被修改为 "INJECTED"。
    # 每个与注入相关的测试用例前后，必须将该变量重置为空，避免污染。
    variable _should_be_empty ""
}


proc ::kwargs::test::__________utility__________ {} {
    error "分割线，用于为 vs code 大纲提供视觉分组，请勿调用"
}


proc ::kwargs::test::_has_duplicates {} {
    ::tcltest::test _has_duplicates-1.1 {空列表无重复} \
        -body { ::kwargs::_has_duplicates {} } \
        -result 0

    ::tcltest::test _has_duplicates-1.2 {单元素列表无重复} \
        -body { ::kwargs::_has_duplicates {-a} } \
        -result 0

    ::tcltest::test _has_duplicates-1.3 {无重复列表} \
        -body { ::kwargs::_has_duplicates {-a -b -c} } \
        -result 0

    ::tcltest::test _has_duplicates-1.4 {有重复列表} \
        -body { ::kwargs::_has_duplicates {-a -b -a} } \
        -result 1

    ::tcltest::test _has_duplicates-1.5 {全部相同} \
        -body { ::kwargs::_has_duplicates {-x -x -x} } \
        -result 1

    ::tcltest::test _has_duplicates-1.6 {非关键字字符串无重复} \
        -body { ::kwargs::_has_duplicates {foo bar baz} } \
        -result 0

    ::tcltest::test _has_duplicates-1.7 {非关键字字符串有重复} \
        -body { ::kwargs::_has_duplicates {foo bar foo} } \
        -result 1
}


proc ::kwargs::test::fake_wrap {} {
    # 辅助函数
    proc ::kwargs::test::_add_7_values {a b c d e f g} {
        return [expr {$a + $b + $c + $d + $e + $f + $g}]
    }

    proc ::kwargs::test::_concat_three {x y z} {
        return "${x}${y}${z}"
    }

    proc ::kwargs::test::_return_args_count {args} {
        return [llength $args]
    }

    # ---------- 正常功能测试 ----------
    ::tcltest::test fake_wrap-1.1 {基本伪关键字传参} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_add_7_values \
                -a 1 -b 0 -c 0 -d 12 -e 45 -f 0 -g 1
        } \
        -result 59

    ::tcltest::test fake_wrap-1.2 {关键字顺序不影响结果（因为是位置传参）} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_concat_three \
                -x hello -y " " -z world
        } \
        -result "hello world"

    ::tcltest::test fake_wrap-1.3 {关键字不以-开头也可以} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_add_7_values \
                "a" 1 "b" 0 "c" 0 "d" 12 "e" 45 "f" 0 "g" 1
        } \
        -result 59

    ::tcltest::test fake_wrap-1.4 {空args时报错} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_return_args_count
        } \
        -returnCodes error -match glob -result "*args 为空*"

    ::tcltest::test fake_wrap-1.5 {单个参数} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_return_args_count -x 42
        } \
        -result 1

    ::tcltest::test fake_wrap-1.6 {命令列表形式调用} \
        -body {
            ::kwargs::fake_wrap [list ::kwargs::test::_add_7_values] \
                -a 1 -b 2 -c 3 -d 4 -e 5 -f 6 -g 7
        } \
        -result 28

    # ---------- 错误处理测试 ----------
    ::tcltest::test fake_wrap-2.1 {cmd为空时报错} \
        -body { ::kwargs::fake_wrap "" -a 1 } \
        -returnCodes error -match glob -result "*cmd 为空*"

    ::tcltest::test fake_wrap-2.2 {args元素数量为奇数时报错} \
        -body { ::kwargs::fake_wrap ::kwargs::test::_return_args_count -a 1 -b } \
        -returnCodes error -match glob -result "*元素数量必须为偶数*"

    ::tcltest::test fake_wrap-2.3 {args元素数量为奇数时报错（3个元素）} \
        -body { ::kwargs::fake_wrap ::kwargs::test::_return_args_count -a } \
        -returnCodes error -match glob -result "*元素数量必须为偶数*"

    ::tcltest::test fake_wrap-2.4 {关键字重复时报错} \
        -body { ::kwargs::fake_wrap ::kwargs::test::_return_args_count -a 1 -a 2 } \
        -returnCodes error -match glob -result "*伪关键字(字典键)禁止重复*"

    ::tcltest::test fake_wrap-2.5 {关键字重复时报错（多个重复）} \
        -body { ::kwargs::fake_wrap ::kwargs::test::_return_args_count -a 1 -b 2 -a 3 -b 4 } \
        -returnCodes error -match glob -result "*伪关键字(字典键)禁止重复*"

    ::tcltest::test fake_wrap-2.6 {cmd不存在时报错} \
        -body { ::kwargs::fake_wrap ::kwargs::test::_nonexistent_cmd -x 1 } \
        -returnCodes error -match glob -result "*nonexistent*"

    # ---------- 边界情况测试 ----------
    ::tcltest::test fake_wrap-3.1 {空字符串作为值} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_concat_three -x "" -y "" -z ""
        } \
        -result ""

    ::tcltest::test fake_wrap-3.2 {数字作为值} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_add_7_values \
                -a 0 -b 0 -c 0 -d 0 -e 0 -f 0 -g 0
        } \
        -result 0

    ::tcltest::test fake_wrap-3.3 {负数作为值} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_add_7_values \
                -a -1 -b -2 -c -3 -d -4 -e -5 -f -6 -g -7
        } \
        -result -28

    ::tcltest::test fake_wrap-3.4 {列表作为值} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_return_args_count \
                -x {a b c} -y {d e f}
        } \
        -result 2

    ::tcltest::test fake_wrap-3.5 {特殊字符作为关键字} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_return_args_count \
                "-特殊键" 1 "-another-key" 2
        } \
        -result 2
}


proc ::kwargs::test::_check_formal_parameters {} {
    # ---------- 正常情况测试 ----------
    ::tcltest::test _check_formal_parameters-1.1 {只有必选关键字} \
        -body { ::kwargs::_check_formal_parameters {-name -email} {} } \
        -result ""

    ::tcltest::test _check_formal_parameters-1.2 {只有可选关键字} \
        -body { ::kwargs::_check_formal_parameters {} {-age "未知" -city "未知"} } \
        -result ""

    ::tcltest::test _check_formal_parameters-1.3 {必选和可选关键字都有} \
        -body { ::kwargs::_check_formal_parameters {-name -email} {-age "未知" -city "未知"} } \
        -result ""

    ::tcltest::test _check_formal_parameters-1.4 {可选关键字默认值为空字符串} \
        -body { ::kwargs::_check_formal_parameters {} {-name "" -email ""} } \
        -result ""

    ::tcltest::test _check_formal_parameters-1.5 {可选关键字默认值为数字} \
        -body { ::kwargs::_check_formal_parameters {} {-count 0 -limit 100} } \
        -result ""

    ::tcltest::test _check_formal_parameters-1.6 {可选关键字默认值为列表} \
        -body { ::kwargs::_check_formal_parameters {} {-items {a b c}} } \
        -result ""

    ::tcltest::test _check_formal_parameters-1.7 {单字符关键字} \
        -body { ::kwargs::_check_formal_parameters {-a -b} {} } \
        -result ""

    ::tcltest::test _check_formal_parameters-1.8 {长关键字名} \
        -body { ::kwargs::_check_formal_parameters {-very_long_keyword_name} {} } \
        -result ""

    # ---------- 错误处理测试 ----------
    ::tcltest::test _check_formal_parameters-2.1 {必选和可选都为空时报错} \
        -body { ::kwargs::_check_formal_parameters {} {} } \
        -returnCodes error -match glob -result "*必选和可选关键字都为空*"

    ::tcltest::test _check_formal_parameters-2.2 {可选关键字不是字典（奇数元素）时报错} \
        -body { ::kwargs::_check_formal_parameters {} {-a 1 -b} } \
        -returnCodes error -match glob -result "*元素数量必须为偶数*"

    ::tcltest::test _check_formal_parameters-2.3 {必选关键字格式错误（不以-开头）} \
        -body { ::kwargs::_check_formal_parameters {name} {} } \
        -returnCodes error -match glob -result "*格式错误*"

    ::tcltest::test _check_formal_parameters-2.4 {必选关键字格式错误（包含特殊字符）} \
        -body { ::kwargs::_check_formal_parameters {-na me} {} } \
        -returnCodes error -match glob -result "*格式错误*"

    ::tcltest::test _check_formal_parameters-2.5 {可选关键字格式错误（不以-开头）} \
        -body { ::kwargs::_check_formal_parameters {} {name "张三"} } \
        -returnCodes error -match glob -result "*格式错误*"

    ::tcltest::test _check_formal_parameters-2.6 {必选关键字重复} \
        -body { ::kwargs::_check_formal_parameters {-name -name} {} } \
        -returnCodes error -match glob -result "*关键字不能重复*"

    ::tcltest::test _check_formal_parameters-2.7 {可选关键字重复} \
        -body { ::kwargs::_check_formal_parameters {} {-age 25 -age 30} } \
        -returnCodes error -match glob -result "*关键字不能重复*"

    ::tcltest::test _check_formal_parameters-2.8 {必选和可选关键字有交集} \
        -body { ::kwargs::_check_formal_parameters {-name} {-name "张三"} } \
        -returnCodes error -match glob -result "*交集*"

    ::tcltest::test _check_formal_parameters-2.9 {必选和可选关键字部分交集} \
        -body { ::kwargs::_check_formal_parameters {-name -email} {-email "test@test.com" -age 25} } \
        -returnCodes error -match glob -result "*交集*"

    ::tcltest::test _check_formal_parameters-2.10 {可选关键字格式错误（空字符串作为关键字）} \
        -body { ::kwargs::_check_formal_parameters {} {"" "value"} } \
        -returnCodes error -match glob -result "*格式错误*"

    # ---------- 边界情况测试 ----------
    ::tcltest::test _check_formal_parameters-3.1 {大量必选关键字} \
        -body {
            set keywords {}
            for {set i 0} {$i < 50} {incr i} {
                lappend keywords "-kw${i}"
            }
            ::kwargs::_check_formal_parameters $keywords {}
        } \
        -result ""

    ::tcltest::test _check_formal_parameters-3.2 {大量可选关键字} \
        -body {
            set opt_kw {}
            for {set i 0} {$i < 50} {incr i} {
                lappend opt_kw "-kw${i}" $i
            }
            ::kwargs::_check_formal_parameters {} $opt_kw
        } \
        -result ""

    ::tcltest::test _check_formal_parameters-3.3 {关键字包含数字} \
        -body { ::kwargs::_check_formal_parameters {-a1 -b2 -c3} {} } \
        -result ""

    ::tcltest::test _check_formal_parameters-3.4 {关键字包含下划线} \
        -body { ::kwargs::_check_formal_parameters {-my_var -my_other_var} {} } \
        -result ""
}


proc ::kwargs::test::inject {} {
    # ---------- 正常功能测试 ----------
    ::tcltest::test inject-1.1 {基本注入 - 所有参数都提供} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {-name 张三 -email test@test.com -age 25 -city 北京}
            ::kwargs::inject $caller_args {-name -email} {-age "未知" -city "未知"}
            return "姓名: $name, 邮箱: $email, 年龄: $age, 城市: $city"
        } \
        -result "姓名: 张三, 邮箱: test@test.com, 年龄: 25, 城市: 北京" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-1.2 {可选参数使用默认值} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {-name 李四 -email li@test.com}
            ::kwargs::inject $caller_args {-name -email} {-age "未知" -city "未知"}
            return "姓名: $name, 邮箱: $email, 年龄: $age, 城市: $city"
        } \
        -result "姓名: 李四, 邮箱: li@test.com, 年龄: 未知, 城市: 未知" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-1.3 {只有必选关键字} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {-x 10 -y 20}
            ::kwargs::inject $caller_args {-x -y} {}
            return [expr {$x + $y}]
        } \
        -result 30 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-1.4 {只有可选关键字} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {-a 100}
            ::kwargs::inject $caller_args {} {-a 0 -b 0}
            return [expr {$a + $b}]
        } \
        -result 100 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-1.5 {可选关键字全部不提供} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {}
            ::kwargs::inject $caller_args {} {-a 0 -b 0 -c 0}
            return [expr {$a + $b + $c}]
        } \
        -result 0 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-1.6 {部分可选关键字提供} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {-b 5}
            ::kwargs::inject $caller_args {} {-a 1 -b 2 -c 3}
            return [expr {$a + $b + $c}]
        } \
        -result 9 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-1.7 {字符串值包含空格} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {-name "张 三" -desc "hello world"}
            ::kwargs::inject $caller_args {-name} {-desc ""}
            return "${name}:${desc}"
        } \
        -result "张 三:hello world" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-1.8 {数字值} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {-count 42 -ratio 3.14}
            ::kwargs::inject $caller_args {} {-count 0 -ratio 0.0}
            return [expr {$count + $ratio}]
        } \
        -result 45.14 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-1.9 {列表值} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {-items {a b c}}
            ::kwargs::inject $caller_args {} {-items {}}
            return [llength $items]
        } \
        -result 3 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-1.10 {布尔值} \
        -setup {set _should_be_empty ""} \
        -body {
            set caller_args {-flag true -enabled false}
            ::kwargs::inject $caller_args {} {-flag false -enabled true}
            return "${flag}:${enabled}"
        } \
        -result "true:false" \
        -cleanup {set _should_be_empty ""}

    # ---------- 错误处理测试 ----------
    ::tcltest::test inject-2.1 {caller_args元素数量为奇数时报错} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-a 1 -b} {-a -b} {}
        } \
        -returnCodes error -match glob -result "*元素数量必须为偶数*" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-2.2 {caller_args关键字格式错误} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {"bad key" 1} {-a} {}
        } \
        -returnCodes error -match glob -result "*格式错误*" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-2.3 {caller_args关键字重复} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-a 1 -a 2} {-a} {}
        } \
        -returnCodes error -match glob -result "*关键字不能重复*" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-2.4 {缺少必选关键字} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-a 1} {-a -b} {}
        } \
        -returnCodes error -match glob -result "*缺少必选关键字*" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-2.5 {缺少多个必选关键字} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {} {-a -b -c} {}
        } \
        -returnCodes error -match glob -result "*缺少必选关键字*" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-2.6 {提供了未知关键字} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-a 1 -x 100} {-a} {}
        } \
        -returnCodes error -match glob -result "*提供了未知关键字*" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-2.7 {提供了多个未知关键字} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-a 1 -x 100 -y 200} {-a} {}
        } \
        -returnCodes error -match glob -result "*提供了未知关键字*" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-2.8 {caller_args为空但缺少必选关键字} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {} {-required_key} {}
        } \
        -returnCodes error -match glob -result "*缺少必选关键字*" \
        -cleanup {set _should_be_empty ""}

    # ---------- 边界情况测试 ----------
    ::tcltest::test inject-3.1 {大量关键字} \
        -setup {set _should_be_empty ""} \
        -body {
            set required_kw {}
            set optional_kw {}
            set caller_args {}
            for {set i 0} {$i < 20} {incr i} {
                lappend required_kw "-req${i}"
                lappend caller_args "-req${i}" $i
            }
            for {set i 0} {$i < 20} {incr i} {
                lappend optional_kw "-opt${i}" [expr {$i * 10}]
            }
            ::kwargs::inject $caller_args $required_kw $optional_kw
            set sum 0
            for {set i 0} {$i < 20} {incr i} {
                set sum [expr {$sum + [set req${i}] + [set opt${i}]}]
            }
            return $sum
        } \
        -result 2090 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-3.2 {关键字顺序不影响结果} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-b 2 -a 1} {-a -b} {}
            return [expr {$a + $b}]
        } \
        -result 3 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-3.3 {空字符串作为值} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-name ""} {-name} {}
            return [string length $name]
        } \
        -result 0 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-3.4 {零作为值} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-count 0} {-count} {}
            return $count
        } \
        -result 0 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-3.5 {负数作为值} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-value -42} {-value} {}
            return $value
        } \
        -result -42 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-3.6 {嵌套列表作为值} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-data {{a b} {c d}}} {-data} {}
            return [llength $data]
        } \
        -result 2 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-3.7 {变量名包含数字} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-var1 hello -var2 world} {-var1 -var2} {}
            return "${var1} ${var2}"
        } \
        -result "hello world" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test inject-3.8 {变量名包含下划线} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject {-my_var hello -my_other_var world} {-my_var -my_other_var} {}
            return "${my_var} ${my_other_var}"
        } \
        -result "hello world" \
        -cleanup {set _should_be_empty ""}
}


proc ::kwargs::test::code_injection {} {
    # 注入测试命令：如果被当作命令执行，会修改 _should_be_empty 变量
    set injection_cmd {set ::kwargs::test::_should_be_empty "INJECTED"}

    # ============================================================
    # ::kwargs::fake_wrap - cmd 为空时，args 可能被当作命令执行
    # ============================================================
    ::tcltest::test code_injection-fake_wrap-1.1 {fake_wrap 空 cmd 报错} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::fake_wrap "" $injection_cmd
        } \
        -returnCodes error -match glob -result "*cmd 为空*" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test code_injection-fake_wrap-1.2 {fake_wrap 空 cmd 且 args 为空时也报错} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::fake_wrap ""
        } \
        -returnCodes error -match glob -result "*cmd 为空*" \
        -cleanup {set _should_be_empty ""}

    # ============================================================
    # ::kwargs::inject - caller_args 中的值不会被当作命令执行
    # ============================================================
    ::tcltest::test code_injection-inject-1.1 {inject 值不会被当作命令执行} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject [list -cmd $injection_cmd] {} {-cmd ""}
            set _should_be_empty
        } \
        -result "" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test code_injection-inject-1.2 {inject 值包含特殊字符安全} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject [list -x ";[set ::kwargs::test::_should_be_empty INJECTED]"] {} {-x ""}
            set _should_be_empty
        } \
        -result "" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test code_injection-inject-1.3 {inject 值包含方括号安全} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::inject [list -x "\[set ::kwargs::test::_should_be_empty INJECTED\]"] {} {-x ""}
            set _should_be_empty
        } \
        -result "" \
        -cleanup {set _should_be_empty ""}
}


# 场景1：使用 fake_wrap 包装已有函数
proc ::kwargs::test::_create_user {name email age city} {
    return "用户: $name, 邮箱: $email, 年龄: $age, 城市: $city"
}

# 场景2：使用 inject 实现真正的关键字参数
proc ::kwargs::test::_greet_user {caller_args} {
    ::kwargs::inject $caller_args {-name} {-greeting "你好" -suffix "!"}
    return "${greeting}, ${name}${suffix}"
}

# 场景3：计算器函数
proc ::kwargs::test::_calculate {caller_args} {
    ::kwargs::inject $caller_args {-op -a -b} {}
    switch -- $op {
        add    { return [expr {$a + $b}] }
        sub    { return [expr {$a - $b}] }
        mul    { return [expr {$a * $b}] }
        div    {
            if {$b == 0} { error "除数不能为0" }
            return [expr {$a / $b}]
        }
        default { error "未知操作: $op" }
    }
}

# 场景4：配置函数
proc ::kwargs::test::_configure {caller_args} {
    ::kwargs::inject $caller_args {} \
        {-host "localhost" -port 8080 -debug false -timeout 30}
    return "host=$host, port=$port, debug=$debug, timeout=${timeout}s"
}


proc ::kwargs::test::integration {} {
    ::tcltest::test integration-1.1 {fake_wrap 包装创建用户函数} \
        -body {
            ::kwargs::fake_wrap ::kwargs::test::_create_user \
                -name 张三 -email zhang@test.com -age 30 -city 上海
        } \
        -result "用户: 张三, 邮箱: zhang@test.com, 年龄: 30, 城市: 上海"

    ::tcltest::test integration-1.2 {fake_wrap 包装创建用户函数（不同顺序）} \
        -body {
            # fake_wrap 本质是位置传参，顺序不能变
            ::kwargs::fake_wrap ::kwargs::test::_create_user \
                -name 李四 -email li@test.com -age 25 -city 北京
        } \
        -result "用户: 李四, 邮箱: li@test.com, 年龄: 25, 城市: 北京"

    ::tcltest::test integration-2.1 {inject 实现关键字参数函数} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::test::_greet_user {-name 张三}
        } \
        -result "你好, 张三!" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test integration-2.2 {inject 覆盖默认值} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::test::_greet_user [list -name 李四 -greeting "Hello" -suffix ""]
        } \
        -result "Hello, 李四" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test integration-2.3 {inject 关键字顺序无关} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::test::_greet_user [list -suffix "~" -name 王五 -greeting "嗨"]
        } \
        -result "嗨, 王五~" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test integration-3.1 {计算器 - 加法} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::test::_calculate [list -op add -a 10 -b 20]
        } \
        -result 30 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test integration-3.2 {计算器 - 除法} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::test::_calculate [list -op div -a 100 -b 3]
        } \
        -result 33 \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test integration-3.3 {计算器 - 除数为0报错} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::test::_calculate [list -op div -a 10 -b 0]
        } \
        -returnCodes error -match glob -result "*除数不能为0*" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test integration-4.1 {配置函数 - 全部默认值} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::test::_configure {}
        } \
        -result "host=localhost, port=8080, debug=false, timeout=30s" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test integration-4.2 {配置函数 - 部分覆盖} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::test::_configure [list -host "192.168.1.1" -port 3000]
        } \
        -result "host=192.168.1.1, port=3000, debug=false, timeout=30s" \
        -cleanup {set _should_be_empty ""}

    ::tcltest::test integration-4.3 {配置函数 - 全部覆盖} \
        -setup {set _should_be_empty ""} \
        -body {
            ::kwargs::test::_configure [list \
                -host "example.com" -port 443 -debug true -timeout 60]
        } \
        -result "host=example.com, port=443, debug=true, timeout=60s" \
        -cleanup {set _should_be_empty ""}
}


proc ::kwargs::test::__________run_tests__________ {} {
    error "分割线，用于为 vs code 大纲提供视觉分组，请勿调用"
}


proc ::kwargs::test::run_tests {} {
    # """
    # 收集全部非私有的测试函数名，执行测试，最后执行`::tcltest::cleanupTests`
    # """

    set all_procs_in_current_ns [info commands [namespace current]::*]

    set this_proc_name [dict get [info frame -1] "cmd"]
    set this_proc_short_name [namespace tail $this_proc_name]

    foreach proc_to_run [concat $all_procs_in_current_ns ::tcltest::cleanupTests] {
        set proc_short_name [namespace tail $proc_to_run]
        # 跳过自己
        if {$proc_short_name eq $this_proc_short_name} {
            continue
        }
        # 跳过私有
        if {[string match "_*" $proc_short_name]} {
            continue
        }
        if {[catch {{*}$proc_to_run} catch_result]} {
            puts "$proc_to_run 报错: $catch_result"
        }
    }
}


set script_dir [file dirname [info script]]
set parent_dir [file dirname $script_dir]
if {$parent_dir ni $::auto_path} {
    lappend ::auto_path $parent_dir
}
package require kwargs
::kwargs::test::run_tests
