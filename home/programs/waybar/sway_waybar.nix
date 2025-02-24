{ pkgs, inputs, ... }:
let
  sharedScripts = import ./share_scripts.nix { inherit pkgs; };
in
{
  programs.waybar = {
    enable = true;
    # package = inputs.nixpkgs-wayland.packages.${pkgs.system}.waybar;
    systemd = {
      enable = false; # disable it,autostart it in sway conf
      target = "graphical-session.target";
    };
    style = ''
      * {
        font-family: "Maple Mono NF CN";
        font-size: 12pt;
        font-weight: bold;
        border-radius: 0px;
        transition-property: background-color;
        transition-duration: 0.5s;
      }

      @keyframes blink_red {
        to {
          background-color: rgb(242, 143, 173);
          color: rgb(26, 24, 38);
        }
      }

      .warning,
      .critical,
      .urgent {
        animation-name: blink_red;
        animation-duration: 1s;
        animation-timing-function: linear;
        animation-iteration-count: infinite;
        animation-direction: alternate;
      }

      window#waybar {
        background-color: transparent;
      }

      window>box {
        margin-left: 5px;
        margin-right: 5px;
        margin-top: 5px;
        background-color: #3b4252;
      }

      #workspaces {
        padding-left: 0px;
        padding-right: 4px;
      }

      #workspaces button {
        padding-top: 5px;
        padding-bottom: 5px;
        padding-left: 6px;
        padding-right: 6px;
        color: #d8dee9;
      }

      #workspaces button.focused {
        background-color: rgb(181, 232, 224);
        color: rgb(26, 24, 38);
      }

      #workspaces button.urgent {
        color: rgb(26, 24, 38);
      }

      #workspaces button:hover {
        background-color: #b38dac;
        color: rgb(26, 24, 38);
      }

      tooltip {
        /* background: rgb(250, 244, 252); */
        background: #3b4253;
      }

      tooltip label {
        color: #e4e8ef;
      }

      #custom-launcher {
        font-size: 20px;
        padding-left: 8px;
        padding-right: 6px;
        color: #7ebae4;
      }

      #mode,
      #clock,
      #memory,
      #temperature,
      #cpu,
      #mpd,
      #custom-wall,
      #temperature,
      #backlight,
      #pulseaudio,
      #network,
      #battery,
      #custom-powermenu,
      #custom-cava-internal {
        padding-left: 10px;
        padding-right: 10px;
      }

      /* #mode { */
      /* 	margin-left: 10px; */
      /* 	background-color: rgb(248, 189, 150); */
      /*     color: rgb(26, 24, 38); */
      /* } */
      #memory {
        color: #8ebbba;
      }

      #cpu {
        color: #b38dac;
      }

      #clock {
        color: #e4e8ef;
      }

      #custom-wall {
        color: #b38dac;
      }

      #temperature {
        color: #80a0c0;
      }

      #backlight {
        color: #a2bd8b;
      }

      #pulseaudio {
        color: #e9c98a;
      }

      #network {
        color: #99cc99;
      }

      #network.disconnected {
        color: #cccccc;
      }

      #battery.charging,
      #battery.full,
      #battery.discharging {
        color: #cf876f;
      }

      #battery.critical:not(.charging) {
        color: #d6dce7;
      }

      #custom-powermenu {
        color: #bd6069;
      }

      #tray {
        padding-right: 8px;
        padding-left: 10px;
      }

      #tray menu {
        background: #3b4252;
        color: #dee2ea;
      }

      #mpd.paused {
        color: rgb(192, 202, 245);
        font-style: italic;
      }

      #mpd.stopped {
        background: transparent;
      }

      #mpd {
        color: #e4e8ef;

        /* color: #c0caf5; */
      }

      #custom-cava-internal {
        font-family: "Maple Mono NF CN";
      }
    '';
    settings = [
      {
        mode = "dock";
        start_hidden = false;
        modules-left = [
          "custom/launcher"
          "sway/workspaces"
          "temperature"
          "custom/wall"
          "mpd"
          "custom/cava-internal"
          "custom/recgif"
        ];
        modules-center = [
          "clock"
        ];
        modules-right = [
          "pulseaudio"
          "backlight"
          "memory"
          "cpu"
          # "network"
          "battery"
          "custom/powermenu"
          "tray"
        ];
        "custom/launcher" = {
          "format" = " ";
          "on-click" = "~/.config/rofi/launcher.sh";
          "tooltip" = false;
        };
        "custom/recgif" = {
          "format" = "{icon}";
          "return-type" = "json";
          "format-icons" = {
            "recording" = "<span foreground='#bf616a'> </span>";
            "stopped" = " ";
          };
          "exec" =
            "pgrep -x recgif >/dev/null && echo '{\"alt\": \"recording\"}' || echo '{\"alt\": \"stopped\"}'";
          "interval" = 1;
          "exec-if" = "sleep 0.1";
          "on-click" = "pkill -SIGINT wf-recorder || ${sharedScripts.recgif}/bin/recgif";
          "on-click-right" = "flameshot_watermark";
          "tooltip" = false;
        };
        "custom/wall" = {
          "on-click" = "${sharedScripts.wallpaper_random}/bin/wallpaper_random";
          "on-click-middle" = "${sharedScripts.default_wall}/bin/default_wall";
          "on-click-right" =
            "killall dynamic_wallpaper || ${sharedScripts.dynamic_wallpaper}/bin/dynamic_wallpaper &";
          "format" = " 󰠖 ";
          "tooltip" = false;
        };
        "custom/cava-internal" = {
          "exec" = "sleep 1s && ${sharedScripts.cava-internal}/bin/cava-internal";
          "tooltip" = false;
        };
        "sway/workspaces" = {
          "disable-scroll" = true;
        };
        "backlight" = {
          "device" = "intel_backlight";
          "on-scroll-up" = "light -A 5";
          "on-scroll-down" = "light -U 5";
          "format" = "{icon} {percent}%";
          "format-icons" = [
            "󰃝"
            "󰃞"
            "󰃟"
            "󰃠"
          ];
        };
        "pulseaudio" = {
          "scroll-step" = 1;
          "format" = "{icon} {volume}%";
          "format-muted" = "󰖁 Muted";
          "format-icons" = {
            "default" = [
              ""
              ""
              ""
            ];
          };
          "on-click" = "pamixer -t";
          "tooltip" = false;
        };
        "battery" = {
          "interval" = 10;
          "states" = {
            "warning" = 20;
            "critical" = 10;
          };
          "format" = "{icon} {capacity}%";
          "format-icons" = [
            "󰁺"
            "󰁻"
            "󰁼"
            "󰁽"
            "󰁾"
            "󰁿"
            "󰂀"
            "󰂁"
            "󰂂"
            "󰁹"
          ];
          "format-full" = "{icon} {capacity}%";
          "format-charging" = "󰂄 {capacity}%";
          "tooltip" = false;
        };
        "clock" = {
          "interval" = 1;
          "format" = "{:%I:%M %p  %A %b %d}";
          "tooltip" = true;
          "tooltip-format" = "<tt>{calendar}</tt>";
        };
        "memory" = {
          "interval" = 1;
          "format" = "󰍛 {percentage}%";
          "states" = {
            "warning" = 85;
          };
        };
        "cpu" = {
          "interval" = 1;
          "format" = "󰻠 {usage}%";
        };
        "mpd" = {
          "max-length" = 25;
          "format" = "<span foreground='#bb9af7'></span> {title}";
          "format-paused" = " {title}";
          "format-stopped" = "<span foreground='#bb9af7'></span>";
          "format-disconnected" = "";
          "on-click" = "mpc --quiet toggle";
          "on-click-right" = "mpc update; mpc ls | mpc add";
          "on-click-middle" = "kitty --class='ncmpcpp' ncmpcpp";
          "on-scroll-up" = "mpc --quiet prev";
          "on-scroll-down" = "mpc --quiet next";
          "smooth-scrolling-threshold" = 5;
          "tooltip-format" = "{title} - {artist} ({elapsedTime:%M:%S}/{totalTime:%H:%M:%S})";
        };
        "network" = {
          "interval" = 1;
          "format-wifi" = "󰖩 {essid} ({ipaddr})";
          "format-ethernet" = "󰀂 {ifname} ({ipaddr})";
          "format-linked" = "󰖪 {essid} (No IP)";
          "format-disconnected" = "󰯡 Disconnected";
          "tooltip" = false;
        };
        "temperature" = {
          #"critical-threshold"= 80;
          "tooltip" = false;
          "format" = " {temperatureC}°C";
        };
        "custom/powermenu" = {
          "format" = "";
          "on-click" = "~/.config/rofi/powermenu.sh";
          "tooltip" = false;
        };
        "tray" = {
          "icon-size" = 15;
          "spacing" = 5;
        };
      }
    ];
  };
}
