#!/bin/bash
set -e  # 任何命令失败立即退出，防止静默跳过错误

# 1. 基础配置
sed -i 's/192.168.1.1/192.168.123.2/g' package/base-files/files/bin/config_generate
sed -i 's/ImmortalWrt/OpenWrt/g' package/base-files/files/bin/config_generate

# 2. 修复 apk video 仓库
mkdir -p package/base-files/files/etc/uci-defaults
cat > package/base-files/files/etc/uci-defaults/99-fix-apk-video << 'HOOK'
#!/bin/sh
sed -i '/video/d' /etc/apk/repositories.d/distfeeds.list
exit 0
HOOK

# 3. 升级 Golang 到 26.x
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 4. 彻底清理 feeds 自带的冲突项
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-libev,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,trojan-plus,tuic-client,v2ray-plugin,xray-plugin,geoview,shadow-tls}
rm -rf feeds/luci/applications/luci-app-passwall
rm -rf feeds/luci/applications/luci-app-passwall2
rm -rf feeds/luci/applications/luci-app-mosdns feeds/packages/net/mosdns
rm -rf feeds/packages/net/openlist
rm -rf feeds/luci/applications/luci-app-openlist
rm -rf feeds/luci/applications/luci-app-lucky
rm -rf feeds/luci/applications/luci-app-nikki
rm -rf feeds/luci/applications/luci-app-openclash
rm -rf feeds/luci/applications/luci-app-openlist2

rm -rf feeds/luci/luci-app-mjpg-streamer
rm -rf feeds/packages/onionshare-cli
sed -i '/mjpg-streamer/d' .config 2>/dev/null || true
sed -i '/onionshare/d' .config 2>/dev/null || true


# 5. 克隆 Passwall 2
git clone https://github.com/Openwrt-Passwall/openwrt-passwall-packages.git package/passwall-packages
rm -rf package/passwall-packages/shadowsocksr-libev
git clone https://github.com/Openwrt-Passwall/openwrt-passwall2.git package/passwall2


# 6. 其他插件
git clone https://github.com/ophub/luci-app-amlogic --depth=1 package/amlogic
git clone https://github.com/gdy666/luci-app-lucky.git --depth=1 package/lucky
git clone https://github.com/sbwml/luci-app-mosdns -b v5 --depth=1 package/mosdns
git clone https://github.com/sbwml/luci-app-openlist2 --depth=1 package/openlist2
git clone https://github.com/nikkinikki-org/OpenWrt-nikki --depth=1 package/nikki
git clone https://github.com/vernesong/OpenClash --depth=1 package/openclash


# 7. 修正 25.12 兼容层的按钮翻译
if [ -f feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm ]; then
    sed -i 's/<%:Up%>/<%:Move up%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
    sed -i 's/<%:Down%>/<%:Move down%>/g' feeds/luci/modules/luci-compat/luasrc/view/cbi/tblsection.htm
fi




# 8. 修复nikki数据库下载失败的问题
echo ">>> Preparing GeoSite.dat for Nikki..."
# 自动定位 nikki 路径
NIKKI_DIR=$(find . -name nikki -type d -path "*/luci-app-nikki" -o -path "*/nikki" | head -n 1)

if [ -n "$NIKKI_DIR" ]; then
    GEO_DIR="$NIKKI_DIR/root/etc/nikki/run"
    mkdir -p "$GEO_DIR"
    
    URL_PROXY="https://gh-proxy.org/https://github.com/MetaCubeX/meta-rules-dat/releases/download/latest/geosite.dat"
    URL_FASTLY="https://fastly.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@release/geosite.dat"
    
    echo ">>> 尝试从代理地址下载 (URL1)..."
    if ! wget -t 3 -T 20 -nv -O "$GEO_DIR/GeoSite.dat" "$URL_PROXY"; then
        echo ">>> URL1 下载失败，尝试切换到 Fastly 镜像 (URL2)..."
        wget -t 5 -T 30 -nv -O "$GEO_DIR/GeoSite.dat" "$URL_FASTLY"
    fi
    
    if [ -s "$GEO_DIR/GeoSite.dat" ]; then
        chmod 644 "$GEO_DIR/GeoSite.dat"
        echo ">>> GeoSite.dat 下载并部署成功."
    else
        echo ">>> [!] 警告: 所有下载地址均失效，请检查网络！"
        exit 1  # 强制脚本报错退出，停止编译流程。
    fi
fi
