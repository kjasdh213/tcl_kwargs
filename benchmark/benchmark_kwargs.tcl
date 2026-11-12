# ============================================================================
# kwargs - 模块性能基准测试
#
# Copyright (c) 2026 kjasdh213 <https://github.com/kjasdh213>
#
# Licensed under the MIT License.
# License: https://opensource.org/licenses/MIT
# Full text: see the LICENSE file in this repository.
# ============================================================================

# kwargs 模块性能基准测试
#
# 从多个维度对比各方案性能：
# 1. 直接位置传参（基准线）
# 2. fake_wrap 伪关键字传参（debug_mode=1）
# 3. inject 真正关键字传参（debug_mode=1）
# 4. _check_formal_parameters 单独测试（debug_mode=1）
# 5. _has_duplicates 单独测试（debug_mode=1）
# 6. 调试模式开启/关闭对比（fake_wrap + inject）
#
# 测试结果:
#
#     ============================================================
#     kwargs 模块性能基准测试
#     ============================================================
#     迭代次数: 100000
#     Tcl 版本: 8.5.9
#     测试时间: 2026-05-13 12:03:36
#     ============================================================
#     
#     --- 维度1: 直接位置传参（基准线） ---
#       直接位置传参                                                97403 us total     0.974 us/op
#     
#     --- 维度2: fake_wrap 伪关键字传参（debug_mode=1） ---
#       fake_wrap (debug_mode=1, 10个参数)                      527848 us total     5.278 us/op
#     
#     --- 维度3: inject 真正关键字传参（debug_mode=1） ---
#       inject (debug_mode=1, 10个必选参数)                      3359227 us total    33.592 us/op
#     
#     --- 维度4: 参数数量对性能的影响（debug_mode=1） ---
#       直接传参 (debug_mode=1, 2个参数)                             73684 us total     0.737 us/op
#       inject (debug_mode=1, 2个参数)                         1645289 us total    16.453 us/op
#       直接传参 (debug_mode=1, 5个参数)                            101489 us total     1.015 us/op
#       inject (debug_mode=1, 5个参数)                         2294732 us total    22.947 us/op
#       直接传参 (debug_mode=1, 20个参数)                           125069 us total     1.251 us/op
#       inject (debug_mode=1, 20个参数)                        5437219 us total    54.372 us/op
#     
#     --- 维度5: 可选参数对性能的影响（debug_mode=1） ---
#       inject 全部可选 (debug_mode=1, 提供全部)                    3645902 us total    36.459 us/op
#       inject 全部可选 (debug_mode=1, 不提供)                     2957690 us total    29.577 us/op
#       inject 5必选+5可选 (debug_mode=1, 提供全部)                 3769515 us total    37.695 us/op
#       inject 5必选+5可选 (debug_mode=1, 只提供必选)                3442123 us total    34.421 us/op
#     
#     --- 维度6: _check_formal_parameters 开销（debug_mode=1） ---
#       _check_formal_parameters (debug_mode=1, 10个必选)      1084613 us total    10.846 us/op
#       _check_formal_parameters (debug_mode=1, 10个可选)      1102879 us total    11.029 us/op
#       _check_formal_parameters (debug_mode=1, 5必选+5可选)    1352173 us total    13.522 us/op
#     
#     --- 维度7: _has_duplicates 开销（debug_mode=1） ---
#       _has_duplicates (debug_mode=1, 10个元素, 无重复)           135209 us total     1.352 us/op
#       _has_duplicates (debug_mode=1, 10个元素, 有重复)           135448 us total     1.354 us/op
#     
#     --- 维度8: 调试模式开启/关闭对比 ---
#       fake_wrap (debug_mode=1, 10个参数)                      531570 us total     5.316 us/op
#       fake_wrap (debug_mode=0, 10个参数)                      287709 us total     2.877 us/op
#       inject (debug_mode=1, 10个必选)                        3281841 us total    32.818 us/op
#       inject (debug_mode=0, 10个必选)                        2189996 us total    21.900 us/op
#       inject (debug_mode=1, 5必选+5可选)                      3853272 us total    38.533 us/op
#       inject (debug_mode=0, 5必选+5可选)                      2238406 us total    22.384 us/op
#     
#     ============================================================
#     基准测试完成
#     ============================================================


encoding system utf-8


namespace eval ::benchmark {
    # 测试数据（命名空间变量，确保在 uplevel 中可访问）
    variable pos_args {1 2 3 4 5 6 7 8 9 10}
    variable kw_args {-a 1 -b 2 -c 3 -d 4 -e 5 -f 6 -g 7 -h 8 -i 9 -j 10}
    variable pos_args_20 {1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20}
    variable kw_args_20 {-a 1 -b 2 -c 3 -d 4 -e 5 -f 6 -g 7 -h 8 -i 9 -j 10 -k 11 -l 12 -m 13 -n 14 -o 15 -p 16 -q 17 -r 18 -s 19 -t 20}
}


proc ::benchmark::_direct_pos {a b c d e f g h i j} {
    # """
    # 基准线：直接位置传参
    # """
    return [expr {$a + $b + $c + $d + $e + $f + $g + $h + $i + $j}]
}

proc ::benchmark::_fake_wrapped {args} {
    # """
    # fake_wrap 包装
    # """
    return [::kwargs::fake_wrap ::benchmark::_direct_pos {*}$args]
}

proc ::benchmark::_kw_inject {caller_args} {
    # """
    # inject 实现的关键字参数函数
    # """
    ::kwargs::inject $caller_args \
        {-a -b -c -d -e -f -g -h -i -j} {}
    return [expr {$a + $b + $c + $d + $e + $f + $g + $h + $i + $j}]
}


proc ::benchmark::run_single {name iterations script} {
    # 预热
    for {set i 0} {$i < 100} {incr i} {
        uplevel 1 $script
    }

    set start [clock microseconds]
    for {set i 0} {$i < $iterations} {incr i} {
        uplevel 1 $script
    }
    set elapsed [expr {[clock microseconds] - $start}]
    set per_op [expr {$elapsed / double($iterations)}]

    puts [format "  %-50s %8.0f us total  %8.3f us/op" \
        $name $elapsed $per_op]
}


proc ::benchmark::run_all {{iterations 100000}} {
    puts ""
    puts "============================================================"
    puts "kwargs 模块性能基准测试"
    puts "============================================================"
    puts [format "迭代次数: %d" $iterations]
    puts [format "Tcl 版本: [info patchlevel]"]
    puts [format "测试时间: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"]
    puts "============================================================"
    puts ""

    # 手动开启调试模式，避免受默认值影响
    set ::kwargs::debug_mode 1

    # ============================================================
    # 维度1：直接位置传参（基准线）
    # ============================================================
    puts "--- 维度1: 直接位置传参（基准线） ---"
    run_single "直接位置传参" $iterations {
        ::benchmark::_direct_pos {*}$::benchmark::pos_args
    }

    # ============================================================
    # 维度2：fake_wrap 伪关键字传参（debug_mode=1）
    # ============================================================
    puts ""
    puts "--- 维度2: fake_wrap 伪关键字传参（debug_mode=1） ---"
    run_single "fake_wrap (debug_mode=1, 10个参数)" $iterations {
        ::kwargs::fake_wrap ::benchmark::_direct_pos {*}$::benchmark::kw_args
    }

    # ============================================================
    # 维度3：inject 真正关键字传参（debug_mode=1）
    # ============================================================
    puts ""
    puts "--- 维度3: inject 真正关键字传参（debug_mode=1） ---"
    run_single "inject (debug_mode=1, 10个必选参数)" $iterations {
        ::benchmark::_kw_inject $::benchmark::kw_args
    }

    # ============================================================
    # 维度4：不同参数数量的影响（debug_mode=1）
    # ============================================================
    puts ""
    puts "--- 维度4: 参数数量对性能的影响（debug_mode=1） ---"

    # 2个参数
    proc ::benchmark::_direct_2 {a b} { return [expr {$a + $b}] }
    proc ::benchmark::_kw_inject_2 {caller_args} {
        ::kwargs::inject $caller_args {-a -b} {}
        return [expr {$a + $b}]
    }

    run_single "直接传参 (debug_mode=1, 2个参数)" $iterations {
        ::benchmark::_direct_2 1 2
    }
    run_single "inject (debug_mode=1, 2个参数)" $iterations {
        ::benchmark::_kw_inject_2 {-a 1 -b 2}
    }

    # 5个参数
    proc ::benchmark::_direct_5 {a b c d e} { return [expr {$a + $b + $c + $d + $e}] }
    proc ::benchmark::_kw_inject_5 {caller_args} {
        ::kwargs::inject $caller_args {-a -b -c -d -e} {}
        return [expr {$a + $b + $c + $d + $e}]
    }

    run_single "直接传参 (debug_mode=1, 5个参数)" $iterations {
        ::benchmark::_direct_5 1 2 3 4 5
    }
    run_single "inject (debug_mode=1, 5个参数)" $iterations {
        ::benchmark::_kw_inject_5 {-a 1 -b 2 -c 3 -d 4 -e 5}
    }

    # 20个参数
    proc ::benchmark::_direct_20 {a b c d e f g h i j k l m n o p q r s t} {
        return [expr {$a + $b + $c + $d + $e + $f + $g + $h + $i + $j
            + $k + $l + $m + $n + $o + $p + $q + $r + $s + $t}]
    }
    proc ::benchmark::_kw_inject_20 {caller_args} {
        ::kwargs::inject $caller_args \
            {-a -b -c -d -e -f -g -h -i -j -k -l -m -n -o -p -q -r -s -t} {}
        return [expr {$a + $b + $c + $d + $e + $f + $g + $h + $i + $j
            + $k + $l + $m + $n + $o + $p + $q + $r + $s + $t}]
    }

    run_single "直接传参 (debug_mode=1, 20个参数)" $iterations {
        ::benchmark::_direct_20 {*}$::benchmark::pos_args_20
    }
    run_single "inject (debug_mode=1, 20个参数)" $iterations {
        ::benchmark::_kw_inject_20 $::benchmark::kw_args_20
    }

    # ============================================================
    # 维度5：可选参数对性能的影响（debug_mode=1）
    # ============================================================
    puts ""
    puts "--- 维度5: 可选参数对性能的影响（debug_mode=1） ---"

    proc ::benchmark::_kw_inject_opt_all {caller_args} {
        ::kwargs::inject $caller_args {} \
            {-a 0 -b 0 -c 0 -d 0 -e 0 -f 0 -g 0 -h 0 -i 0 -j 0}
        return [expr {$a + $b + $c + $d + $e + $f + $g + $h + $i + $j}]
    }

    proc ::benchmark::_kw_inject_mixed {caller_args} {
        ::kwargs::inject $caller_args {-a -b -c -d -e} \
            {-f 0 -g 0 -h 0 -i 0 -j 0}
        return [expr {$a + $b + $c + $d + $e + $f + $g + $h + $i + $j}]
    }

    run_single "inject 全部可选 (debug_mode=1, 提供全部)" $iterations {
        ::benchmark::_kw_inject_opt_all $::benchmark::kw_args
    }
    run_single "inject 全部可选 (debug_mode=1, 不提供)" $iterations {
        ::benchmark::_kw_inject_opt_all {}
    }
    run_single "inject 5必选+5可选 (debug_mode=1, 提供全部)" $iterations {
        ::benchmark::_kw_inject_mixed $::benchmark::kw_args
    }
    run_single "inject 5必选+5可选 (debug_mode=1, 只提供必选)" $iterations {
        ::benchmark::_kw_inject_mixed {-a 1 -b 2 -c 3 -d 4 -e 5}
    }

    # ============================================================
    # 维度6：check_formal_parameters 单独测试（debug_mode=1）
    # ============================================================
    puts ""
    puts "--- 维度6: _check_formal_parameters 开销（debug_mode=1） ---"
    run_single "_check_formal_parameters (debug_mode=1, 10个必选)" $iterations {
        ::kwargs::_check_formal_parameters {-a -b -c -d -e -f -g -h -i -j} {}
    }
    run_single "_check_formal_parameters (debug_mode=1, 10个可选)" $iterations {
        ::kwargs::_check_formal_parameters {} {-a 0 -b 0 -c 0 -d 0 -e 0 -f 0 -g 0 -h 0 -i 0 -j 0}
    }
    run_single "_check_formal_parameters (debug_mode=1, 5必选+5可选)" $iterations {
        ::kwargs::_check_formal_parameters {-a -b -c -d -e} {-f 0 -g 0 -h 0 -i 0 -j 0}
    }

    # ============================================================
    # 维度7：_has_duplicate 开销（debug_mode=1）
    # ============================================================
    puts ""
    puts "--- 维度7: _has_duplicates 开销（debug_mode=1） ---"
    run_single "_has_duplicates (debug_mode=1, 10个元素, 无重复)" $iterations {
        ::kwargs::_has_duplicates {-a -b -c -d -e -f -g -h -i -j}
    }
    run_single "_has_duplicates (debug_mode=1, 10个元素, 有重复)" $iterations {
        ::kwargs::_has_duplicates {-a -b -c -d -e -a -b -c -d -e}
    }

    # ============================================================
    # 维度8：调试模式开启/关闭对比
    # ============================================================
    puts ""
    puts "--- 维度8: 调试模式开启/关闭对比 ---"

    # 保存原始调试模式状态
    set original_debug_mode $::kwargs::debug_mode

    # --- fake_wrap 调试模式对比 ---
    # 调试模式开启 (debug_mode=1)
    set ::kwargs::debug_mode 1
    run_single "fake_wrap (debug_mode=1, 10个参数)" $iterations {
        ::kwargs::fake_wrap ::benchmark::_direct_pos {*}$::benchmark::kw_args
    }

    # 调试模式关闭 (debug_mode=0)
    set ::kwargs::debug_mode 0
    run_single "fake_wrap (debug_mode=0, 10个参数)" $iterations {
        ::kwargs::fake_wrap ::benchmark::_direct_pos {*}$::benchmark::kw_args
    }

    # --- inject 调试模式对比 ---
    # 调试模式开启 (debug_mode=1)
    set ::kwargs::debug_mode 1
    run_single "inject (debug_mode=1, 10个必选)" $iterations {
        ::benchmark::_kw_inject $::benchmark::kw_args
    }

    # 调试模式关闭 (debug_mode=0)
    set ::kwargs::debug_mode 0
    run_single "inject (debug_mode=0, 10个必选)" $iterations {
        ::benchmark::_kw_inject $::benchmark::kw_args
    }

    # 调试模式开启 (debug_mode=1, 5必选+5可选)
    set ::kwargs::debug_mode 1
    run_single "inject (debug_mode=1, 5必选+5可选)" $iterations {
        ::benchmark::_kw_inject_mixed $::benchmark::kw_args
    }

    # 调试模式关闭 (debug_mode=0, 5必选+5可选)
    set ::kwargs::debug_mode 0
    run_single "inject (debug_mode=0, 5必选+5可选)" $iterations {
        ::benchmark::_kw_inject_mixed $::benchmark::kw_args
    }

    # 恢复原始调试模式状态
    set ::kwargs::debug_mode $original_debug_mode

    puts ""
    puts "============================================================"
    puts "基准测试完成"
    puts "============================================================"
}


set script_dir [file dirname [info script]]
set parent_dir [file dirname $script_dir]
if {$parent_dir ni $::auto_path} {
    lappend ::auto_path $parent_dir
}
package require kwargs
::benchmark::run_all 100000
