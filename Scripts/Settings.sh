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

# 提取设备键：取 WRT_CONFIG 第一个横杠前的内容，去除非字母数字，转大写
# 比如 "TR3000-immortalwrt" -> "TR3000"
DEVICE_KEY=$(echo "${WRT_CONFIG%%-*}" | tr -cd '[:alnum:]' | tr '[:lower:]' '[:upper:]')
echo "设备键: $DEVICE_KEY"

# 定义 pick 函数：用于按优先级取出配置值
pick() {
	local suffix=$1
	local specific="${DEVICE_KEY}_${suffix}"
	if [ -n "${!specific:-}" ]; then
		echo "${!specific}"
	else
		echo "${!suffix:-}"
	fi
}

# 应用配置优先级
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

# 最后防线：防止 wifi.txt 缺失导致变量全空。
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
WIFI_SSID_SPLIT="${WIFI_SSID_SPLIT:-false}"

# 将频宽转为 htmode 字符串
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

# 针对 MTK 闭源驱动的特殊处理（开源驱动不受影响）
WIFI_ENCRYPTION_UCI="${WIFI_ENCRYPTION}"
MTWIFI_SH="./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"
[ -f "$MTWIFI_SH" ] && WIFI_ENCRYPTION_UCI="${WIFI_ENCRYPTION_UCI}+ccmp"

# 回写 GITHUB_ENV
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
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 | xargs -0 -r sed -i "/attendedsysupgrade/d"
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 | xargs -0 -r sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g"
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -print0 | xargs -0 -r sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g"

# 移除了你原来追加的编译日期标识，如果你需要可以恢复：
# find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -print0 | xargs -0 -r sed -i "s/(\(luciversion || ''\))/(\1) + (' -$WRT_DATE')/g"

CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"
sed -i "s/timezone='GMT0'/timezone='CST-8'/g" "$CFG_FILE"
sed -i "s|zonename='UTC'|zonename='Asia/Shanghai'|g" "$CFG_FILE"

# ============================================================
# 3. 无线默认值注入（修改底层源码中的默认字眼）
# ============================================================
WIFI_SH=$(find ./target/linux/mediatek/filogic/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"

if [ -f "$MTWIFI_SH" ]; then
	echo "检测到 MTK 闭源驱动栈，修改 mtwifi.sh..."
	sed -i "s/ImmortalWrt-[[:alnum:].-]*/$WRT_SSID/g; s/encryption=none/encryption=$WIFI_ENCRYPTION_UCI/g" "$MTWIFI_SH"
	sed -i "/set wireless.default_\${dev}.key=/d" "$MTWIFI_SH"
	sed -i "/set wireless.default_\${dev}.encryption=/a\\					set wireless.default_\${dev}.key='$WRT_WORD'" "$MTWIFI_SH"
elif [ -f "$WIFI_SH" ]; then
	echo "检测到老式 set-wireless.sh，修改默认值..."
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	echo "检测到主线开源驱动栈，修改源码兜底值..."
	# 这里只改兜底名称，确保如果 board.json 缺失，名字也不会是 ImmortalWrt。
	# 真正的 2.4G/5G 独立命名，交由下方的 uci-defaults 脚本在开机时完成。
	sed -i "s/\"ImmortalWrt\"/\"$SSID_2G\"/g" "$WIFI_UC"
fi

# ============================================================
# 4. uci-defaults 开机兜底脚本（核心修复区）
#    放弃依赖 board.d 注入，直接在首次开机时遍历接口，按频段改写。
# ============================================================
WIFI_DEFAULTS_DIR="./files/etc/uci-defaults"
mkdir -p "$WIFI_DEFAULTS_DIR"

# 注意 heredoc 里的 "\$"：防止变量在编译时被展开，保留到设备开机时执行。
cat > "$WIFI_DEFAULTS_DIR/10-wifi-defaults" <<EOF
#!/bin/sh
# 出厂默认无线参数：构建时由 Settings.sh 生成
WIFI_SSID_2G='${SSID_2G}'
WIFI_SSID_5G='${SSID_5G}'
WIFI_KEY='${WRT_WORD}'
WIFI_ENCRYPTION='$WIFI_ENCRYPTION_UCI'
WIFI_2G_WIDTH='$WIFI_2G_HTMODE'
WIFI_5G_WIDTH='$WIFI_5G_HTMODE'
WIFI_COUNTRY='${WIFI_COUNTRY}'

[ -f /etc/config/wireless ] || exit 0

# 1. 遍历所有 radio，设置频宽和国家码
for radio in radio0 radio1 radio2; do
	band="\$(uci get wireless.\$radio.band 2>/dev/null)"
	case "\$band" in
		2g) uci -q set wireless.\$radio.htmode="\$WIFI_2G_WIDTH" ;;
		5g) uci -q set wireless.\$radio.htmode="\$WIFI_5G_WIDTH" ;;
	esac
	uci -q set wireless.\$radio.country="\$WIFI_COUNTRY"
done

# 2. 使用 config_foreach 遍历所有 wifi-iface 接口，按绑定的 radio 频段分配 SSID
set_ssid_by_band() {
	local cfg="\$1"
	local dev
	config_get dev "\$cfg" device
	[ -n "\$dev" ] || return

	local band
	config_get band "\$dev" band

	case "\$band" in
		2g) uci -q set wireless.\$cfg.ssid="\$WIFI_SSID_2G" ;;
		5g) uci -q set wireless.\$cfg.ssid="\$WIFI_SSID_5G" ;;
		*)  uci -q set wireless.\$cfg.ssid="\$WIFI_SSID_2G" ;; # 未知频段默认套 2.4G
	esac
	uci -q set wireless.\$cfg.encryption="\$WIFI_ENCRYPTION"
	uci -q set wireless.\$cfg.key="\$WIFI_KEY"
}
config_load wireless
config_foreach set_ssid_by_band wifi-iface

uci -q commit wireless 2>/dev/null
exit 0
EOF
chmod +x "$WIFI_DEFAULTS_DIR/10-wifi-defaults"

# ============================================================
# 5. 主题 / 语言 / 配置追加
# ============================================================
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

# 动态裁剪 kmod-nft-fullcone
if ! grep -rqs --include=Makefile "KernelPackage/nft-fullcone" ./package/; then
	sed -i "/^CONFIG_PACKAGE_kmod-nft-fullcone=/d" ./.config
fi

if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	cat "$GITHUB_WORKSPACE/Config/PRIVATE.txt" >> ./.config
fi

if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

# ============================================================
# 6. 高通平台无 WiFi 调整 & Rust 修复
# ============================================================
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	if [[ "$WRT_WIFI" == "WIFI-NO" ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
	fi
fi

RUST_FILE="$(find ./feeds/packages -maxdepth 3 -type f -wholename '*/rust/Makefile' -print -quit 2>/dev/null)"
if [ -f "$RUST_FILE" ]; then
	sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"
fi
