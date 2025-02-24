{
  mkWaybar =
    { workspaces }:
    {
      pkgs,
      appearance,
      ...
    }:
    let
      sharedScripts = import ./share_scripts.nix { inherit pkgs; };
      n = appearance.palettes.nord;
      h = appearance.toHex;
    in
    {
      programs.waybar = {
        enable = true;
        # package = inputs.nixpkgs-wayland.packages.${pkgs.stdenv.hostPlatform.system}.waybar;
        systemd = {
          enable = false; # disable it,autostart it in sway conf
          targets = [ "graphical-session.target" ];
        };
        style = ''
          * {
            font-family: "${appearance.font.name}";
            font-size: 12pt;
            font-weight: bold;
            border-radius: 0px;
            transition-property: background-color;
            transition-duration: 0.5s;
          }

          @keyframes blink_red {
            to {
              background-color: ${h n.nord11};
              color: ${h n.nord0};
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
            background-color: ${h n.nord1};
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
            color: ${h n.nord4};
          }

          #workspaces button.focused {
            background-color: ${h n.nord7};
            color: ${h n.nord0};
          }

          #workspaces button.urgent {
            color: ${h n.nord0};
          }

          #workspaces button:hover {
            background-color: ${h n.nord15};
            color: ${h n.nord0};
          }

          tooltip {
            /* background: rgb(250, 244, 252); */
            background: ${h n.nord1};
          }

          tooltip label {
            color: ${h n.nord5};
          }

          #custom-launcher {
            font-size: 20px;
            padding-left: 8px;
            padding-right: 6px;
            color: ${h n.nord8};
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
            color: ${h n.nord7};
          }

          #cpu {
            color: ${h n.nord15};
          }

          #clock {
            color: ${h n.nord5};
          }

          #custom-wall {
            color: ${h n.nord15};
          }

          #temperature {
            color: ${h n.nord9};
          }

          #backlight {
            color: ${h n.nord14};
          }

          #pulseaudio {
            color: ${h n.nord13};
          }

          #network {
            color: ${h n.nord14};
          }

          #network.disconnected {
            color: ${h n.nord4};
          }

          #battery.charging,
          #battery.full,
          #battery.discharging {
            color: ${h n.nord12};
          }

          #battery.critical:not(.charging) {
            color: ${h n.nord4};
          }

          #custom-powermenu {
            color: ${h n.nord11};
          }

          #tray {
            padding-right: 8px;
            padding-left: 10px;
          }

          #tray menu {
            background: ${h n.nord1};
            color: ${h n.nord4};
          }

          #mpd.paused {
            color: ${h n.nord9};
            font-style: italic;
          }

          #mpd.stopped {
            background: transparent;
          }

          #mpd {
            color: ${h n.nord5};

            /* color: #c0caf5; */
          }

          #custom-cava-internal {
            font-family: "${appearance.font.name}";
          }
        '';
        settings = [
          {
            mode = "dock";
            start_hidden = false;
            modules-left = [
              "custom/launcher"
              workspaces.module
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
                "recording" = "<span foreground='${h n.nord11}'> </span>";
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
            "${workspaces.module}" = workspaces.config;
            "backlight" = {
              "device" = "intel_backlight";
              "on-scroll-up" = "brightnessctl -d intel_backlight set +5%";
              "on-scroll-down" = "brightnessctl -d intel_backlight set 5%-";
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
              "calendar" = {
                "mode" = "year";
                "mode-mon-col" = 3;
                "weeks-pos" = "right";
                "on-scroll" = 1;
                "format" = {
                  "months" = "<span color='${h n.nord13}'><b>{}</b></span>";
                  "days" = "<span color='${h n.nord15}'><b>{}</b></span>";
                  "weeks" = "<span color='${h n.nord7}'><b>W{}</b></span>";
                  "weekdays" = "<span color='${h n.nord13}'><b>{}</b></span>";
                  "today" = "<span color='${h n.nord11}'><b><u>{}</u></b></span>";
                };
              };
              "actions" = {
                "on-click-right" = "mode";
                "on-scroll-up" = "shift_up";
                "on-scroll-down" = "shift_down";
              };
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
              "format" = "<span foreground='${h n.nord15}'></span> {title}";
              "format-paused" = " {title}";
              "format-stopped" = "<span foreground='${h n.nord15}'></span>";
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
    };
}
