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
MINIUPNPD_MK="$(find "$FEEDS_PACKAGES" -maxdepth 3 -type f -wholename '*/miniupnpd/Makefile' -print -quit 2>/dev/null)"
if [ -f "$MINIUPNPD_MK" ] && grep -q '^PKG_VERSION:=2\.3\.11' "$MINIUPNPD_MK"; then
	echo " "
	MINIUPNPD_PATCH_DIR="$(dirname "$MINIUPNPD_MK")/patches"
	if [ -d "$MINIUPNPD_PATCH_DIR" ]; then
		for STALE_PATCH in \
			020-descr-filter-fix.patch \
			030-allow-private-fix.patch \
			040-improve-logging.patch \
			900-miniupnpd-format-xml-to-make-some-app-happy.patch; do
			if [ -f "$MINIUPNPD_PATCH_DIR/$STALE_PATCH" ]; then
				rm -f "$MINIUPNPD_PATCH_DIR/$STALE_PATCH"
				echo "removed stale miniupnpd patch: $STALE_PATCH"
			fi
		done
		echo "miniupnpd 2.3.11 stale patches have been removed!"
	else
		echo "miniupnpd patches directory not found; continuing!"
	fi
fi
