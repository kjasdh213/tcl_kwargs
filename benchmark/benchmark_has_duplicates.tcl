# ============================================================================
# kwargs - _has_duplicates 各实现方案性能基准测试
#
# Copyright (c) 2026 kjasdh213 <https://github.com/kjasdh213>
#
# Licensed under the MIT License.
# License: https://opensource.org/licenses/MIT
# Full text: see the LICENSE file in this repository.
# ============================================================================

# _has_duplicates 各实现方案性能基准测试
#
# 对比多种检测列表重复项的算法：
# 1. lsort -unique（当前实现）
# 2. struct::set size（tcllib）
# 3. dict 键唯一性
# 4. array 键唯一性
# 5. seen 变量 + in 操作
#
# 测试结果（Tcl 8.6.13, Windows 10, 10,000 次迭代）:
#
#     ============================================================
#     _has_duplicates 各实现方案性能基准测试
#     ============================================================
#     迭代次数: 10000
#     Tcl 版本: 8.6.13
#     测试时间: 2026-05-13 13:31:51
#     ============================================================
#
#     --- 维度: 10 个元素, 无重复 ---
#       lsort -unique (无重复, 10 个元素)                            7349 us total     0.735 us/op
#       struct::set size (无重复, 10 个元素)                        15167 us total     1.517 us/op
#       dict (无重复, 10 个元素)                                    25775 us total     2.578 us/op
#       array (无重复, 10 个元素)                                   15709 us total     1.571 us/op
#       seen+in (无重复, 10 个元素)                                 14379 us total     1.438 us/op
#
#     --- 维度: 10 个元素, 有重复 ---
#       lsort -unique (有重复, 10 个元素)                            6445 us total     0.644 us/op
#       struct::set size (有重复, 10 个元素)                        13340 us total     1.334 us/op
#       dict (有重复, 10 个元素)                                    23584 us total     2.358 us/op
#       array (有重复, 10 个元素)                                   11253 us total     1.125 us/op
#       seen+in (有重复, 10 个元素)                                  5463 us total     0.546 us/op
#
#     --- 维度: 100 个元素, 无重复 ---
#       lsort -unique (无重复, 100 个元素)                          42127 us total     4.213 us/op
#       struct::set size (无重复, 100 个元素)                      102418 us total    10.242 us/op
#       dict (无重复, 100 个元素)                                  144013 us total    14.401 us/op
#       array (无重复, 100 个元素)                                  79235 us total     7.923 us/op
#       seen+in (无重复, 100 个元素)                               412827 us total    41.283 us/op
#
#     --- 维度: 100 个元素, 有重复 ---
#       lsort -unique (有重复, 100 个元素)                          26422 us total     2.642 us/op
#       struct::set size (有重复, 100 个元素)                       94422 us total     9.442 us/op
#       dict (有重复, 100 个元素)                                  144371 us total    14.437 us/op
#       array (有重复, 100 个元素)                                  64124 us total     6.412 us/op
#       seen+in (有重复, 100 个元素)                                 5270 us total     0.527 us/op
#
#     --- 维度: 1000 个元素, 无重复 ---
#       lsort -unique (无重复, 1000 个元素)                        472363 us total    47.236 us/op
#       struct::set size (无重复, 1000 个元素)                    1069404 us total   106.940 us/op
#       dict (无重复, 1000 个元素)                                1418070 us total   141.807 us/op
#       array (无重复, 1000 个元素)                                880126 us total    88.013 us/op
#       seen+in (无重复, 1000 个元素)                            23618863 us total  2361.886 us/op
#
#     --- 维度: 1000 个元素, 有重复 ---
#       lsort -unique (有重复, 1000 个元素)                        266913 us total    26.691 us/op
#       struct::set size (有重复, 1000 个元素)                     935392 us total    93.539 us/op
#       dict (有重复, 1000 个元素)                                1400983 us total   140.098 us/op
#       array (有重复, 1000 个元素)                                573375 us total    57.337 us/op
#       seen+in (有重复, 1000 个元素)                                5482 us total     0.548 us/op
#
#     ============================================================
#     基准测试完成
#     ============================================================


encoding system utf-8


namespace eval ::benchmark_has_duplicates {
    # ============================================================
    # 各实现方案
    # ============================================================

    # 方案1: lsort -unique（当前实现）
    proc _has_duplicates_lsort {input_list} {
        return [expr {[llength $input_list] != [llength [lsort -unique $input_list]]}]
    }

    # 方案2: struct::set size（tcllib）
    proc _has_duplicates_set {input_list} {
        return [expr {[llength $input_list] != [::struct::set size $input_list]}]
    }

    # 方案3: dict 键唯一性
    # 利用 dict 的键唯一性：将列表元素作为 dict 的键，然后比较键的数量
    # 注意：dict create 需要键值对，所以用 lmap 将每个元素映射为 {elem 1} 对
    proc _has_duplicates_dict {input_list} {
        return [expr {[llength $input_list] != [llength [dict keys [dict create {*}[lmap x $input_list {list $x 1}]]]]}]
    }

    # 方案4: array 键唯一性
    # 利用 array 的键唯一性：将列表元素作为 array 的键
    proc _has_duplicates_array {input_list} {
        array set _tmp_arr {}
        foreach elem $input_list {
            set _tmp_arr($elem) 1
        }
        set unique_count [array size _tmp_arr]
        return [expr {[llength $input_list] != $unique_count}]
    }

    # 方案5: seen 变量 + in 操作
    # 遍历列表，用 seen 记录已见过的元素，用 in 操作判断是否重复
    proc _has_duplicates_seen {input_list} {
        set seen {}
        foreach elem $input_list {
            if {$elem in $seen} {
                return 1
            }
            lappend seen $elem
        }
        return 0
    }
}


# ============================================================
# 测试数据生成
# ============================================================

proc ::benchmark_has_duplicates::_gen_no_duplicates {count} {
    # 生成无重复的测试数据（使用关键字格式，模拟 kwargs 场景）
    set result {}
    for {set i 0} {$i < $count} {incr i} {
        lappend result "-key_${i}"
    }
    return $result
}

proc ::benchmark_has_duplicates::_gen_with_duplicates {count} {
    # 生成有重复的测试数据（一半元素重复一次）
    set result {}
    set half [expr {$count / 2}]
    for {set i 0} {$i < $half} {incr i} {
        lappend result "-key_${i}" "-key_${i}"
    }
    # 如果 count 是奇数，补一个不重复的元素
    if {$count % 2 != 0} {
        lappend result "-key_odd"
    }
    return $result
}


# ============================================================
# 基准测试框架
# ============================================================

proc ::benchmark_has_duplicates::run_single {name iterations script} {
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


proc ::benchmark_has_duplicates::run_all {{iterations 100000}} {
    puts ""
    puts "============================================================"
    puts "_has_duplicates 各实现方案性能基准测试"
    puts "============================================================"
    puts [format "迭代次数: %d" $iterations]
    puts [format "Tcl 版本: [info patchlevel]"]
    puts [format "测试时间: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"]
    puts "============================================================"
    puts ""

    # 各数据规模的测试
    foreach {size_label size} {10 10 100 100 1000 1000} {
        # 无重复数据
        set data_no_dup [_gen_no_duplicates $size]
        # 有重复数据
        set data_with_dup [_gen_with_duplicates $size]

        # 无重复测试
        puts "--- 维度: $size_label 个元素, 无重复 ---"
        run_single "lsort -unique (无重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_lsort $data_no_dup]
        run_single "struct::set size (无重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_set $data_no_dup]
        run_single "dict (无重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_dict $data_no_dup]
        run_single "array (无重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_array $data_no_dup]
        run_single "seen+in (无重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_seen $data_no_dup]
        puts ""

        # 有重复测试
        puts "--- 维度: $size_label 个元素, 有重复 ---"
        run_single "lsort -unique (有重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_lsort $data_with_dup]
        run_single "struct::set size (有重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_set $data_with_dup]
        run_single "dict (有重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_dict $data_with_dup]
        run_single "array (有重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_array $data_with_dup]
        run_single "seen+in (有重复, $size_label 个元素)" $iterations [list ::benchmark_has_duplicates::_has_duplicates_seen $data_with_dup]
        puts ""
    }

    puts "============================================================"
    puts "基准测试完成"
    puts "============================================================"
}


# ============================================================
# 主入口
# ============================================================

set script_dir [file dirname [info script]]
set parent_dir [file dirname $script_dir]
if {$parent_dir ni $::auto_path} {
    lappend ::auto_path $parent_dir
}
package require kwargs

# 根据参数决定迭代次数
if {$::argc > 0} {
    set iterations [lindex $::argv 0]
} else {
    set iterations 100000
}

::benchmark_has_duplicates::run_all $iterations
