{ appearance, ... }:
let
  n = appearance.palettes.nord;
  h = appearance.toHex;
in
{
  programs.starship = {
    enable = true;
    enableTransience = false;
    settings = {
      add_newline = false;

      character = {
        success_symbol = "[❯](bold ${h n.nord9})";
        error_symbol = "[❯](bold ${h n.nord11})";
        vimcmd_symbol = "[❮](bold ${h n.nord9})";
        vimcmd_replace_one_symbol = "[❮](bold ${h n.nord15})";
        vimcmd_replace_symbol = "[❮](bold ${h n.nord15})";
        vimcmd_visual_symbol = "[❮](bold ${h n.nord12})";
      };

      directory = {
        style = h n.nord9;
        truncation_length = 3;
        truncate_to_repo = true;
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = h n.nord15;
      };

      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        style = h n.nord12;
        conflicted = "!";
        modified = "~";
        staged = "+";
        untracked = "?";
        deleted = "✗";
        renamed = "↻";
        stashed = "≡";
        ahead = "↑$count";
        behind = "↓$count";
        diverged = "↕";
      };

      cmd_duration = {
        format = "[$duration]($style)";
        style = h n.nord3;
        min_time = 2000;
      };

      nix_shell = {
        symbol = "󱄅 ";
        format = "[$symbol]($style)";
        style = h n.nord7;
      };
    };
  };
}
