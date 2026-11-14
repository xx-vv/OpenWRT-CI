#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# ============================================================
# 1. 读取机型默认值 (Config/wifi.txt)
# ============================================================
WIFI_CFG="${GITHUB_WORKSPACE:-.}/Config/wifi.txt"
if [ -f "$WIFI_CFG" ]; then
	# shellcheck source=/dev/null
	source "$WIFI_CFG"
fi

# 提取设备键：去掉最后一个 -发行版 后缀，去非字母数字，转大写
# 例：TR3000-immortalwrt -> TR3000；GL-MT3600BE-immortalwrt -> GLMT3600BE
DEVICE_KEY=$(printf '%s' "${WRT_CONFIG%-*}" | tr -cd '[:alnum:]' | tr '[:lower:]' '[:upper:]')
echo "设备键: $DEVICE_KEY"

# 按优先级取出配置值
pick() {
	local suffix=$1
	local specific="${DEVICE_KEY}_${suffix}"
	if [ -n "${!specific:-}" ]; then
		echo "${!specific}"
	else
		echo "${!suffix:-}"
	fi
}

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

# 最后防线：防止 wifi.txt 缺失导致变量全空
WRT_IP="${WRT_IP:-192.168.10.1}"
WRT_PW="${WRT_PW:-无}"
WRT_NAME="${WRT_NAME:-OWRT}"
WRT_SSID="${WRT_SSID:-OWRT}"
WRT_WORD="${WRT_WORD:-12345678}"
WIFI_ENCRYPTION="${WIFI_ENCRYPTION:-sae-mixed}"
WIFI_COUNTRY="${WIFI_COUNTRY:-CN}"
WIFI_2G_MODE="${WIFI_2G_MODE:-AX}"
WIFI_5G_MODE="${WIFI_5G_MODE:-AX}"
WIFI_2G_WIDTH="${WIFI_2G_WIDTH:-40}"
WIFI_5G_WIDTH="${WIFI_5G_WIDTH:-160}"

# 将频宽转为 htmode 字符串
case "$WIFI_2G_MODE" in
	BE) WIFI_2G_HTMODE="EHT${WIFI_2G_WIDTH}" ;;
	*)  WIFI_2G_HTMODE="HE${WIFI_2G_WIDTH}" ;;
esac
case "$WIFI_5G_MODE" in
	BE) WIFI_5G_HTMODE="EHT${WIFI_5G_WIDTH}" ;;
	*)  WIFI_5G_HTMODE="HE${WIFI_5G_WIDTH}" ;;
esac

# 针对 MTK 闭源驱动的特殊处理
MTWIFI_SH="./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"
WIFI_ENCRYPTION_UCI="${WIFI_ENCRYPTION}"
[ -f "$MTWIFI_SH" ] && WIFI_ENCRYPTION_UCI="${WIFI_ENCRYPTION_UCI}+ccmp"

# 回写 GITHUB_ENV
if [ -n "${GITHUB_ENV:-}" ]; then
	{
		echo "WRT_IP=$WRT_IP"
		echo "WRT_PW=$WRT_PW"
		echo "WRT_NAME=$WRT_NAME"
		echo "WRT_SSID=$WRT_SSID"
		echo "WRT_WORD=$WRT_WORD"
	} >> "$GITHUB_ENV"
fi
echo "解析结果：设备=$DEVICE_KEY IP=$WRT_IP 主机=$WRT_NAME SSID=$WRT_SSID 加密=$WIFI_ENCRYPTION 国家=$WIFI_COUNTRY"

# ============================================================
# 2. 通用修改（主题 / IP / 主机名 / 时区）
# ============================================================
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 2>/dev/null | xargs -0 -r sed -i "/attendedsysupgrade/d"
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 2>/dev/null | xargs -0 -r sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g"
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -print0 2>/dev/null | xargs -0 -r sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g"

CFG_FILE="./package/base-files/files/bin/config_generate"
if [ -f "$CFG_FILE" ]; then
	sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
	sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"
	sed -i "s/timezone='GMT0'/timezone='CST-8'/g" "$CFG_FILE"
	sed -i "s|zonename='UTC'|zonename='Asia/Shanghai'|g" "$CFG_FILE"
else
	echo "警告：未找到 $CFG_FILE，跳过 IP/主机名/时区修改"
fi

# ============================================================
# 3. 无线默认值注入（按驱动栈分流）
#
# 刻意不写 router-tool.defaults：Router Tool 的 wireless defaults 固定
# country='US'、encryption='psk2+ccmp'、channel/htmode，与我们的
# CN / sae-mixed 冲突。这里让首次生成的 wireless 直接不是 OWRT，
# Router Tool 的 untouched-AP 判定必然失败，会 mark_done 跳过，
# 不会覆盖我们的值。
# ============================================================
WIFI_SH=$(find ./target/linux/mediatek/filogic/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null | head -n1)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"

if [ -f "$MTWIFI_SH" ]; then
	echo "检测到 MTK 闭源驱动栈，修改 mtwifi.sh..."
	sed -i "s/ImmortalWrt-[[:alnum:].-]*/$WRT_SSID/g; s/encryption=none/encryption=$WIFI_ENCRYPTION_UCI/g" "$MTWIFI_SH"
	sed -i "/set wireless.default_\${dev}.key=/d" "$MTWIFI_SH"
	sed -i "/set wireless.default_\${dev}.encryption=/a\\					set wireless.default_\${dev}.key='$WRT_WORD'" "$MTWIFI_SH"
elif [ -n "$WIFI_SH" ] && [ -f "$WIFI_SH" ]; then
	echo "检测到老式 set-wireless.sh，修改默认值..."
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" "$WIFI_SH"
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" "$WIFI_SH"
elif [ -f "$WIFI_UC" ]; then
	echo "检测到主线开源驱动栈，修改 mac80211.uc 默认字眼..."
	if grep -q "'ImmortalWrt'" "$WIFI_UC"; then
		sed -i "s/'ImmortalWrt'/'$WRT_SSID'/g" "$WIFI_UC"
	elif grep -q '"ImmortalWrt"' "$WIFI_UC"; then
		sed -i "s/\"ImmortalWrt\"/\"$WRT_SSID\"/g" "$WIFI_UC"
	else
		echo "警告：mac80211.uc 中未找到预期默认 SSID，跳过"
	fi
else
	echo "警告：未检测到任何无线驱动栈，跳过无线默认值注入"
fi

# ============================================================
# 4. uci-defaults 开机兜底脚本
#    负责 htmode / country / encryption / key 的最终写入。
#    ssid 已在第 3 节改为非 OWRT，Router Tool 会 mark_done 跳过。
#    DONE_FILE 防 sysupgrade 保留配置时重跑覆盖用户改动。
# ============================================================
WIFI_DEFAULTS_DIR="./files/etc/uci-defaults"
mkdir -p "$WIFI_DEFAULTS_DIR"
cat > "$WIFI_DEFAULTS_DIR/10-wifi-defaults" <<EOF
#!/bin/sh
. /lib/functions.sh

WIFI_SSID='${WRT_SSID}'
WIFI_KEY='${WRT_WORD}'
WIFI_ENCRYPTION='${WIFI_ENCRYPTION_UCI}'
WIFI_2G_HTMODE='${WIFI_2G_HTMODE}'
WIFI_5G_HTMODE='${WIFI_5G_HTMODE}'
WIFI_COUNTRY='${WIFI_COUNTRY}'

DONE_FILE=/etc/config/wireless-build-defaults.done
[ -f "\$DONE_FILE" ] && exit 0
[ -f /etc/config/wireless ] || exit 0

handle_radio() {
	local radio="\$1" band
	config_get band "\$radio" band
	case "\$band" in
		2g) uci -q set wireless."\$radio".htmode="\$WIFI_2G_HTMODE" ;;
		5g) uci -q set wireless."\$radio".htmode="\$WIFI_5G_HTMODE" ;;
	esac
	uci -q set wireless."\$radio".country="\$WIFI_COUNTRY"
}

handle_iface() {
	local iface="\$1" mode
	config_get mode "\$iface" mode
	# 只处理 AP 接口，避免破坏 STA/mesh/WDS/monitor 配置
	[ "\$mode" = "ap" ] || return 0
	uci -q set wireless."\$iface".ssid="\$WIFI_SSID"
	uci -q set wireless."\$iface".encryption="\$WIFI_ENCRYPTION"
	uci -q set wireless."\$iface".key="\$WIFI_KEY"
}

config_load wireless
config_foreach handle_radio wifi-device
config_foreach handle_iface wifi-iface

if ! uci -q commit wireless; then
	logger -t wifi-defaults "Failed to commit wireless defaults"
	exit 1
fi
touch "\$DONE_FILE"
exit 0
EOF
chmod +x "$WIFI_DEFAULTS_DIR/10-wifi-defaults"

# ============================================================
# 5. 主题 / 语言 / 配置追加
# ============================================================
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config

# 主题配套包名并不统一（aurora → luci-app-aurora-config，vantage →
# luci-app-vantage，argon → luci-app-argon-config）。无脑拼
# luci-app-$WRT_THEME / luci-app-$WRT_THEME-config 会写出不存在的符号，
# defconfig 阶段静默丢弃并让日志变脏；这里精确映射，未知主题不追加。
THEME_PKG=""
case "$WRT_THEME" in
	aurora)  THEME_PKG="luci-app-aurora-config" ;;
	vantage) THEME_PKG="luci-app-vantage" ;;
	argon)   THEME_PKG="luci-app-argon-config" ;;
	*)
		echo "警告：主题 $WRT_THEME 无已知配套包，跳过配套包追加"
		;;
esac
if [ -n "$THEME_PKG" ]; then
	echo "CONFIG_PACKAGE_$THEME_PKG=y" >> ./.config
fi

if ! grep -rqs --include=Makefile "KernelPackage/nft-fullcone" ./package/; then
	sed -i "/^CONFIG_PACKAGE_kmod-nft-fullcone=/d" ./.config
fi

if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	cat "$GITHUB_WORKSPACE/Config/PRIVATE.txt" >> ./.config
fi

if [ -n "${WRT_PACKAGE:-}" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

# ============================================================
# 6. 高通平台无 WiFi 调整 & Rust 修复
# ============================================================
DTS_PATH="./target/linux/qualcommax/dts/"
WRT_TARGET="${WRT_TARGET:-}"
WRT_WIFI="${WRT_WIFI:-}"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	if [[ "$WRT_WIFI" == "WIFI-NO" ]]; then
		find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
	fi
fi

RUST_FILE="$(find ./feeds/packages -maxdepth 3 -type f -wholename '*/rust/Makefile' -print -quit 2>/dev/null)"
if [ -f "$RUST_FILE" ]; then
	sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"
fi
