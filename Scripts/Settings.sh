#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

# ============================================================
# 1. 读取机型默认值 (Config/wifi.txt)
#    逻辑：环境变量(CI传入) > 机型专属配置(如 TR3000_xxx) > 全局配置 > 内置兜底
# ============================================================

# 定义配置文件的绝对路径。如果 GITHUB_WORKSPACE 未定义（本地运行），则用当前目录 "."
WIFI_CFG="${GITHUB_WORKSPACE:-.}/Config/wifi.txt"

# 检查 wifi.txt 是否存在。如果存在，就把它 source 进来，让里面的变量在当前脚本生效
if [ -f "$WIFI_CFG" ]; then
	# shellcheck source=/dev/null
	source "$WIFI_CFG"
fi

# 提取设备键：取 WRT_CONFIG 变量中第一个横杠 "-" 之前的内容（%%-* 表示删掉第一个 - 及其后面的所有内容）
# 比如 "TR3000-immortalwrt" 会变成 "TR3000"
# 然后通过 tr -cd '[:alnum:]' 删除所有非字母和数字的字符
# 最后通过 tr '[:lower:]' '[:upper:]' 把所有小写字母转成大写
DEVICE_KEY=$(echo "${WRT_CONFIG%%-*}" | tr -cd '[:alnum:]' | tr '[:lower:]' '[:upper:]')
# 打印出解析出来的设备键，方便在编译日志里核对是否正确
echo "设备键: $DEVICE_KEY"

# 定义 pick 函数：用于按优先级取出配置值
pick() {
	# $1 是我们要取的后缀名，比如 "LAN_IP"
	local suffix=$1
	# 拼出机型专属变量名，比如 "TR3000_LAN_IP"
	local specific="${DEVICE_KEY}_${suffix}"
	# 判断 ${!specific} (间接引用，即取变量名对应的值) 是否非空
	if [ -n "${!specific:-}" ]; then
		# 如果有专属配置，就输出专属配置
		echo "${!specific}"
	else
		# 如果没有专属配置，就输出全局配置
		echo "${!suffix:-}"
	fi
}

# 下面这一段：${WRT_IP:-...} 的意思是如果外部有传入 WRT_IP(环境变量)，就用外部的；
# 如果外部没传，就执行 pick 函数去 wifi.txt 里找合适的值。
WRT_IP="${WRT_IP:-$(pick LAN_IP)}"                      # 获取 IP
WRT_PW="${WRT_PW:-$(pick LAN_PASSWORD)}"                # 获取密码
WRT_NAME="${WRT_NAME:-$(pick HOST_NAME)}"               # 获取主机名
WRT_SSID="${WRT_SSID:-$(pick WIFI_SSID)}"               # 获取 WiFi 名称前缀
WRT_WORD="${WRT_WORD:-$(pick WIFI_PASSWORD)}"           # 获取 WiFi 密码
WRT_THEME="${WRT_THEME:-aurora}"                        # 获取主题，如果没配则默认 aurora

WIFI_ENCRYPTION="${WIFI_ENCRYPTION:-$(pick WIFI_ENCRYPTION)}"   # 获取加密方式
WIFI_COUNTRY="${WIFI_COUNTRY:-$(pick WIFI_COUNTRY)}"            # 获取国家码
WIFI_2G_MODE="${WIFI_2G_MODE:-$(pick WIFI_2G_MODE)}"            # 获取 2.4G 模式 (AX/BE)
WIFI_5G_MODE="${WIFI_5G_MODE:-$(pick WIFI_5G_MODE)}"            # 获取 5G 模式 (AX/BE)
WIFI_2G_WIDTH="${WIFI_2G_WIDTH:-$(pick WIFI_2G_WIDTH)}"         # 获取 2.4G 频宽
WIFI_5G_WIDTH="${WIFI_5G_WIDTH:-$(pick WIFI_5G_WIDTH)}"         # 获取 5G 频宽
WIFI_SSID_SPLIT="${WIFI_SSID_SPLIT:-$(pick WIFI_SSID_SPLIT)}"   # 获取是否拆分 SSID (true/false)

# 最后防线：防止 wifi.txt 缺失导致变量全空。这里给所有变量强制赋默认值。
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

# 将频宽转为无线驱动需要的 htmode 字符串
# 如果是 BE (WiFi7)，拼上 EHT；如果是 AX (WiFi6)，拼上 HE
case "$WIFI_2G_MODE" in
	BE) WIFI_2G_HTMODE="EHT${WIFI_2G_WIDTH}" ;;
	*)  WIFI_2G_HTMODE="HE${WIFI_2G_WIDTH}" ;;
esac
case "$WIFI_5G_MODE" in
	BE) WIFI_5G_HTMODE="EHT${WIFI_5G_WIDTH}" ;;
	*)  WIFI_5G_HTMODE="HE${WIFI_5G_WIDTH}" ;;
esac

# 判断是否要给 2.4G 和 5G 加上不同的后缀。
# 如果 WIFI_SSID_SPLIT 为 true，则 2.4G 名字叫 "TR3000-2.4G"，5G 叫 "TR3000-5G"
if [ "$WIFI_SSID_SPLIT" = "true" ]; then
	SSID_2G="${WRT_SSID}-2.4G"
	SSID_5G="${WRT_SSID}-5G"
else
	SSID_2G="$WRT_SSID"
	SSID_5G="$WRT_SSID"
fi

# 针对 MTK 闭源驱动栈的特殊处理
# 闭源驱动识别加密方式时，必须在后面加 "+ccmp" 后缀（比如 sae-mixed+ccmp）才能生效
WIFI_ENCRYPTION_UCI="${WIFI_ENCRYPTION}"
MTWIFI_SH="./package/mtk/applications/mtwifi-cfg/files/mtwifi.sh"
# [ -f ... ] 判断文件是否存在，如果存在才执行 && 后面的追加字符串操作
[ -f "$MTWIFI_SH" ] && WIFI_ENCRYPTION_UCI="${WIFI_ENCRYPTION_UCI}+ccmp"

# 回写变量到 GITHUB_ENV。这会让后续的 Github Actions 步骤（比如发布 Release 的页面）能读到这些值。
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
# 在日志里打印解析结果，方便编译失败时排查
echo "解析结果：设备=$DEVICE_KEY IP=$WRT_IP 主机=$WRT_NAME SSID(2.4G)=$SSID_2G SSID(5G)=$SSID_5G 加密=$WIFI_ENCRYPTION 国家=$WIFI_COUNTRY"

# ============================================================
# 2. 通用修改（主题 / IP / 主机名 / 时区）
# ============================================================

# 在 LuCI 的集合里删掉 attendedsysupgrade (强制升级) 相关代码，防止它把固件改回原版
# find ... -print0 | xargs -0 -r 是处理路径中包含空格的文件的正确姿势
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 | xargs -0 -r sed -i "/attendedsysupgrade/d"

# 把默认的 bootstrap 主题替换为我们指定的 WRT_THEME (比如 aurora)
find ./feeds/luci/collections/ -type f -name "Makefile" -print0 | xargs -0 -r sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g"

# 把 LuCI 系统界面里写死的 192.168.x.x 替换成我们的 WRT_IP
find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js" -print0 | xargs -0 -r sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g"

# 在 LuCI 状态页面的版本号旁边，追加编译日期标识（形如 / MARK-DATE）
find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js" -print0 | xargs -0 -r sed -i "s/(\(luciversion || ''\))/(\1) + (' -$WRT_DATE')/g"

# 修改系统底层的默认 IP 地址生成脚本
CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"

# 修改默认的主机名（比如设为 CUDY）
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"

# 修改默认时区，CST-8 即北京时间
sed -i "s/timezone='GMT0'/timezone='CST-8'/g" "$CFG_FILE"

# 修改时区名称。因为 Asia/Shanghai 包含斜杠 "/"，如果用 s///g 会报错，所以这里用 s|||g 替代
sed -i "s|zonename='UTC'|zonename='Asia/Shanghai'|g" "$CFG_FILE"

# ============================================================
# 3. 无线默认值注入（按驱动栈分流）
# ============================================================

# 探测源码里的无线驱动长什么样
WIFI_SH=$(find ./target/linux/mediatek/filogic/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
BOARD_D_DIR="./target/linux/mediatek/filogic/base-files/etc/board.d"

# 情况 A：如果存在 mtwifi.sh，说明用的是 MTK 闭源驱动方案
if [ -f "$MTWIFI_SH" ]; then
	echo "检测到 MTK 闭源驱动栈，修改 mtwifi.sh..."
	# 替换原版的默认名称（ImmortalWrt-xxx），并把 encryption=none 替换为实际的加密方式
	sed -i "s/ImmortalWrt-[[:alnum:].-]*/$WRT_SSID/g; s/encryption=none/encryption=$WIFI_ENCRYPTION_UCI/g" "$MTWIFI_SH"
	# 删掉可能存在的旧密码行，防止冲突
	sed -i "/set wireless.default_\${dev}.key=/d" "$MTWIFI_SH"
	# 在 encryption 那一行的后面（a 命令），追加一行写入我们的密码
	sed -i "/set wireless.default_\${dev}.encryption=/a\\					set wireless.default_\${dev}.key='$WRT_WORD'" "$MTWIFI_SH"

# 情况 B：如果存在老式的 set-wireless.sh，说明用的是旧版 mediatek 官方脚本
elif [ -f "$WIFI_SH" ]; then
	echo "检测到老式 set-wireless.sh，修改默认值..."
	# 替换里面的 BASE_SSID 和 BASE_WORD
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH

# 情况 C：如果存在 mac80211.uc 和 board.d 目录，说明是主线开源驱动栈（你当前的情况）
elif [ -f "$WIFI_UC" ] && [ -d "$BOARD_D_DIR" ]; then
	echo "检测到主线开源驱动栈，通过 board.d 注入分频段默认值..."
	BOARD_SCRIPT=""
	# 把设备键转成小写，用于后面模糊匹配文件名
	key_lc=$(echo "$DEVICE_KEY" | tr '[:upper:]' '[:lower:]')
	# 遍历 board.d 目录，看看有没有包含我们设备名的专属脚本（比如 02_network_tr3000）
	for f in "$BOARD_D_DIR"/*; do
		[ -f "$f" ] || continue
		base=$(basename "$f" | tr '[:upper:]' '[:lower:]')
		if [[ "$base" == *"$key_lc"* ]]; then
			BOARD_SCRIPT="$f"
			break
		fi
	done
	# 如果没找到专属的，就把通用的 02_network 作为注入目标
	[ -z "$BOARD_SCRIPT" ] && BOARD_SCRIPT="$BOARD_D_DIR/02_network"

	# 找到了目标脚本就开始注入
	if [ -f "$BOARD_SCRIPT" ]; then
		echo "向 board.d 注入无线默认值：$BOARD_SCRIPT"
		# 用 heredoc (<<EOF) 把下面几行追加到脚本末尾。
		# 这几行代码会在编译时生成 board.json，告诉 mac80211.uc 2.4G 和 5G 分别用什么名字。
		cat >> "$BOARD_SCRIPT" <<EOF

# ==== 本仓库注入：按频段默认 SSID ====
ucidef_set_wireless "2g" "$SSID_2G" "$WIFI_ENCRYPTION" "$WRT_WORD"
ucidef_set_wireless "5g" "$SSID_5G" "$WIFI_ENCRYPTION" "$WRT_WORD"
EOF
	fi
	# 兜底：把 mac80211.uc 里原本写死的 "ImmortalWrt" 也替换掉，防止 board.json 丢失时名字不对
	sed -i "s/\"ImmortalWrt\"/\"$SSID_2G\"/g" "$WIFI_UC"

# 情况 D：什么无线模板都没找到，说明是无 WiFi 的纯有线设备
else
	echo "未检测到无线模板，跳过 WiFi 默认值注入（无 WiFi 设备）"
fi

# ============================================================
# 4. uci-defaults 开机兜底脚本
#    不管前面生成的配置对不对，这个脚本会在设备刷机后第一次开机时执行一次，
#    强制把所有无线的名字、密码、频宽、国家码按频段修正。
# ============================================================
WIFI_DEFAULTS_DIR="./files/etc/uci-defaults"
mkdir -p "$WIFI_DEFAULTS_DIR"
# 注意 heredoc 里的 "\$"：因为外层是 bash 脚本，加反斜杠是为了防止变量在编译时就被展开，
# 而是要保留到开机脚本里去执行。
cat > "$WIFI_DEFAULTS_DIR/10-wifi-defaults" <<EOF
#!/bin/sh
# 由 Settings.sh 在编译时自动生成，写入固件，首次开机时执行
WIFI_SSID_2G='${SSID_2G}'
WIFI_SSID_5G='${SSID_5G}'
WIFI_KEY='${WRT_WORD}'
WIFI_ENCRYPTION='$WIFI_ENCRYPTION_UCI'
WIFI_2G_WIDTH='$WIFI_2G_HTMODE'
WIFI_5G_WIDTH='$WIFI_5G_HTMODE'
WIFI_COUNTRY='${WIFI_COUNTRY}'

# 检查是否生成了 wireless 配置文件，没有则直接退出（说明无无线功能）
[ -f /etc/config/wireless ] || exit 0

# 遍历所有 radio 硬件（一般最多 3 个），设置频宽和国家码
for radio in radio0 radio1 radio2; do
	# 读出这个 radio 的频段（2g 还是 5g）
	band="\$(uci get wireless.\$radio.band 2>/dev/null)"
	# 根据频段设置对应的频宽 (htmode)
	case "\$band" in
		2g) uci -q set wireless.\$radio.htmode="\$WIFI_2G_WIDTH" ;;
		5g) uci -q set wireless.\$radio.htmode="\$WIFI_5G_WIDTH" ;;
	esac
	# 设置国家码
	uci -q set wireless.\$radio.country="\$WIFI_COUNTRY"
done

# 再次遍历所有 radio，找到属于它的接口 (wifi-iface)，分别改 SSID 和密码
for radio in radio0 radio1 radio2; do
	band="\$(uci get wireless.\$radio.band 2>/dev/null)"
	# 用 grep 找出所有绑定在这个 radio 上的 iface 名称
	for iface in \$(uci show wireless | grep "device='\$radio'" | cut -d. -f2); do
		# 根据频段设置不同的名称
		case "\$band" in
			2g) uci -q set wireless.\$iface.ssid="\$WIFI_SSID_2G" ;;
			5g) uci -q set wireless.\$iface.ssid="\$WIFI_SSID_5G" ;;
			*)  uci -q set wireless.\$iface.ssid="\$WIFI_SSID_2G" ;; # 未知频段默认套 2.4G
		esac
		# 统一设置加密和密码
		uci -q set wireless.\$iface.encryption="\$WIFI_ENCRYPTION"
		uci -q set wireless.\$iface.key="\$WIFI_KEY"
	done
done
# 将修改提交保存到配置文件
uci -q commit wireless 2>/dev/null
exit 0
EOF
# 赋予开机脚本执行权限
chmod +x "$WIFI_DEFAULTS_DIR/10-wifi-defaults"

# ============================================================
# 5. 主题 / 语言 / 配置追加
# ============================================================
# 向编译配置文件追加基础包和主题
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

# 动态修补配置：
# 如果源码里根本没有 kmod-nft-fullcone 这个包（新版源码改成了内置实现），
# 就把配置文件里要求编译这个包的选项删掉，否则会编译报错。
if ! grep -rqs --include=Makefile "KernelPackage/nft-fullcone" ./package/; then
	sed -i "/^CONFIG_PACKAGE_kmod-nft-fullcone=/d" ./.config
fi

# 如果存在 PRIVATE.txt（私有配置文件），把它合并进 .config
if [ -n "${GITHUB_WORKSPACE:-}" ] && [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	cat "$GITHUB_WORKSPACE/Config/PRIVATE.txt" >> ./.config
fi

# 如果手动触发编译时输入了额外的插件（WRT_PACKAGE），也追加进去
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

# ============================================================
# 6. 高通平台无 WiFi 调整 & Rust 修复
# ============================================================

# 高通平台专有逻辑：如果是无 WiFi 版本，替换 DTS（设备树）文件
DTS_PATH="./target/linux/qualcommax/dts/"
# 匹配变量名里是否含有 QUALCOMMAX（转大写后）
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	if [[ "$WRT_WIFI" == "WIFI-NO" ]]; then
		# 将所有非 nowifi 的 dtsi 引用替换为 nowifi 版本
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
	fi
fi

# Rust 编译修复：
# 某些 feeds 里的 rust 包会触发拉取完整的 LLVM 源码进行本地编译（耗时 1-2 小时且占用 20G+ 空间），
# 在 CI 里必定超时。这里修改它的 Makefile，关闭 ci-llvm 选项，强制走预编译的 LLVM 分支。
RUST_FILE="$(find ./feeds/packages -maxdepth 3 -type f -wholename '*/rust/Makefile' -print -quit 2>/dev/null)"
if [ -f "$RUST_FILE" ]; then
	sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE"
fi
