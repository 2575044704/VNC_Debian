#!/bin/bash
# 适用于Ubuntu
# Ubuntu容器环境VNC安装脚本 - 整合包版本（带桌面启动器和壁纸）
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[信息]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[警告]${NC} $1"
}

# 检查壁纸文件是否存在
if [ -f "./desktop.png" ]; then
    info "检测到壁纸文件，将设置为桌面背景"
    WALLPAPER_FOUND=true
else
    warn "未找到壁纸文件 (./desktop.png)，将使用默认背景"
    WALLPAPER_FOUND=false
fi

# 更新系统
info "正在更新系统包..."
apt update

# 安装X环境和轻量级窗口管理器
info "安装VNC和窗口环境..."
apt install -y --no-install-recommends xvfb x11vnc xterm jwm menu net-tools procps psmisc xfonts-base xauth
apt install -y xfce4-terminal

# 安装浏览器和文件管理器
info "安装Firefox和文件管理器..."
apt install -y firefox pcmanfm lxpanel

# 清理旧进程
info "清理旧进程..."
pkill Xvfb || true
pkill x11vnc || true
pkill jwm || true
pkill lxpanel || true
pkill pcmanfm || true

# 设置VNC密码为123456
info "设置VNC密码为123456..."
mkdir -p /root/.vnc
x11vnc -storepasswd 123456 /root/.vnc/passwd

# 创建壁纸目录并复制壁纸
if [ "$WALLPAPER_FOUND" = true ]; then
    mkdir -p /usr/share/backgrounds
    cp ./desktop.png /usr/share/backgrounds/
    info "已复制壁纸到系统目录"
fi

# 配置XTerm支持Ctrl+V粘贴
info "配置XTerm支持Ctrl+V粘贴..."
cat > /root/.Xresources << 'EOF'
! 允许XTerm使用Ctrl+V粘贴
XTerm*VT100.translations: #override \
    Ctrl <Key>v: insert-selection(CLIPBOARD) \n\
    Ctrl <Key>c: copy-selection(CLIPBOARD)
EOF

# 创建更舒适的桌面环境配置
info "配置桌面环境..."
mkdir -p /root/.jwmrc.d
mkdir -p /root/.config/lxpanel/default/panels
mkdir -p /root/.config/pcmanfm/default

# 创建PCManFM桌面配置
cat > /root/.config/pcmanfm/default/desktop-items-0.conf << EOF
[*]
wallpaper_mode=stretch
wallpaper_common=1
$(if [ "$WALLPAPER_FOUND" = true ]; then echo "wallpaper=/usr/share/backgrounds/desktop.png"; else echo "wallpaper_common=0"; fi)
desktop_bg=#4464a3
desktop_fg=#ffffff
desktop_shadow=#000000
desktop_font=Sans 10
show_wm_menu=0
sort=mtime;ascending;
show_documents=1
show_trash=1
show_mounts=1
EOF

# 创建PCManFM一般配置
cat > /root/.config/pcmanfm/default/pcmanfm.conf << 'EOF'
[config]
bm_open_method=0

[volume]
mount_on_startup=1
mount_removable=1
autorun=1

[ui]
always_show_tabs=0
max_tab_chars=32
win_width=640
win_height=480
splitter_pos=150
media_in_new_tab=0
desktop_folder_new_win=0
change_tab_on_drop=1
close_on_unmount=1
focus_previous=0
side_pane_mode=places
view_mode=icon
show_hidden=0
sort=name;ascending;
columns=name:200;desc:127;size:62;mtime;
toolbar=newtab;navigation;home;
show_statusbar=1
pathbar_mode_buttons=0
EOF

# 创建桌面图标目录
mkdir -p /root/Desktop

# 创建Firefox桌面图标
cat > /root/Desktop/firefox.desktop << 'EOF'
[Desktop Entry]
Name=Firefox
Comment=Web Browser
Exec=firefox
Icon=firefox
Type=Application
Terminal=false
EOF

# 创建终端桌面图标
cat > /root/Desktop/terminal.desktop << 'EOF'
[Desktop Entry]
Name=Terminal
Comment=Terminal Emulator
Exec=xterm
Icon=terminal
Type=Application
Terminal=false
EOF

# 创建文件管理器桌面图标
cat > /root/Desktop/filemanager.desktop << 'EOF'
[Desktop Entry]
Name=File Manager
Comment=Browse Files
Exec=pcmanfm
Icon=system-file-manager
Type=Application
Terminal=false
EOF

# 创建XFCE终端桌面图标
cat > /root/Desktop/xfce-terminal.desktop << 'EOF'
[Desktop Entry]
Name=终端
Comment=更好的终端模拟器
Exec=xfce4-terminal
Icon=utilities-terminal
Type=Application
Terminal=false
EOF

# 设置桌面图标可执行权限
chmod +x /root/Desktop/*.desktop

# 将桌面图标复制到应用目录，以便LXPanel等程序能找到它们
info "为面板创建应用程序启动器..."
mkdir -p /root/.local/share/applications
cp /root/Desktop/*.desktop /root/.local/share/applications/

# 创建JWM配置文件
cat > /root/.jwmrc << EOF
<?xml version="1.0"?>
<JWM>
    <!-- 基本设置 -->
    <RootMenu height="25" onroot="12">
        <Program icon="terminal" label="终端">xterm</Program>
        <Program icon="web-browser" label="Firefox">firefox</Program>
        <Program icon="system-file-manager" label="文件管理器">pcmanfm</Program>
        <Separator/>
        <Restart label="重启窗口管理器"/>
        <Exit label="退出" confirm="true"/>
    </RootMenu>

    <!-- 任务栏 -->
    <Tray x="0" y="0" height="30" autohide="off">
        <TrayButton icon="jwm-blue" label="应用菜单">root:1</TrayButton>
        <Spacer width="2"/>
        <TaskList maxwidth="250"/>
        <Dock/>
        <Clock format="%H:%M">
            <Button mask="123">exec:xclock</Button>
        </Clock>
    </Tray>

    <!-- 视觉样式 -->
    <WindowStyle>
        <Font>Sans-10</Font>
        <Width>4</Width>
        <Height>20</Height>
        <Corner>4</Corner>
        <Active>
            <Text>white</Text>
            <Title>#4C7CBD</Title>
            <Outline>black</Outline>
        </Active>
        <Inactive>
            <Text>#DCDCDC</Text>
            <Title>#888888</Title>
            <Outline>black</Outline>
        </Inactive>
    </WindowStyle>

    <!-- 桌面配置 -->
    <Desktops width="3" height="1">
        $(if [ "$WALLPAPER_FOUND" = true ]; then echo "<Background type=\"image\">/usr/share/backgrounds/desktop.png</Background>"; else echo "<Background type=\"solid\">#4464a3</Background>"; fi)
    </Desktops>

    <!-- 行为设置 -->
    <FocusModel>click</FocusModel>
    <SnapMode distance="10">border</SnapMode>
    <MoveMode>opaque</MoveMode>
    <ResizeMode>opaque</ResizeMode>
    
    <!-- 自动启动面板和桌面管理器 -->
    <StartupCommand>lxpanel</StartupCommand>
    <StartupCommand>pcmanfm --desktop</StartupCommand>
</JWM>
EOF

# 创建LXPanel配置
mkdir -p /root/.config/lxpanel/default/panels
cat > /root/.config/lxpanel/default/panels/panel << 'EOF'
# lxpanel <profile> config file
# 自动生成的文件，请勿手动修改

Global {
    edge=bottom
    allign=left
    margin=0
    widthtype=percent
    width=100
    height=30
    transparent=0
    tintcolor=#000000
    alpha=0
    autohide=0
    heightwhenhidden=2
    setdocktype=1
    setpartialstrut=1
    usefontcolor=0
    fontsize=10
    fontcolor=#ffffff
    usefontsize=0
    background=1
    backgroundfile=/usr/share/lxpanel/images/background.png
    iconsize=24
}

Plugin {
    type=menu
    Config {
        image=/usr/share/lxpanel/images/my-computer.png
        system {
        }
        separator {
        }
        item {
            image=gnome-run
            command=run
        }
        separator {
        }
        item {
            image=gnome-logout
            command=logout
        }
    }
}

Plugin {
    type=launchbar
    Config {
        Button {
            id=firefox.desktop
        }
        Button {
            id=xfce-terminal.desktop
        }
        Button {
            id=filemanager.desktop
        }
    }
}

Plugin {
    type=space
    Config {
        Size=4
    }
}

Plugin {
    type=taskbar
    expand=1
    Config {
        tooltips=1
        IconsOnly=0
        ShowAllDesks=0
        UseMouseWheel=1
        UseUrgencyHint=1
        FlatButton=0
        MaxTaskWidth=150
        spacing=1
        GroupedTasks=0
    }
}

Plugin {
    type=tray
    Config {
    }
}

Plugin {
    type=dclock
    Config {
        ClockFmt=%R
        TooltipFmt=%A %x
        BoldFont=0
        IconOnly=0
        CenterText=0
    }
}
EOF

# 创建启动脚本
info "创建启动脚本..."
cat > /root/start-vnc.sh << 'EOF'
#!/bin/bash
export DISPLAY=:1
Xvfb :1 -screen 0 1400x1000x16 &
sleep 2
# 加载X资源以支持Ctrl+V粘贴
xrdb -merge /root/.Xresources
pcmanfm --desktop &
lxpanel &
jwm &
x11vnc -display :1 -rfbauth /root/.vnc/passwd -forever -shared -bg -rfbport 5901 -xkb -noxrecord -noxfixes -noxdamage -permitfiletransfer
EOF

chmod +x /root/start-vnc.sh

info "安装成功！如果需要启动VNC服务，请执行: /root/start-vnc.sh"
