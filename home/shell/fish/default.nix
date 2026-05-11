{ config, pkgs, ... }:
{
  programs.fish = {
    enable = true;
    loginShellInit =
      if config.wayland.windowManager.sway.enable then
        ''
          set TTY1 (tty)
          [ "$TTY1" = "/dev/tty1" ] && exec sway
        ''
      else
        "";
    interactiveShellInit = ''
      set fish_greeting ""
      set fish_key_bindings  fish_vi_key_bindings
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish | source
    '';
    shellAliases = {
      l = "eza -lah --icons";
      la = "eza -a --icons";
      ll = "eza -l --icons";
      ls = "eza";
      n = "fastfetch";
      nf = ''nvim (FZF_DEFAULT_COMMAND='fd' FZF_DEFAULT_OPTS="--preview 'bat --style=numbers --color=always --line-range :500 {}'" fzf --height 60% --layout reverse --info inline --border --color 'border:#b48ead')'';
      top = "btop";
    };
    functions = {
      nv = ''
        if command -q neovide.exe
            neovide.exe --wsl $argv
        else if command -q neovide
            neovide $argv
        else
            nvim $argv
        end
      '';
      f = ''
        FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git' FZF_DEFAULT_OPTS="--color=bg+:#4C566A,bg:#424A5B,spinner:#F8BD96,hl:#F28FAD  --color=fg:#D9E0EE,header:#F28FAD,info:#DDB6F2,pointer:#F8BD96  --color=marker:#F8BD96,fg+:#F2CDCD,prompt:#DDB6F2,hl+:#F28FAD --preview 'bat --style=numbers --color=always --line-range :500 {}'" fzf --height 60% --layout reverse --info inline --border --color 'border:#b48ead'
      '';
      "clang++strict" = ''
        clang++ -std=c++20 -Wall -Werror -Wextra -Wconversion -Wsign-conversion -pedantic-errors -ggdb $argv
      '';
    };
    plugins = [ ];
  };
  home.file = {
    ".config/fish/conf.d/tokyo_night.fish".text = import ./tokyo_night.nix;
    ".config/fish/functions/xdg-get.fish".text = import ./functions/xdg-get.nix;
    ".config/fish/functions/xdg-set.fish".text = import ./functions/xdg-set.nix;
    ".config/fish/functions/owf.fish".text = import ./functions/owf.nix;
    ".config/fish/functions/cd.fish".text = import ./functions/cd.nix;
  };
}
