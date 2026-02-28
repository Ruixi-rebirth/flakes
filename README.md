## 💡 Installation Suggestions

- **Host Selection**:
  - `minimal`: **Highly recommended for initial installation.** It contains only the base system, making the process fast and stable. If you are installing NixOS (not WSL), please choose this first.
  - `yu`: Based on **WSL** (Windows Subsystem for Linux).
  - `k-on`: A regular **NixOS** full configuration (includes desktop environment, etc.).
- **Hardware Requirements**:
  - Recommended RAM: **> 8GB**.
  - **Reason**: In the NixOS Live environment, operations occur in RAM and Nix downloads many dependencies. Insufficient memory often leads to "No space left on device" errors.
  - **Suggestion**: If your RAM is limited, install the `minimal` configuration first. Once the system is successfully installed and booted, you can then switch to the full configuration.

---

step0:

```
> Enter the nixos livecd environment
```

step1:

```console
nix run nixpkgs#git clone https://github.com/Ruixi-rebirth/flakes.git --extra-experimental-features nix-command --extra-experimental-features flakes
```

step2:

```console
cd flakes; rm -rf .git
```

step3:

```console
nix develop --extra-experimental-features nix-command --extra-experimental-features flakes
```

step4

```console
just disko
```

step5

```console
just install
```
