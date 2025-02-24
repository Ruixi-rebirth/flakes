{ appearance, ... }:
let
  n = appearance.palettes.nord;
  a = appearance.toAnsi;
in
{
  programs.fastfetch = {
    enable = true;
    settings = {
      logo = {
        type = "none";
      };
      display = {
        separator = " ";
        key = {
          width = 15;
        };
        color = {
          keys = a n.nord15;
        };
        size = {
          binaryPrefix = "jedec";
        };

      };
      modules = [
        {
          type = "title";
          color = {
            user = a n.nord13;
            at = a n.nord15;
            host = a n.nord14;
          };
        }
        {
          type = "separator";
          string = "────────────────────────────────────────";
        }
        {
          type = "os";
          key = "󰣇 OS     ";
        }
        {
          type = "kernel";
          key = "󰌽 Kernel ";
        }
        {
          type = "uptime";
          key = "󰔟 Uptime ";
        }
        {
          type = "packages";
          key = "󰏖 PKGs   ";
        }
        {
          type = "shell";
          key = "󱆃 Shell  ";
        }
        {
          type = "display";
          key = "󰍹 Resolution";
        }
        {
          type = "de";
          key = "󰧨 DE     ";
        }
        {
          type = "wm";
          key = "󱂬 WM     ";
        }
        {
          type = "terminal";
          key = "󱊑 Terminal";
        }
        {
          type = "cpu";
          key = "󰻟 CPU    ";
          showPeCoreCount = true;
        }
        {
          type = "gpu";
          key = "󰢮 GPU    ";
        }
        {
          type = "memory";
          key = "󰍛 Memory ";
          format = "{used} / {total} ({percentage})";
        }
        {
          type = "disk";
          key = "󰋊 Disk   ";
          format = "{##${n.nord8}}{mountpoint} ({filesystem}){#} │ {size-used} / {size-total} ({size-percentage})";
        }
        {
          type = "localip";
          key = "󰩟 Local IP";
          showIpv4 = true;
          showIpv6 = false;
        }
      ];
    };
  };
}
