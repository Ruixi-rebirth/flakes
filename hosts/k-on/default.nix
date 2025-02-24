{
  config,
  pkgs,
  me,
  ...
}:
let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec "$@"
  '';
in
{
  imports = [
    ./hardware-configuration.nix
    ./ai
  ];

  networking.hostName = "k-on";

  # NOTE: Power management/Suspend and hibernate: https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate
  boot = {
    resumeDevice = "/dev/mapper/pool-root"; # The partition where the swapfile is located
    kernel.sysctl = {
      "kernel.kptr_restrict" = 0;
      "kernel.perf_event_paranoid" = -1;
    };
    kernelPackages = pkgs.linuxPackages_xanmod_latest;
    kernelParams = [
      "quiet"
      "splash"
      "nvidia-drm.modeset=1"
      "modprobe.blacklist=nouveau"
      "resume_offset=13938688" # `filefrag -v /var/lib/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}'`
    ];
  };

  # The default priority will be higher than the swapfile, `swapon --show`
  # https://search.nixos.org/options?channel=unstable&show=zramSwap.priority&from=0&size=50&sort=relevance&type=packages&query=zramSwap
  # https://search.nixos.org/options?channel=unstable&show=swapDevices.*.priority&from=0&size=50&sort=relevance&type=packages&query=swapDevices
  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024;
    }
  ];

  services = {
    tlp.enable = true;
    auto-cpufreq.enable = true;
    xserver.videoDrivers = [ "nvidia" ];
  };
  hardware = {
    nvidia = {
      open = false;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
      modesetting.enable = true;
      prime = {
        offload.enable = true;
        intelBusId = "PCI:00:02:0";
        nvidiaBusId = "PCI:01:00:0";
      };

    };
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-media-driver
        vaapiIntel
        nvidia-vaapi-driver
        vaapiVdpau
        libvdpau-va-gl
      ];
    };
  };
  environment.systemPackages =
    with pkgs;
    [
      libva
      libva-utils
      glxinfo
    ]
    ++ [
      nvidia-offload
      config.boot.kernelPackages.perf
      flamegraph
    ];

  environment.variables = {
    # WLR_RENDERER = "vulkan";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    GBM_BACKEND = "nvidia-drm";
    WLR_NO_HARDWARE_CURSORS = "1";
    WLR_RENDERER_ALLOW_SOFTWARE = "1";
  };
}
