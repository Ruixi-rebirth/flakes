{ ... }:
{
  programs.starship = {
    enable = true;
    enableTransience = true;
    settings = {
      add_newline = false;

      character = {
        success_symbol = "[❯](bold #cba6f7)";
        error_symbol = "[❯](bold #f38ba8)";
        vimcmd_symbol = "[❮](bold #cba6f7)";
        vimcmd_replace_one_symbol = "[❮](bold #f5c2e7)";
        vimcmd_replace_symbol = "[❮](bold #f5c2e7)";
        vimcmd_visual_symbol = "[❮](bold #fab387)";
      };

      directory = {
        style = "#b4befe";
        truncation_length = 3;
        truncate_to_repo = true;
        format = "[$path]($style) ";
      };

      git_branch = {
        format = "[$branch]($style) ";
        style = "#f5c2e7";
      };

      git_status = {
        format = "([\\[$all_status$ahead_behind\\]]($style) )";
        style = "#fab387";
        conflicted = "!";
        modified = "~";
        staged = "+";
        untracked = "?";
        deleted = "✗";
        stashed = "≡";
        ahead = "↑$count";
        behind = "↓$count";
        diverged = "↕";
      };

      cmd_duration = {
        format = "[$duration]($style)";
        style = "#6c7086";
        min_time = 2000;
      };

      nix_shell = {
        symbol = "󱄅 ";
        format = "[$symbol]($style)";
        style = "#94e2d5";
      };

    };
  };
}
