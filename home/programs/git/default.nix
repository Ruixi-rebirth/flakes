{ me, ... }:
{
  programs = {
    git = {
      enable = true;
      userName = me.githubUserName;
      userEmail = me.email;
      signing = {
        key = me.gitSignKey;
        signByDefault = true;
      };
      delta.enable = true;
      extraConfig = {
        pull = {
          rebase = false;
        };
        url = {
          "git@github.com:" = {
            insteadOf = "gh:";
          };
          "https://github.com/" = {
            insteadOf = "github:";
          };
        };
      };
    };
  };
}
