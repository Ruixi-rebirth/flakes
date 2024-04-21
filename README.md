step0:

```
> Enter the nixos livecd environment
```

step1:

```console
$ nix run nixpkgs#git clone https://github.com/Ruixi-rebirth/flakes.git --extra-experimental-features nix-command --extra-experimental-features flakes
```

step2:

```console
$ cd flakes; rm -rf .git
```

step3:

```console
$ nix develop --extra-experimental-features nix-command --extra-experimental-features flakes
```

step4

```console
$ just disko
```

step5

```console
$ just install
```
