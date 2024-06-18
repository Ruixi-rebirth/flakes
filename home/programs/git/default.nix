{
  programs = {
    git = {
      enable = true;
      userName = "Ruixi-rebirth";
      userEmail = "ruixirebirth@gmail.com";
      signing = {
        key = "D6FA49B594337867";
        signByDefault = true;
      };
      extraConfig = {
        url = {
          "ssh://git@github.com:Ruixi-rebirth" = {
            insteadOf = "https://github.com/Ruixi-rebirth/";
          };
        };
      };
    };
  };
}
