#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# ============================================================
# 1. 读取机型默认值（Config/wifi.txt）
#    优先级：WRT_* 环境变量 > 机型专属段 > 全局段 > 内置兜底
# ============================================================
WIFI_CFG="${GITHUB_WORKSPACE:-.}/Config/wifi.txt"
if [ -f "$WIFI_CFG" ]; then
	# shellcheck source=/dev/null
	source "$WIFI_CFG"
fi

# 设备键：WRT_CONFIG 首段，去非字母数字，转大写
# TR3000-immortalwrt -> TR3000；GL-MT3600BE-xxx -> GLMT3600BE
DEVICE_KEY=$(echo "${WRT_CONFIG%%-*}" | tr -cd '[:alnum:]' | tr '[:lower:]' '[:upper:]')
echo "设备键: $DEVICE_KEY"

# 通用取值：<DEVICE_KEY>_<SUFFIX> 存在则取，否则取全局 <SUFFIX>
pick() {
	local suffix=$1
	local specific="${DEVICE_KEY}_${suffix}"
	if [ -n "${!specific:-}" ]; then
		echo "${!specific}"
	else
		echo "${!suffix:-}"
	fi
}

# 环境变量优先，其次机型/全局，最后内置兜底
WRT_IP="${WRT_IP:-$(pick LAN_IP)}"
WRT_PW="${WRT_PW:-$(pick LAN_PASSWORD)}"
WRT_NAME="${WRT_NAME:-$(pick HOST_NAME)}"
WRT_SSID="${WRT_SSID:-$(pick WIFI_SSID)}"
WRT_WORD="${WRT_WORD:-$(pick WIFI_PASSWORD)}"
WRT_THEME="${WRT_THEME:-aurora}"

WIFI_ENCRYPTION="${WIFI_ENCRYPTION:-$(pick WIFI_ENCRYPTION)}"
WIFI_COUNTRY="${WIFI_COUNTRY:-$(pick WIFI_COUNTRY)}"
WIFI_2G_MODE="${WIFI_2G_MODE:-$(pick WIFI_2G_MODE)}"
WIFI_5G_MODE="${WIFI_5G_MODE:-$(pick WIFI_5G_MODE)}"
WIFI_2G_WIDTH="${WIFI_2G_WIDTH:-$(pick WIFI_2G_WIDTH)}"
WIFI_5G_WIDTH="${WIFI_5G_WIDTH:-$(pick WIFI_5G_WIDTH)}"
WIFI_SSID_SPLIT="${WIFI_SSID_SPLIT:-$(pick WIFI_SSID_SPLIT)}"

# 内置兜底（防止 wifi.txt 缺失导致空值）
WRT_IP="${WRT_IP:-192.168.10.1}"
WRT_PW="${WRT_PW:-无}"
WRT_NAME="${WRT_NAME:-OWRT}"
WRT_SSID="${WRT_SSID:-OWRT}"
WRT_WORD="${WRT_WORD:-12345678}"
WIFI_ENCRYPTION="${WIFI_ENCRYPTION:-psk-mixed}"
WIFI_COUNTRY="${WIFI_COUNTRY:-CN}"
WIFI_2G_MODE="${WIFI_2G_MODE:-AX}"
WIFI_5G_MODE="${WIFI_5G_MODE:-AX}"
WIFI_2G_WIDTH="${WIFI_2G_WIDTH:-40}"
WIFI_5G_WIDTH="${WIFI_5G_WIDTH:-160}"
WIFI_SSID_SPLIT="${WIFI_SSID_SPLIT:-false}"

# 频宽 -> htmode（AX=HE / BE=EHT）；本脚本仅用于日志与兜底展示
case "$WIFI_2G_MODE" in
	BE) WIFI_2G_HTMODE="EHT${WIFI_2G_WIDTH}" ;;
	*)  WIFI_2G_HTMODE="HE${WIFI_2G_WIDTH}" ;;
esac
case "$WIFI_5G_MODE" in
	BE) WIFI_5G_HTMODE="EHT${WIFI_5G_WIDTH}" ;;
	*)  WIFI_5G_HTMODE="HE${WIFI_5G_WIDTH}" ;;
esac

# 按频段拆分 SSID 名
if [ "$WIFI_SSID_SPLIT" = "true" ]; then
	SSID_2G="${WRT_SSID}-2.4G"
	SSID_5G="${WRT_SSID}-5G"
else
	SSID_2G="$WRT_SSID"
	SSID_5G="$WRT_SSID"
fi

# 回写 GITHUB_ENV，供 Release 展示实际生效值
if [ -n "${GITHUB_ENV:-}" ]; then
	{
		echo "WRT_IP=$WRT_IP"
		echo "WRT_PW=$WRT_PW"
		echo "WRT_NAME=$WRT_NAME"
		echo "WRT_SSID=$WRT_SSID"
		echo "WRT_WORD=$WRT_WORD"
		echo "WRT_SSID_2G=$SSID_2G"
		echo "WRT_SSID_5G=$SSID_5G"
	} >> "$GITHUB_ENV"
fi

echo "解析结果：设备=$DEVICE_KEY IP=$WRT_IP 主机=$WRT_NAME SSID(2.4G)=$SSID_2G SSID(5G)=$SSID_5G 加密=$WIFI_ENCRYPTION 国家=$WIFI_COUNTRY"

# ============================================================
# 2. 通用修改（主题 / IP / 主机名 / 时区）
# ============================================================
#移除luci-app-attendedsysupgrade
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 | xargs -0 -r sed -i "/attendedsysupgrade/d"
#修改默认主题
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 | xargs -0 -r sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g"
#修改immortalwrt.lan关联IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -print0 | xargs -0 -r sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g"
#添加编译日期标识
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -print0 | xargs -0 -r sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g"

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"
#修改默认时区
sed -i "s/timezone='.*'/timezone='CST-8'/g" "$CFG_FILE"
sed -i "s/zonename='.*'/zonename='Asia\/Shanghai'/g" "$CFG_FILE"

# ============================================================
# 3. 无线默认值：按频段注入 board.d（开源 mac80211 方案）
#    mac80211.uc 从 board.json 的 wlan.defaults.ssids 读取，
#    因此这里用 ucidef_set_wireless 写入 2g/5g 两条独立默认值。
#    仅对存在无线模板的设备生效；无 WiFi 设备自动跳过。
# ============================================================
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
BOARD_D_DIR="./target/linux/mediatek/filogic/base-files/etc/board.d"

if [ -f "$WIFI_UC" ] && [ -d "$BOARD_D_DIR" ]; then
	# 选择本机型对应的 board.d 脚本：
	# 优先匹配文件名含设备键小写的脚本，否则追加到 02_network（通用入口）
	BOARD_SCRIPT=""
	key_lc=$(echo "$DEVICE_KEY" | tr '[:upper:]' '[:lower:]')
	for f in "$BOARD_D_DIR"/*; do
		[ -f "$f" ] || continue
		base=$(basename "$f" | tr '[:upper:]' '[:lower:]')
		if [[ "$base" == *"$key_lc"* ]]; then
			BOARD_SCRIPT="$f"
			break
		fi
	done
	[ -z "$BOARD_SCRIPT" ] && BOARD_SCRIPT="$BOARD_D_DIR/02_network"

	if [ -f "$BOARD_SCRIPT" ]; then
		echo "向 board.d 注入无线默认值：$BOARD_SCRIPT"
		cat >> "$BOARD_SCRIPT" <<EOF

# ==== 本仓库注入：按频段默认 SSID（mac80211.uc 读取 wlan.defaults.ssids）====
ucidef_set_wireless "2g" "$SSID_2G" "$WIFI_ENCRYPTION" "$WRT_WORD"
ucidef_set_wireless "5g" "$SSID_5G" "$WIFI_ENCRYPTION" "$WRT_WORD"
EOF
	else
		echo "::warning::未找到可注入的 board.d 脚本，无线默认值未写入"
	fi
else
	echo "未检测到无线模板或 board.d（$WIFI_UC / $BOARD_D_DIR），跳过 WiFi 默认值注入（无 WiFi 设备）"
fi

# 兜底：仍对 mac80211.uc 的兜底值做一次替换，保证 board.json 缺失时不会出现 ImmortalWrt 字样
if [ -f "$WIFI_UC" ]; then
	sed -i "s/\"ImmortalWrt\"/\"$SSID_2G\"/g" "$WIFI_UC"
fi

# ============================================================
# 4. 主题 / 语言 / 私有扩展 / 手动插件
# ============================================================
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat "$GITHUB_WORKSPACE/Config/PRIVATE.txt" >> ./.config
fi

if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

# ============================================================
# 5. 高通平台无 WiFi 调整（保留原逻辑）
# ============================================================
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	if [[ "$WRT_WIFI" == "WIFI-NO" ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

# ============================================================
# 6. Rust 编译修复（保留原逻辑）
# ============================================================
FEEDS_PACKAGES="./feeds/packages"
RUST_FILE="$(find "$FEEDS_PACKAGES" -maxdepth 3 -type f -wholename '*/rust/Makefile' -print -quit 2>/dev/null)"
if [ -f "$RUST_FILE" ]; then
	echo " "
	if sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"; then
		echo "rust has been fixed!"
	else
		echo "rust fix failed; continuing!"
	fi
fi
