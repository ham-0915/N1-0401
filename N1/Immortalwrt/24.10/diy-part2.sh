#!/bin/bash
set -e  # 任何命令失败立即退出，防止静默跳过错误

# 1. 基础环境设置 (IP与主机名)
sed -i 's/192.168.1.1/192.168.123.2/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate

# 2. 强制升级 Golang 1.26 (编译 xray-core 26.x / sing-box 等必须)
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 3. 清理 feeds 内置的、版本落后或与自定义包冲突的插件及核心包
#    注意：PKGS 只填包本身名称，循环会自动拼 luci-app- 前缀，勿重复填
PKGS="xray-core v2ray-geodata sing-box chinadns-ng dns2socks hysteria ipt2socks microsocks \
naiveproxy shadowsocks-libev shadowsocks-rust shadowsocksr-libev simple-obfs tcping \
trojan-plus tuic-client v2ray-plugin xray-plugin geoview shadow-tls mosdns"
for pkg in $PKGS; do
    rm -rf feeds/packages/net/$pkg
    rm -rf feeds/luci/applications/luci-app-$pkg
done

# 单独清理 feeds 内置的 luci 前端（包名与上面规律不一致的）
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf feeds/luci/applications/luci-app-ssr-plus
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-nikki
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-openlist
rm -rf feeds/luci/applications/luci-app-openlist2

# 4. 克隆自定义插件包
# helloworld (ssr-plus)：只保留 luci-app-ssr-plus 及其必要依赖
# shadowsocksr-libev 由 passwall-packages 提供，其余与 passwall-packages 重叠的核心包全部删除
git clone --depth=1 https://github.com/fw876/helloworld package/ssr-plus
rm -rf package/ssr-plus/xray-core          # passwall-packages 提供
rm -rf package/ssr-plus/v2ray-geodata      # passwall-packages 提供
rm -rf package/ssr-plus/v2ray-plugin       # passwall-packages 提供
rm -rf package/ssr-plus/xray-plugin        # passwall-packages 提供
rm -rf package/ssr-plus/simple-obfs        # passwall-packages 提供
rm -rf package/ssr-plus/sing-box           # passwall-packages 提供
rm -rf package/ssr-plus/mosdns             # 由下方 sbwml/luci-app-mosdns 提供，避免冲突
# 注意：package/ssr-plus/shadowsocksr-libev 已在上方 git clone 时不存在（helloworld 本身不含）
# luci-app-ssr-plus 依赖的 shadowsocksr-libev-ssr-* 由 passwall-packages 提供，勿删！

# passwall 系列
# 注意：不删除 passwall-packages 里的 shadowsocksr-libev！
# luci-app-ssr-plus 依赖其提供的 shadowsocksr-libev-ssr-check/local/redir/server 四个子包
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/passwall-packages
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall2.git package/passwall2
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall.git package/passwall

# 其他插件
git clone --depth=1 https://github.com/ophub/luci-app-amlogic package/amlogic
git clone --depth=1 https://github.com/gdy666/luci-app-lucky.git package/lucky
git clone --depth=1 https://github.com/sbwml/luci-app-mosdns -b v5 package/mosdns
git clone --depth=1 https://github.com/sbwml/luci-app-openlist2 package/openlist2
git clone --depth=1 https://github.com/nikkinikki-org/OpenWrt-nikki package/nikki
git clone --depth=1 https://github.com/vernesong/OpenClash package/openclash

# 5. 修正 luci-compat 中两处错误翻译
sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm


# 6. 修复nikki数据库下载失败的问题
echo ">>> Updating GeoSite.dat for Nikki..."

# 1. 自动定位 nikki 路径 (防止不同仓库路径不同，如 feeds/luci/applications/... 或 package/...)
NIKKI_DIR=$(find package -name nikki -type d | head -n 1)

if [ -n "$NIKKI_DIR" ]; then
    # 2. 定义目标运行目录
    GEO_DIR="$NIKKI_DIR/files/etc/nikki/run"
    mkdir -p "$GEO_DIR"

    # 3. 下载并直接命名为 GeoSite.dat
    # 使用 -nv (non-verbose) 保持日志整洁，-t 3 重试
    wget -t 3 -nv -O "$GEO_DIR/GeoSite.dat" "https://gh-proxy.org/https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat"

    # 4. 检查文件大小（通常 geosite.dat 应该 > 1MB）
    if [ -s "$GEO_DIR/GeoSite.dat" ]; then
        chmod 644 "$GEO_DIR/GeoSite.dat"
        echo ">>> GeoSite.dat 已成功下载到 $GEO_DIR"
    else
        echo ">>> [!] 警告: GeoSite.dat 下载失败，将保留源码版本。"
        rm -f "$GEO_DIR/GeoSite.dat"
    fi
else
    echo ">>> [!] 错误: 未能在源码中找到 nikki 文件夹，请检查 feeds 是否包含该插件。"
fi

