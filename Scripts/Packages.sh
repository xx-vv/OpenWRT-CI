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

	# 克隆 GitHub 仓库	git clone --depth=1 --single-branch --branch $PKG_BRANCH "https://github.com/$PKG_REPO.git" $REPO_PATH

	# ★ 克隆失败即退出：避免网络瞬断/仓库不存在时留下残缺 package 树，
	#   让后续校验或编译在缺包状态下浪费时间（日志里曾出现
	#   "could not read Username for 'https://github.com'" 后继续跑的情况）。
	if [ ! -d "$REPO_PATH/.git" ]; then
		echo "ERROR: git clone failed for $PKG_REPO (branch: $PKG_BRANCH)" >&2
		exit 1
	fi

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
UPDATE_PACKAGE "vantage" "anothaDev/luci-theme-vantage" "main"

UPDATE_PACKAGE "momo" "nikkinikki-org/OpenWrt-momo" "main"
UPDATE_PACKAGE "nikki" "nikkinikki-org/OpenWrt-nikki" "main"
UPDATE_PACKAGE "openclash" "vernesong/OpenClash" "dev" "pkg"
UPDATE_PACKAGE "passwall" "Openwrt-Passwall/openwrt-passwall" "main" "pkg"
UPDATE_PACKAGE "passwall2" "Openwrt-Passwall/openwrt-passwall2" "main" "pkg"

UPDATE_PACKAGE "diskmanager" "4IceG/luci-app-mini-diskmanager" "main"
UPDATE_PACKAGE "easytier" "EasyTier/luci-app-easytier" "main"
# QModem 与 MT5700 抢同一 AT 串口，且 TR3000.txt 里所有 qmodem 配置均已注释；
# 不再克隆，省 clone 时间。如需恢复，取消下一行注释。
#UPDATE_PACKAGE "qmodem" "FUjr/QModem" "main"
UPDATE_PACKAGE "viking" "VIKINGYFY/packages" "main" "" "axonhub gecoosac miniupnpd sing-box luci-app-homeproxy luci-app-timewol luci-app-upnp luci-app-wolplus luci-app-wolultra"
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

#UPDATE_PACKAGE "airpi3000m-fancontrol" "LianXia233/luci-app-airpi3000m-fancontrol" "main"
#UPDATE_PACKAGE "chfs" "LianXia233/luci-app-chfs" "main"
#UPDATE_PACKAGE "fm350" "LianXia233/luci-app-fm350" "main"
#UPDATE_PACKAGE "h5000m-netmode" "LianXia233/luci-app-h5000m-netmode" "main"
UPDATE_PACKAGE "mt5700" "LianXia233/luci-app-mt5700" "main"
#UPDATE_PACKAGE "mt5700m" "LianXia233/luci-app-mt5700m" "main"
#UPDATE_PACKAGE "netmonitor" "LianXia233/luci-app-netmonitor" "main"
#UPDATE_PACKAGE "qmodem-generic" "LianXia233/luci-app-qmodem-generic" "main"

# ===== luci-app-mt5700 克隆结果校验 + 预编译注入 =====
# 上游仓库结构调整、文件改名或漏推时在此尽早失败，避免数小时后才在编译阶段暴露。
MT5700_DIR="./package/luci-app-mt5700"
MT5700_REQUIRED="Makefile
src/Makefile
src/rust/Cargo.toml
src/rust/Cargo.lock
root/etc/init.d/at-webserver
root/etc/config/at-webserver
root/usr/share/rpcd/ucode/mt5700.uc
root/usr/share/luci/menu.d/luci-app-mt5700.json
root/usr/share/rpcd/acl.d/luci-app-mt5700.json
htdocs/luci-static/resources/view/at-webserver/network_status.js
po/zh_Hans/luci-app-mt5700.po"
MT5700_MISSING=""
while read -r MT5700_FILE; do
	[ -z "$MT5700_FILE" ] && continue
	[ -f "$MT5700_DIR/$MT5700_FILE" ] || MT5700_MISSING="$MT5700_MISSING $MT5700_FILE"
done <<< "$MT5700_REQUIRED"
if [ -n "$MT5700_MISSING" ]; then
	echo "ERROR: LianXia233/luci-app-mt5700 仓库结构异常，缺少:$MT5700_MISSING" >&2
	exit 1
fi
MT5700_VER=$(sed -n 's/^PKG_VERSION:=//p' "$MT5700_DIR/Makefile" | head -1)
MT5700_BACKEND_VER=$(sed -n 's/^version[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "$MT5700_DIR/src/rust/Cargo.toml" | head -1)
MT5700_INFO="plugin ${MT5700_VER} / backend ${MT5700_BACKEND_VER}"
echo "luci-app-mt5700 version: $MT5700_INFO"
[ -n "${GITHUB_ENV:-}" ] && echo "MT5700_VERSION=$MT5700_INFO" >> "$GITHUB_ENV"

# ===== 深度适配：让包在 buildroot 内使用 CI 预编译的 Rust 后端 =====
# 固件构建阶段的 PATH 只有交叉工具链（rules.mk 里 export PATH:=$(TARGET_PATH)），
# 既没有宿主 cargo/rustc，也不适合在 CI 里临时拉起 feeds/packages/lang/rust
# （host rust 要现场编译 LLVM，动辄 1~2 小时且占 20GB 磁盘）。
# 因此 WRT-CORE-MT5700.yml 在编译前用 rustup + zig 交叉编译出 aarch64 musl 静态
# 二进制，放到 src/prebuilt/at-webserver；这里把上游 src/Makefile 的 compile 目标
# 改成「有预编译产物就直接装，否则回退上游 cargo 构建」，install 目标无需改动。
# 上游若调整 compile 规则，正则匹配数量校验会立刻失败，而不是静默编出旧逻辑。
PREPARE_MT5700_PREBUILT() {
	local MAKE_FILE="$MT5700_DIR/src/Makefile"

	python3 - "$MAKE_FILE" <<'PY'
import io
import re
import sys

path = sys.argv[1]
src = io.open(path, encoding='utf-8').read()

if 'MT5700_PREBUILT_HOOK' in src:
    print('luci-app-mt5700: 预编译注入已存在，跳过')
    sys.exit(0)

if re.search(r'^install:', src, re.M) is None:
    sys.exit('ERROR: src/Makefile 缺少 install 目标，上游结构已变更，需人工复核预编译注入')

new_compile = '''# ==== MT5700_PREBUILT_HOOK（本仓库深度适配，勿手改）====
# 固件构建阶段 PATH 内没有 cargo；CI 已用 rustup + zig 交叉编译出静态后端，
# 放在 src/prebuilt/at-webserver。存在时直接复制到 $(BIN)，否则回退上游 cargo 构建。
compile:
	@if [ -x "$(CURDIR)/prebuilt/at-webserver" ]; then \\
		echo "==> [mt5700] 使用预编译后端: $(CURDIR)/prebuilt/at-webserver"; \\
		mkdir -p "$(dir $(BIN))"; \\
		cp -f "$(CURDIR)/prebuilt/at-webserver" "$(BIN)"; \\
	else \\
		echo "==> [mt5700] cargo build: ARCH=$(ARCH) ARCH_PACKAGES=$(ARCH_PACKAGES) RUST_TARGET=$(RUST_TARGET)"; \\
		cd $(RUST_DIR) && \\
			CARGO_TARGET_DIR="$(CARGO_TARGET_DIR)" \\
			cargo build $(CARGO_BUILD_STD_FLAGS) --release --target $(RUST_TARGET); \\
	fi
	test -x "$(BIN)" || { echo "ERROR: 未产出后端二进制 $(BIN)"; exit 1; }
	@echo "==> [mt5700] 后端二进制就绪: $(BIN)"

'''

# 用 lambda 作为替换参数，避免 re.subn 把 new_compile 里的反斜杠当转义序列解析
# （Python 替换字符串对 \ + 非数字字符的解析行为在旧版本上可能报 bad escape）
patched, n = re.subn(r'(?ms)^compile:.*?(?=^install:)', lambda m: new_compile, src)
if n != 1:
    sys.exit('ERROR: src/Makefile 的 compile 目标匹配数量为 %d（期望 1），上游结构已变更' % n)

io.open(path, 'w', encoding='utf-8', newline='\n').write(patched)
print('luci-app-mt5700: 已注入预编译后端分支')
PY
}

PREPARE_MT5700_PREBUILT

UPDATE_PACKAGE "luci-app-onliner" "xx-vv/luci-app-onliner" "main"
#UPDATE_PACKAGE "mt5700webui" "inotdream/mt5700webui-openwrt-server" "feat/go-backend"
#UPDATE_PACKAGE "modemdata" "obsy/modemdata" "main"
#UPDATE_PACKAGE "luci-app-modemdata" "4IceG/luci-app-modemdata" "main"
#UPDATE_PACKAGE "packges-gc9307" "zzzz0317/kmod-fb-tft-gc9307" "main"
#UPDATE_PACKAGE "xgp-v3-screen" "junhong-l/xgp-v3-screen" "main"
UPDATE_PACKAGE "proton2025" "ChesterGoodiny/luci-theme-proton2025" "main"

#更新软件包版本
UPDATE_VERSION() {
	local PKG_NAME=$1
	local PKG_MARK=${2:-false}
	local PKG_FILES=$(find ./package/ ./feeds/packages/ -maxdepth 3 -type f -wholename "*/$PKG_NAME/Makefile")

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
