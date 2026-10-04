#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#安装和更新软件包
UPDATE_PACKAGE() {
	local PKG_NAME=$1
	local PKG_REPO=$2
	local PKG_BRANCH=$3
	local PKG_SPECIAL=$4
	local PKG_LIST=("$PKG_NAME" $5)  # 第5个参数为自定义名称列表
	local REPO_NAME=${PKG_REPO#*/}
	local REPO_PATH="./package/$REPO_NAME"

	echo " "

	# 删除本地可能存在的不同名称的软件包
	for NAME in "${PKG_LIST[@]}"; do
		# 查找匹配的目录
		echo "Search directory: $NAME"
		local FOUND_DIRS=$(find ./feeds/luci/ ./feeds/packages/ -maxdepth 3 -type d -iname "*$NAME*" 2>/dev/null)

		# 删除找到的目录
		if [ -n "$FOUND_DIRS" ]; then
			while read -r DIR; do
				rm -rf "$DIR"
				echo "Delete directory: $DIR"
			done <<< "$FOUND_DIRS"
		else
			echo "Not fonud directory: $NAME"
		fi
	done

	# 克隆 GitHub 仓库
	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" $REPO_PATH

	# 处理克隆的仓库
	if [[ "$PKG_SPECIAL" == "pkg" ]]; then
		find $REPO_PATH/*/ -maxdepth 3 -type d -iname "*$PKG_NAME*" -prune -exec cp -rf {} ./package \;
		rm -rf $REPO_PATH
	fi
}

# 调用示例
# UPDATE_PACKAGE "OpenAppFilter" "destan19/OpenAppFilter" "master" "" "custom_name1 custom_name2"
# UPDATE_PACKAGE "open-app-filter" "destan19/OpenAppFilter" "master" "" "luci-app-appfilter oaf" 这样会把原有的open-app-filter，luci-app-appfilter，oaf相关组件删除，不会出现coremark错误。

# UPDATE_PACKAGE "包名" "项目地址" "项目分支" "pkg，可选，从大杂烩中单独提取包名插件"
UPDATE_PACKAGE "argon" "sbwml/luci-theme-argon" "openwrt-25.12"
UPDATE_PACKAGE "aurora" "eamonxg/luci-theme-aurora" "master"
UPDATE_PACKAGE "aurora-config" "eamonxg/luci-app-aurora-config" "master"
UPDATE_PACKAGE "fluent" "LazuliKao/luci-theme-fluent" "main"
UPDATE_PACKAGE "footstrap" "VizzleTF/luci-theme-footstrap" "main"
UPDATE_PACKAGE "kucat" "sirpdboy/luci-theme-kucat" "master"
UPDATE_PACKAGE "kucat-config" "sirpdboy/luci-app-kucat-config" "master"
UPDATE_PACKAGE "shadcn" "eamonxg/luci-theme-shadcn" "main"

UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "master" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "axonhub gecoosac sing-box luci-app-homeproxy luci-app-timewol luci-app-wolplus luci-app-wolultra"
UPDATE_PACKAGE "vnt" "lmq8267/luci-app-vnt" "main"

UPDATE_PACKAGE "diskman" "sbwml/luci-app-diskman" "main"
UPDATE_PACKAGE "mosdns" "sbwml/luci-app-mosdns" "v5" "" "v2dat"
UPDATE_PACKAGE "openlist2" "sbwml/luci-app-openlist2" "main"
UPDATE_PACKAGE "qbittorrent" "sbwml/luci-app-qbittorrent" "master" "" "qt6base qt6tools rblibtorrent"
UPDATE_PACKAGE "quickfile" "sbwml/luci-app-quickfile" "main"

UPDATE_PACKAGE "ddns-go" "sirpdboy/luci-app-ddns-go" "main"
UPDATE_PACKAGE "netspeedtest" "sirpdboy/netspeedtest" "main" "" "homebox ookla-speedtest"
UPDATE_PACKAGE "netwizard" "sirpdboy/luci-app-netwizard" "main"
UPDATE_PACKAGE "partexp" "sirpdboy/luci-app-partexp" "main"
UPDATE_PACKAGE "timecontrol" "sirpdboy/luci-app-timecontrol" "main"

UPDATE_PACKAGE "natmapt" "muink/openwrt-natmapt" "master"
UPDATE_PACKAGE "stuntman" "muink/openwrt-stuntman" "master"
UPDATE_PACKAGE "luci-app-natmapt" "muink/luci-app-natmapt" "master"

UPDATE_PACKAGE "airpi3000m-fancontrol" "LianXia233/luci-app-airpi3000m-fancontrol" "main"
UPDATE_PACKAGE "chfs" "LianXia233/luci-app-chfs" "main"
UPDATE_PACKAGE "fm350" "LianXia233/luci-app-fm350" "main"
UPDATE_PACKAGE "h5000m-netmode" "LianXia233/luci-app-h5000m-netmode" "main"
UPDATE_PACKAGE "mt5700" "LianXia233/luci-app-mt5700" "main"
UPDATE_PACKAGE "mt5700m" "LianXia233/luci-app-mt5700m" "main"
UPDATE_PACKAGE "netmonitor" "LianXia233/luci-app-netmonitor" "main"
UPDATE_PACKAGE "qmodem-generic" "LianXia233/luci-app-qmodem-generic" "main"

UPDATE_PACKAGE "luci-app-onliner" "xx-vv/luci-app-onliner" "main"
UPDATE_PACKAGE "mt5700webui" "inotdream/mt5700webui-openwrt-server" "feat/go-backend"
UPDATE_PACKAGE "modemdata" "obsy/modemdata" "main"
UPDATE_PACKAGE "luci-app-modemdata" "4IceG/luci-app-modemdata" "main"
#UPDATE_PACKAGE "packges-gc9307" "zzzz0317/kmod-fb-tft-gc9307" "main"
UPDATE_PACKAGE "xgp-v3-screen" "junhong-l/xgp-v3-screen" "main"
UPDATE_PACKAGE "proton2025" "ChesterGoodiny/luci-theme-proton2025" "main"

# QModem 仓库按 feed（src-git）设计：顶层没有 Makefile，包分散在 application/、luci/、
# driver/ 等二级目录。OpenWrt 的 package 扫描（package/Makefile 的 builddirs）只认含
# Makefile 的一级子目录，仅把克隆目录放进 package/ 会整个不可见，导致
# CONFIG_PACKAGE_luci-app-qmodem* / qmodem / sms-forwarder-next 等配置符号在 defconfig
# 阶段被静默丢弃，固件里没有 qmodem。这里仿照上游 CI 的 src-link 方式把克隆目录注册为
# 本地 feed，scripts/feeds 会递归扫描二级目录并把各包链接到 package/feeds/qmodem/ 下。
# feeds 目录在 WRT-CORE 的 Update Feeds 步骤已就绪，此处仅增量处理 qmodem feed。
REGISTER_QMODEM_FEED() {
	# 先把克隆目录移出 package/：否则 package/ 主扫描会提前命中 QModem 二级目录里的
	# Makefile（application/*、luci/*），把 luci-app-qmodem / qmodem 等注册为 core
	# package，feeds install 时 "Not overriding core package" 直接跳过链接，配置符号
	# 在 defconfig 阶段又被静默丢弃，LuCI 前端依旧进不了固件。
	if [ -d "./QModem" ] && [ ! -d "../QModem" ]; then
		mv -f ./QModem ../QModem
		echo "qmodem: 克隆目录已移出 package/ 至 ../QModem"
	fi
	local QMODEM_DIR="../QModem"
	[ -d "$QMODEM_DIR" ] || { echo "qmodem: 克隆目录不存在，跳过 feed 注册"; return 1; }

	# scripts/feeds 的解析顺序：feeds.conf 存在则完全替代 feeds.conf.default
	local FEEDS_CONF="../feeds.conf"
	[ -f "$FEEDS_CONF" ] || FEEDS_CONF="../feeds.conf.default"

	# src-link 的目标按原样传给 ln -s，必须用绝对路径
	local QMODEM_ABS="$(cd ../QModem && pwd)"
	if ! grep -q "^src-link qmodem " "$FEEDS_CONF" 2>/dev/null; then
		echo "src-link qmodem $QMODEM_ABS" >> "$FEEDS_CONF"
	fi

	# src-link 的 update 为空操作，只会创建 feeds/qmodem -> 克隆目录 的链接
	if ! ( cd .. && ./scripts/feeds update qmodem && ./scripts/feeds install -a -p qmodem ); then
		echo "qmodem: feed 注册失败，固件将不含 qmodem 包"
		return 1
	fi
	echo "qmodem: 已注册为本地 feed 并安装到 package/feeds/qmodem/"
}
REGISTER_QMODEM_FEED

# QModem 包共用 version.mk 的 QMODEM_VERSION（当前上游发布 "3.4.0-rc.3"）。
# OpenWrt 新版 apk 打包器不接受 `-rc.N`：版本串被拼成 "3.4.0-rc.3-rN" 后，
# apk mkpkg 报 "package version is invalid"（Error 99），阻断整个固件构建
# （libqmodem-sms / sms-tool_q 今日 6 job 全灭即此因）。这里在克隆后把
# X.Y.Z-rc.N 改写为 apk 合法的 X.Y.Z_rcN；QModem 各包源码均内嵌仓库 src/，
# 无版本化下载依赖，改写只影响包版本元数据。若上游已改为合法版本，自动跳过。
FIX_QMODEM_VERSION() {
	local VER_FILE="../QModem/version.mk"
	[ -f "$VER_FILE" ] || { echo "qmodem: version.mk not found, skip"; return 0; }
	if grep -qE '^QMODEM_VERSION:=[0-9]+\.[0-9]+\.[0-9]+-rc\.[0-9]+$' "$VER_FILE"; then
		sed -i -E 's/^(QMODEM_VERSION:=)([0-9]+\.[0-9]+\.[0-9]+)-rc\.([0-9]+)$/\1\2_rc\3/' "$VER_FILE"
		echo "qmodem: QMODEM_VERSION sanitized to $(grep -E '^QMODEM_VERSION:=' "$VER_FILE")"
	else
		echo "qmodem: QMODEM_VERSION already apk-valid, no change"
	fi
}
FIX_QMODEM_VERSION

# QModem 上游 2026-09-11 提交 86102c2a6f（"integrate independent SIP SMS and VoIP
# services"）给 sms-forwarder-next 的 DEPENDS 追加了 +qmodem-sipd，形成依赖链
# luci-app-qmodem-next → sms-forwarder-next → qmodem-sipd → qmodem-voip →
# libwebsockets-mbedtls；而 ttyd 依赖 libwebsockets-full，两个 libwebsockets
# 变体互斥（均提供 libwebsockets=4.5.8-r1 并互设 CONFLICTS），导致 rootfs 组装
# 阶段 apk 报 "unable to select packages"，-next 变体全部编译失败。
# 这里在克隆后把 +qmodem-sipd 从 sms-forwarder-next 的 DEPENDS 中摘除：
# SMS 转发（ServerChan / Webhook / 自定义脚本）不受影响，仅去掉依赖 VoIP 栈的
# SIP MESSAGE 通道。若上游调整依赖后已不含 +qmodem-sipd，自动跳过。
FIX_QMODEM_VOIP_DEP() {
	local SFN_FILE="../QModem/application/sms_forwarder_next/Makefile"
	[ -f "$SFN_FILE" ] || { echo "qmodem: sms_forwarder_next/Makefile not found, skip"; return 0; }
	if grep -q '+qmodem-sipd' "$SFN_FILE"; then
		sed -i 's/ +qmodem-sipd//' "$SFN_FILE"
		echo "qmodem: removed +qmodem-sipd from sms-forwarder-next DEPENDS (libwebsockets variant conflict workaround)"
	else
		echo "qmodem: sms-forwarder-next DEPENDS already clean, no change"
	fi
}
FIX_QMODEM_VOIP_DEP

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./ ./feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

	if [ -z "$PKG_FILES" ]; then
		echo "$PKG_NAME not found!"
		return
	fi

	echo -e "\n$PKG_NAME version update has started!"

	for PKG_FILE in $PKG_FILES; do
		local PKG_REPO=$(grep -Po "PKG_SOURCE_URL:=https://.*github.com/\K[^/]+/[^/]+(?=.*)" $PKG_FILE)
		local PKG_TAG=$(curl -sL "https://api.github.com/repos/$PKG_REPO/releases" | jq -r "map(select(.prerelease == $PKG_MARK)) | first | .tag_name")

		local OLD_VER=$(grep -Po "PKG_VERSION:=\K.*" "$PKG_FILE")
		local OLD_URL=$(grep -Po "PKG_SOURCE_URL:=\K.*" "$PKG_FILE")
		local OLD_FILE=$(grep -Po "PKG_SOURCE:=\K.*" "$PKG_FILE")
		local OLD_HASH=$(grep -Po "PKG_HASH:=\K.*" "$PKG_FILE")

		local PKG_URL=$([[ "$OLD_URL" == *"releases"* ]] && echo "${OLD_URL%/}/$OLD_FILE" || echo "${OLD_URL%/}")

		local NEW_VER=$(echo $PKG_TAG | sed -E 's/[^0-9]+/\./g; s/^\.|\.$//g')
		local NEW_URL=$(echo $PKG_URL | sed "s/\$(PKG_VERSION)/$NEW_VER/g; s/\$(PKG_NAME)/$PKG_NAME/g")
		local NEW_HASH=$(curl -sL "$NEW_URL" | sha256sum | cut -d ' ' -f 1)

		echo "old version: $OLD_VER $OLD_HASH"
		echo "new version: $NEW_VER $NEW_HASH"

		if [[ "$NEW_VER" =~ ^[0-9].* ]] && dpkg --compare-versions "$OLD_VER" lt "$NEW_VER"; then
			sed -i "s/PKG_VERSION:=.*/PKG_VERSION:=$NEW_VER/g" "$PKG_FILE"
			sed -i "s/PKG_HASH:=.*/PKG_HASH:=$NEW_HASH/g" "$PKG_FILE"
			echo "$PKG_FILE version has been updated!"
		else
			echo "$PKG_FILE version is already the latest!"
		fi
	done
}

#UPDATE_VERSION "软件包名" "测试版，true，可选，默认为否"
#UPDATE_VERSION "sing-box"

#引入私有扩展脚本
if [ -f "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh" ]; then
	source "$GITHUB_WORKSPACE/Scripts/PRIVATE.sh"
fi
