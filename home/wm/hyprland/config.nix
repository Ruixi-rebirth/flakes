{ pkgs, ... }:
let
  watermark = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Ruixi-rebirth/someSource/main/watermark/watermark1.png";
    sha256 = "sha256-FUVSKKNv594jaAJGF+m622TkHB+Wwvyewd11WzXbjcQ=";
  };
  grimblast_watermark = pkgs.writeShellScriptBin "grimblast_watermark" ''
        FILE=$(date "+%Y-%m-%d"T"%H:%M:%S").png
    # Get the picture from maim
        grimblast --notify --cursor save area $HOME/Pictures/src.png >> /dev/null 2>&1
    # add shadow, round corner, border and watermark
        convert $HOME/Pictures/src.png \
          \( +clone -alpha extract \
          -draw 'fill black polygon 0,0 0,8 8,0 fill white circle 8,8 8,0' \
          \( +clone -flip \) -compose Multiply -composite \
          \( +clone -flop \) -compose Multiply -composite \
          \) -alpha off -compose CopyOpacity -composite $HOME/Pictures/output.png
    #
        convert $HOME/Pictures/output.png -bordercolor none -border 20 \( +clone -background black -shadow 80x8+15+15 \) \
          +swap -background transparent -layers merge +repage $HOME/Pictures/$FILE
    #
        composite -gravity Southeast "${watermark}" $HOME/Pictures/$FILE $HOME/Pictures/$FILE 
    #
        wl-copy < $HOME/Pictures/$FILE
    #   remove the other pictures
        rm $HOME/Pictures/src.png $HOME/Pictures/output.png
  '';
  myswaylock = pkgs.writeShellScriptBin "myswaylock" ''
    ${pkgs.swaylock-effects}/bin/swaylock  \
           --screenshots \
           --clock \
           --indicator \
           --indicator-radius 100 \
           --indicator-thickness 7 \
           --effect-blur 7x5 \
           --effect-vignette 0.5:0.5 \
           --ring-color 3b4252 \
           --key-hl-color 880033 \
           --line-color 00000000 \
           --inside-color 00000088 \
           --separator-color 00000000 \
           --grace 2 \
           --fade-in 0.3
  '';
  launch_waybar = pkgs.writeShellScriptBin "launch_waybar" ''
    killall .waybar-wrapped
    ${pkgs.waybar}/bin/waybar > /dev/null 2>&1 &
  '';
  suspendScript = pkgs.writeShellScript "suspend-script" ''
    RUNNING_COUNT=$(${pkgs.pipewire}/bin/pw-cli i all | ${pkgs.ripgrep}/bin/rg "state: \"running\"" -c || true)
    if [ -z "$RUNNING_COUNT" ]; then
      RUNNING_COUNT=0
    fi
    if [ $RUNNING_COUNT -le 2 ]; then
      ${pkgs.systemd}/bin/systemctl suspend
    fi
  '';
  hycovEasymotion = pkgs.writeShellScriptBin "hycovEasymotion" ''
    handle() {
      case $1 in
        renameworkspace*)
          workspace_name=$(hyprctl -j activeworkspace | ${pkgs.jq}/bin/jq -r '.name')
          if [ "$workspace_name" != "OVERVIEW" ]; then
            hyprctl dispatch easymotionexit
            exit 0
          fi
          ;;
      esac
    }

    workspace_name=$(hyprctl -j activeworkspace | ${pkgs.jq}/bin/jq -r '.name')

    if [ "$workspace_name" = "OVERVIEW" ]; then
        hyprctl dispatch hycov:leaveoverview
    else
        hyprctl dispatch hycov:enteroverview
        hyprctl dispatch 'easymotion action:hyprctl --batch "dispatch focuswindow address:{} ; dispatch hycov:leaveoverview"'
    fi
    socat -U - UNIX-CONNECT:/tmp/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done
  '';
in
{
  imports = [ ../../programs/waybar/hyprland_waybar.nix ];
  services.swayidle = {
    enable = true;
    events = [
      {
        event = "before-sleep";
        command = "${myswaylock}/bin/myswaylock";
      }
    ];
    timeouts = [
      {
        timeout = 900;
        command = suspendScript.outPath;
      }
    ];
  };
  wayland.windowManager.hyprland = {
    extraConfig = ''
      $mainMod = ALT
      # $scripts=$HOME/.config/hypr/scripts

      monitor=,preferred,auto,1 
      # monitor=HDMI-A-1, 1920x1080, 0x0, 1
      # monitor=eDP-1, 1920x1080, 1920x0, 1

      # Source a file (multi-file configs)
      # source = ~/.config/hypr/myColors.conf

      input {
        kb_layout = us
        kb_variant =
        kb_model =
        kb_options = caps:escape
        kb_rules =

        follow_mouse = 2 # 0|1|2|3
        float_switch_override_focus = 2
        numlock_by_default = true

        touchpad {
        natural_scroll = yes
        }

        sensitivity = 0 # -1.0 - 1.0, 0 means no modification.
      }

      general {
        gaps_in = 3
        gaps_out = 5
        border_size = 3
        col.active_border = rgb(81a1c1)
        col.inactive_border = rgba(595959aa)

        layout = dwindle # master|dwindle 
      }

      dwindle {
        no_gaps_when_only = false
        force_split = 0 
        special_scale_factor = 0.8
        split_width_multiplier = 1.0 
        use_active_for_splits = true
        pseudotile = yes 
        preserve_split = yes 
      }

      master {
        new_is_master = true
        special_scale_factor = 0.8
        new_is_master = true
        no_gaps_when_only = false
      }

      # cursor_inactive_timeout = 0
      decoration {
        rounding = 0
        active_opacity = 1.0
        inactive_opacity = 1.0
        fullscreen_opacity = 1.0
        drop_shadow = false
        shadow_range = 4
        shadow_render_power = 3
        shadow_ignore_window = true
      # col.shadow = 
      # col.shadow_inactive
      # shadow_offset
        dim_inactive = false
      # dim_strength = #0.0 ~ 1.0
        col.shadow = rgba(1a1a1aee)

          blur {
              enabled = true
              size = 3
              passes = 1
              new_optimizations = true
              xray = true
              ignore_opacity = false
          }
      }

      # animations {
      #   enabled = yes
      #
      #   bezier = easeOutElastic, 0.05, 0.9, 0.1, 1.05
      #   # bezier=overshot,0.05,0.9,0.1,1.1
      #
      #   animation = windows, 1, 5, easeOutElastic
      #   animation = windowsOut, 1, 5, default, popin 80%
      #   animation = border, 1, 8, default
      #   animation = fade, 1, 5, default
      #   animation = workspaces, 1, 6, default
      # }
      animations {
        enabled=1
        bezier = overshot, 0.13, 0.99, 0.29, 1.1
        animation = windows, 1, 4, overshot, slide
        animation = windowsOut, 1, 5, default, popin 80%
        animation = border, 1, 5, default
        animation = fade, 1, 8, default
        animation = workspaces, 1, 6, overshot, slidevert
      }

      gestures {
        workspace_swipe = true
        workspace_swipe_fingers = 4
        workspace_swipe_distance = 250
        workspace_swipe_invert = true
        workspace_swipe_min_speed_to_force = 15
        workspace_swipe_cancel_ratio = 0.5
        workspace_swipe_create_new = false
      }

      misc {
        disable_autoreload = true
        disable_hyprland_logo = true
        always_follow_on_dnd = true
        layers_hog_keyboard_focus = true
        animate_manual_resizes = false
        enable_swallow = true
        swallow_regex =
        focus_on_activate = true
      }

      #---------#
      # plugins #
      #---------#
      bind=ALT_CTRL,space,exec,${hycovEasymotion}/bin/hycovEasymotion
      submap=__easymotionsubmap__ 
      bind=Alt,right,hycov:movefocus,rightcross
      bind=Alt,left,hycov:movefocus,leftcross
      bind=Alt,up,hycov:movefocus,upcross
      bind=Alt,down,hycov:movefocus,downcross
      bind=ALT_SHIFT,p,killactive
      bind=ALT_CTRL,space,exec,${hycovEasymotion}/bin/hycovEasymotion
      submap=reset
      plugin {
          hycov {
            overview_gappo = 24 # gas width from screen
            overview_gappi = 18 # gas width from clients
            hotarea_size = 10   # hotarea size in bottom left,10x10
            enable_hotarea = 1  # move cursor to bottom-left can toggle overview
          }
          easymotion {
            #font size of the text
            textsize=30

            #color of the text, takes standard hyprland color format
            textcolor=rgba(ffffffff)

            #background color of the label box. alpha is respected
            bgcolor=rgba(46,52,64,1)

            #font to use for the label. This is passed directly to the pango font description
            textfont=JetBrainsMono Nerd Font
            
            #padding around the text (inside the label box) size in pixels, adjusted for
            #monitor scaling. This is the same format as hyprland's gapsin/gapsout workspace layout rule
            #example: textpadding=2 5 5 2 (spaces not commas)
            textpadding=10 20 20 10

            #size of the border around the label box. A border size of zero disables border rendering.
            bordersize=3

            #color of the border. takes the same format as hyprland's border (so it can be a gradient)
            bordercolor=rgba(ffffffff)

            #rounded corners? Same as hyprland's 'decoration:rounding' config
            rounding=3

            #which keys to use for labeling windows
            motionkeys=abcdefghijklmnopqrstuvwxyz1234567890
          }
      }

      bind = $mainMod, Return, exec, kitty
      bind = $mainMod SHIFT, Return, exec, kitty --class="termfloat"
      bind = $mainMod SHIFT, P, killactive,
      bind = $mainMod SHIFT, Q, exit,
      bind = $mainMod SHIFT, Space, togglefloating,
      bind = $mainMod,F,fullscreen
      bind = $mainMod,Y,pin
      bind = $mainMod, P, pseudo, # dwindle
      bind = $mainMod, J, togglesplit, # dwindle

      #-----------------------#
      # Toggle grouped layout #
      #-----------------------#
      bind = $mainMod, K, togglegroup,
      bind = $mainMod, Tab, changegroupactive, f

      #------------#
      # change gap #
      #------------#
      bind = $mainMod SHIFT, G,exec,hyprctl --batch "keyword general:gaps_out 5;keyword general:gaps_in 3"
      bind = $mainMod , G,exec,hyprctl --batch "keyword general:gaps_out 0;keyword general:gaps_in 0"

      #--------------------------------------#
      # Move focus with mainMod + arrow keys #
      #--------------------------------------#
      bind = $mainMod, left, movefocus, l
      bind = $mainMod, right, movefocus, r
      bind = $mainMod, up, movefocus, u
      bind = $mainMod, down, movefocus, d

      #----------------------------------------#
      # Switch workspaces with mainMod + [0-9] #
      #----------------------------------------#
      bind = $mainMod, 1, workspace, 1
      bind = $mainMod, 2, workspace, 2
      bind = $mainMod, 3, workspace, 3
      bind = $mainMod, 4, workspace, 4
      bind = $mainMod, 5, workspace, 5
      bind = $mainMod, 6, workspace, 6
      bind = $mainMod, 7, workspace, 7
      bind = $mainMod, 8, workspace, 8
      bind = $mainMod, 9, workspace, 9
      bind = $mainMod, 0, workspace, 10
      bind = $mainMod, L, workspace, +1
      bind = $mainMod, H, workspace, -1
      bind = $mainMod, period, workspace, e+1
      bind = $mainMod, comma, workspace,e-1
      bind = $mainMod, T, workspace,TG
      bind = $mainMod, M, workspace,Music

      #-------------------------------#
      # special workspace(scratchpad) #
      #-------------------------------# 
      bind = $mainMod, minus, movetoworkspace,special
      bind = $mainMod, equal, togglespecialworkspace

      #----------------------------------#
      # move window in current workspace #
      #----------------------------------#
      bind = $mainMod SHIFT,left ,movewindow, l
      bind = $mainMod SHIFT,right ,movewindow, r
      bind = $mainMod SHIFT,up ,movewindow, u
      bind = $mainMod SHIFT,down ,movewindow, d

      #---------------------------------------------------------------#
      # Move active window to a workspace with mainMod + ctrl + [0-9] #
      #---------------------------------------------------------------#
      bind = $mainMod CTRL, 1, movetoworkspace, 1
      bind = $mainMod CTRL, 2, movetoworkspace, 2
      bind = $mainMod CTRL, 3, movetoworkspace, 3
      bind = $mainMod CTRL, 4, movetoworkspace, 4
      bind = $mainMod CTRL, 5, movetoworkspace, 5
      bind = $mainMod CTRL, 6, movetoworkspace, 6
      bind = $mainMod CTRL, 7, movetoworkspace, 7
      bind = $mainMod CTRL, 8, movetoworkspace, 8
      bind = $mainMod CTRL, 9, movetoworkspace, 9
      bind = $mainMod CTRL, 0, movetoworkspace, 10
      bind = $mainMod CTRL, left, movetoworkspace, -1
      bind = $mainMod CTRL, right, movetoworkspace, +1
      # same as above, but doesnt switch to the workspace
      bind = $mainMod SHIFT, 1, movetoworkspacesilent, 1
      bind = $mainMod SHIFT, 2, movetoworkspacesilent, 2
      bind = $mainMod SHIFT, 3, movetoworkspacesilent, 3
      bind = $mainMod SHIFT, 4, movetoworkspacesilent, 4
      bind = $mainMod SHIFT, 5, movetoworkspacesilent, 5
      bind = $mainMod SHIFT, 6, movetoworkspacesilent, 6
      bind = $mainMod SHIFT, 7, movetoworkspacesilent, 7
      bind = $mainMod SHIFT, 8, movetoworkspacesilent, 8
      bind = $mainMod SHIFT, 9, movetoworkspacesilent, 9
      bind = $mainMod SHIFT, 0, movetoworkspacesilent, 10
      # Scroll through existing workspaces with mainMod + scroll
      bind = $mainMod, mouse_down, workspace, e+1
      bind = $mainMod, mouse_up, workspace, e-1

      #-------------------------------------------#
      # switch between current and last workspace #
      #-------------------------------------------#
      binds {
           workspace_back_and_forth = 1 
           allow_workspace_cycles = 1
      }
      bind=$mainMod,slash,workspace,previous

      #------------------------#
      # quickly launch program #
      #------------------------# 
      bind=$mainMod,B,exec,nvidia-offload firefox
      bind=$mainMod,M,exec,kitty --class="musicfox" --hold sh -c "musicfox" 
      bind=$mainMod SHIFT,D,exec,kitty  --class="danmufloat" --hold sh -c "export TERM=xterm-256color && bili"
      bind=$mainMod SHIFT,X,exec,${myswaylock}/bin/myswaylock
      bind=$mainMod,T,exec,telegram-desktop
      bind=$mainMod,bracketleft,exec,grimblast --notify --cursor  copysave area ~/Pictures/$(date "+%Y-%m-%d"T"%H:%M:%S_no_watermark").png
      bind=$mainMod,bracketright,exec, grimblast --notify --cursor  copy area
      bind=$mainMod,A,exec, ${grimblast_watermark}/bin/grimblast_watermark
      bind=,Super_L,exec, pkill rofi || ~/.config/rofi/launcher.sh
      bind=$mainMod,Super_L,exec, bash ~/.config/rofi/powermenu.sh
      bind=$mainMod,q,exec, qq --enable-features=UseOzonePlatform --ozone-platform=x11

      #-----------------------------------------#
      # control volume,brightness,media players-#
      #-----------------------------------------#
      bind=,XF86AudioRaiseVolume,exec, pamixer -i 5
      bind=,XF86AudioLowerVolume,exec, pamixer -d 5
      bind=,XF86AudioMute,exec, pamixer -t
      bind=,XF86AudioMicMute,exec, pamixer --default-source -t
      bind=,XF86MonBrightnessUp,exec, light -A 5
      bind=,XF86MonBrightnessDown, exec, light -U 5
      bind=,XF86AudioPlay,exec, mpc -q toggle 
      bind=,XF86AudioNext,exec, mpc -q next 
      bind=,XF86AudioPrev,exec, mpc -q prev

      #---------------#
      # waybar toggle #
      # --------------#
      bind=$mainMod,O,exec,killall -SIGUSR1 .waybar-wrapped

      #---------------#
      # resize window #
      #---------------#
      bind=ALT,R,submap,resize
      submap=resize
      binde=,right,resizeactive,15 0
      binde=,left,resizeactive,-15 0
      binde=,up,resizeactive,0 -15
      binde=,down,resizeactive,0 15
      binde=,l,resizeactive,15 0
      binde=,h,resizeactive,-15 0
      binde=,k,resizeactive,0 -15
      binde=,j,resizeactive,0 15
      bind=,escape,submap,reset 
      submap=reset

      bind=CTRL SHIFT, left, resizeactive,-15 0
      bind=CTRL SHIFT, right, resizeactive,15 0
      bind=CTRL SHIFT, up, resizeactive,0 -15
      bind=CTRL SHIFT, down, resizeactive,0 15
      bind=CTRL SHIFT, l, resizeactive, 15 0
      bind=CTRL SHIFT, h, resizeactive,-15 0
      bind=CTRL SHIFT, k, resizeactive, 0 -15
      bind=CTRL SHIFT, j, resizeactive, 0 15

      bindm = $mainMod, mouse:272, movewindow
      bindm = $mainMod, mouse:273, resizewindow

      #-----------------------#
      # wall(by swww service) #
      #-----------------------#
      # exec-once = default_wall 

      #------------#
      # auto start #
      #------------#
      exec-once = ${launch_waybar}/bin/launch_waybar &
      exec-once = mako &
      exec-once = nm-applet &
      #exec-once = swayidle -w timeout 900 'systemctl suspend' before-sleep '${myswaylock}/bin/myswaylock'

      #---------------#
      # windows rules #
      #---------------#
      #`hyprctl clients` get class、title...
      windowrule=float,title:^(Picture-in-Picture)$
      windowrule=size 960 540,title:^(Picture-in-Picture)$
      windowrule=move 25%-,title:^(Picture-in-Picture)$
      windowrule=float,imv
      windowrule=move 25%-,imv
      windowrule=size 960 540,imv
      windowrule=float,mpv
      windowrule=move 25%-,mpv
      windowrule=size 960 540,mpv
      windowrule=float,danmufloat
      windowrule=move 25%-,danmufloat
      windowrule=pin,danmufloat
      windowrule=rounding 5,danmufloat
      windowrule=size 960 540,danmufloat
      windowrule=float,termfloat
      windowrule=move 25%-,termfloat
      windowrule=size 960 540,termfloat
      windowrule=rounding 5,termfloat
      windowrule=float,nemo
      windowrule=move 25%-,nemo
      windowrule=size 960 540,nemo
      windowrule=opacity 0.95,title:Telegram
      windowrule=animation slide right,kitty
      windowrule=workspace name:TG, title:Telegram
      windowrule=workspace name:Music, musicfox
      windowrule=float,ncmpcpp
      windowrule=move 25%-,ncmpcpp
      windowrule=size 960 540,ncmpcpp
      windowrule=noblur,^(firefox)$

      #-----------------#
      # workspace rules #
      #-----------------#
      workspace=HDMI-A-1,10
    '';
  };
}
