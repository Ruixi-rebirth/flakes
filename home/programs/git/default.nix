{
  programs = {
    git = {
      enable = true;
      userName = "Ruixi-rebirth";
      userEmail = "ruixirebirth@gmail.com";
      signing = {
        key = "847E32F6F2F1D108";
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
