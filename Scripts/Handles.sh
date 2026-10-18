#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

FEEDS_PATH="./feeds"
PACKAGE_PATH="./package"

#修补命令统一入口：FIX <名称> <守卫目录> <命令...>
#守卫目录不存在时直接跳过，保证在 bash -e 下不中断
FIX() {
	local NAME=$1
	local GUARD=$2
	shift 2

	[ -d "$GUARD" ] || return 0

	echo " "
	if "$@"; then
		echo "$NAME has been fixed!"
	else
		echo "$NAME fix failed; continuing!"
	fi
}

#修改argon主题字体和颜色
FIX "theme-argon" "$PACKAGE_PATH/luci-theme-argon" sed -i \
	"s/primary '.*'/primary '#31a1a1'/g; s/'0.2'/'0.5'/g; s/'none'/'bing'/g; s/'600'/'normal'/g" \
	"$PACKAGE_PATH/luci-theme-argon/luci-app-argon-config/root/etc/config/argon"

#修改aurora菜单式样
FIX "theme-aurora" "$PACKAGE_PATH/luci-app-aurora-config" find \
	"$PACKAGE_PATH/luci-app-aurora-config/root/usr/share/aurora/" -type f -name '*.template' -exec sed -i \
	"s/nav_type '.*'/nav_type 'dropdown'/g; s/struct_radius_base '.*'/struct_radius_base '0.125rem'/g" {} +

#修改mini-diskmanager菜单位置
FIX "mini-diskmanager" "$PACKAGE_PATH/luci-app-mini-diskmanager" sed -i "s/services/system/g" \
	"$PACKAGE_PATH/luci-app-mini-diskmanager/luci-app-mini-diskmanager/root/usr/share/luci/menu.d/luci-app-mini-diskmanager.json"

#修改natmapt菜单位置
FIX "natmapt" "$PACKAGE_PATH/luci-app-natmapt" sed -i "s/network/services/g" \
	"$PACKAGE_PATH/luci-app-natmapt/root/usr/share/luci/menu.d/luci-app-natmap.json"

#修复Rust编译失败
FIX "rust" "$FEEDS_PATH/packages/lang/rust" sed -i 's/ci-llvm=true/ci-llvm=false/g' \
	"$FEEDS_PATH/packages/lang/rust/Makefile"

#修复 miniupnpd 2.3.11 打补丁失败
# 根因：上游 immortalwrt/packages 在 2026-10-16 合并 official 时只把 PKG_VERSION
# 从 2.3.9 升到 2.3.11，却没有同步刷新 patches 目录，导致旧补丁 hunk 全部失败：
#   - 020-descr-filter-fix / 030-allow-private-fix / 040-improve-logging 的改动
#     其实已并入 miniupnpd 2.3.11 上游（重复打补丁必然失败）；
#   - 900-format-xml 无法再套用（upnpsoap.c 变动过大）。
# 处理：检测到 2.3.11 时移除这 4 个失效补丁，保留仍能干净套用的
# 010-upnp-igdv2-compat（IGDv2 微软/苹果兼容），等价于上游 openwrt/packages
# 的「无补丁」状态，确保 miniupnpd（nftables / iptables 两个 variant）可以编译。
# ===== miniupnpd 过时补丁清理 =====
# 根因：上游 immortalwrt/packages 升级到 2.3.11，但未刷新 patches，导致旧补丁打不上。
# 处理：检测到 2.3.11 时，动态查找路径，精准移除已合入上游的 020/030，以及上下文失效的 040。
# 注意：保留 010 和 900 补丁（实测对 2.3.11 有效）。
FIX_MINIUPNPD_STALE_PATCHES() {
	# 动态查找 miniupnpd 目录，优先从 package/feeds 找，其次从 feeds 找
	local PATCH_DIR=$(find ./package/feeds ./feeds -maxdepth 4 -type d -name "miniupnpd" 2>/dev/null | head -n 1)
	
	# 如果动态查找失败，兜底尝试一下直接路径
	[ -z "$PATCH_DIR" ] && PATCH_DIR="../feeds/packages/net/miniupnpd"

	[ -d "$PATCH_DIR/patches" ] || { echo "miniupnpd: feed 补丁目录不存在，跳过"; return 0; }

	# 读取 feed 侧 PKG_VERSION 做版本闸门
	local VER
	VER=$(grep -m1 -oP '^PKG_VERSION:=\K.*' "$PATCH_DIR/Makefile" 2>/dev/null || true)
	case "$VER" in
		2.3.1[1-9]|2.3.[2-9][0-9]|2.[4-9].*|[3-9].*) ;;
		*) echo "miniupnpd: feed 版本 ${VER:-未知} < 2.3.11，补丁仍适配，跳过清理"; return 0 ;;
	esac

	# 020：解析器重写已入上游，补丁冗余
	local P020="$PATCH_DIR/patches/020-descr-filter-fix.patch"
	if [ -f "$P020" ] && grep -q "Rewrite permission line parser" "$P020"; then
		rm -f "$P020"
		echo "miniupnpd: 移除已合入上游的补丁 020-descr-filter-fix.patch"
	fi

	# 030：ALLOWPRIVATEIPV4MASK 修复已入上游，补丁冗余
	local P030="$PATCH_DIR/patches/030-allow-private-fix.patch"
	if [ -f "$P030" ] && grep -q "ALLOWPRIVATEIPV4MASK" "$P030"; then
		rm -f "$P030"
		echo "miniupnpd: 移除已合入上游的补丁 030-allow-private-fix.patch"
	fi

	# 040：logging 补丁未入上游但上下文已过期，无法适配 2.3.11，移除以恢复构建
	local P040="$PATCH_DIR/patches/040-improve-logging.patch"
	if [ -f "$P040" ]; then
		rm -f "$P040"
		echo "miniupnpd: 移除无法适配 $VER 的补丁 040-improve-logging.patch"
	fi
}
FIX_MINIUPNPD_STALE_PATCHES
