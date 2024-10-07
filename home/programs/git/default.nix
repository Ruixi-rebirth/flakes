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
      extraConfig = {
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
