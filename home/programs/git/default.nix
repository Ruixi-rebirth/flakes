{ me, ... }:
{
  programs = {
    delta = {
      enable = true;
      enableGitIntegration = true;
      options = {
        syntax-theme = "Nord";
        line-numbers = true;
      };
    };
    git = {
      enable = true;
      settings = {
        user = {
          name = me.githubUserName;
          email = me.email;
        };
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
        core = {
          quotepath = false;
        };
      };
      signing = {
        key = me.gitSignKey;
        signByDefault = true;
      };
    };
  };
}
