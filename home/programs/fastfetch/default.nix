{ pkgs, ... }:
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
          keys = "magenta";
          title = "magenta";
        };
        size = {
          binaryPrefix = "jedec";
        };
        percent = {
          type = 9;
        };
        bar = {
          char = {
            elapsed = "■";
            total = "□";
          };
          width = 12;
        };
      };
      modules = [
        "title"
        {
          type = "separator";
          string = "────────────────────────────────────────";
        }
        {
          type = "os";
          key = "󰣇 OS     ";
          keyColor = "magenta";
        }
        {
          type = "kernel";
          key = " Kernel ";
          keyColor = "magenta";
        }
        {
          type = "uptime";
          key = "󰔟 Uptime ";
          keyColor = "magenta";
        }
        {
          type = "packages";
          key = "󰏖 PKGs   ";
          keyColor = "magenta";
        }
        {
          type = "shell";
          key = " Shell  ";
          keyColor = "magenta";
        }
        {
          type = "display";
          key = "󰍹 Resolution";
          keyColor = "magenta";
        }
        {
          type = "de";
          key = "󰧨 DE     ";
          keyColor = "magenta";
        }
        {
          type = "wm";
          key = "󱂬 WM     ";
          keyColor = "magenta";
        }
        {
          type = "terminal";
          key = "󱊑 Terminal";
          keyColor = "magenta";
        }
        {
          type = "cpu";
          key = " CPU    ";
          keyColor = "magenta";
          showPeCoreCount = true;
        }
        {
          type = "gpu";
          key = "󰢮 GPU    ";
          keyColor = "magenta";
        }
        {
          type = "memory";
          key = "󰍛 Memory ";
          keyColor = "magenta";
        }
        {
          type = "disk";
          key = "󰋊 Disk   ";
          keyColor = "magenta";
          format = "{#36}{mountpoint} ({filesystem}){#} │ {size-used} / {size-total} ({size-percentage})";
        }
        {
          type = "localip";
          key = "󰩟 Local IP";
          keyColor = "magenta";
          showIpv4 = true;
          showIpv6 = false;
        }
      ];
    };
  };
}
