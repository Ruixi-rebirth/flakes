{
  config,
  lib,
  me,
  ...
}:
{
  # NOTE: https://github.com/Mic92/sops-nix#initrd-secrets
  sops = {
    defaultSopsFile = ../../secrets/secrets.yaml;
    gnupg.sshKeyPaths = [ ];
    age = {
      sshKeyPaths = [ ];
      keyFile = "/var/lib/sops-nix/keys.txt"; # You must back up this keyFile yourself
      generateKey = true;
    };
    secrets = {
      "config.dae" = {
        mode = "0600";
        owner = "${me.userName}";
      };
      SSH_PVKEY = {
        mode = "0600";
        owner = "${me.userName}";
        path = "/home/" + "${me.userName}" + "/.ssh/id_ed25519"; # ssh-keygen -y -f id_ed25519 > id_ed25519.pub
      };
      GPG_PVKEY = {
        mode = "0600";
        owner = "${me.userName}";
        path = "/home/" + "${me.userName}" + "/.gnupg/GPG_PVKEY"; # gpg --import GPG_PVKEY
      };
      Element_securityKey = {
        owner = "${me.userName}";
        path = "/home/" + "${me.userName}" + "/.config/element_SK/Element_securityKey";
      };
      OPENAI_API_KEY = {
        owner = "${me.userName}";
      };
      ANTHROPIC_API_KEY = {
        owner = "${me.userName}";
      };
      CACHIX_AUTH_TOKEN = {
        owner = "${me.userName}";
      };
      CACHIX_SIGNING_KEY = {
        owner = "${me.userName}";
      };
      GITHUB_TOKEN = {
        owner = "${me.userName}";
      };
    };
  };
  # issue: https://github.com/Mic92/sops-nix/issues/149
  # workaround:
  systemd.services.decrypt-sops = {
    description = "Decrypt sops secrets";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = "2s";
    };
    script = config.system.activationScripts.setupSecrets.text;
  };

  programs.fish = lib.mkIf config.programs.fish.enable {
    shellInit = ''
      export ANTHROPIC_API_KEY="$(cat ${config.sops.secrets.ANTHROPIC_API_KEY.path})"
      export OPENAI_API_KEY="$(cat ${config.sops.secrets.OPENAI_API_KEY.path})"
      export Config_dae="$(cat ${config.sops.secrets."config.dae".path})"
      export Element_securityKey="$(cat ${config.sops.secrets."Element_securityKey".path})"
      export CACHIX_AUTH_TOKEN="$(cat ${config.sops.secrets.CACHIX_AUTH_TOKEN.path})"
      export CACHIX_SIGNING_KEY="$(cat ${config.sops.secrets.CACHIX_SIGNING_KEY.path})"
      export GITHUB_TOKEN="$(cat ${config.sops.secrets.GITHUB_TOKEN.path})"
      export SSH_PVKEY="$(cat ${config.sops.secrets.SSH_PVKEY.path})"
      export GPG_PVKEY="$(cat ${config.sops.secrets.GPG_PVKEY.path})"
    '';
  };
}
