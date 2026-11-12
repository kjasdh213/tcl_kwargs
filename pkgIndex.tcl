# ============================================================================
# kwargs - 包索引文件 (pkgIndex.tcl)
#
# Copyright (c) 2026 kjasdh213 <https://github.com/kjasdh213>
#
# Licensed under the MIT License.
# License: https://opensource.org/licenses/MIT
# Full text: see the LICENSE file in this repository.
# ============================================================================

# 包索引文件，用于支持 `package require kwargs` 语法。
# 当 kwargs 目录在 `auto_path` 中时，Tcl 会自动加载此文件。

package ifneeded kwargs 1.0.0 [list source [file join $dir kwargs.tcl]]
