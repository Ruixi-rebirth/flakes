set -e

cd /mnt/etc/nixos/Flakes

function set_user_passwd {
    echo $'\e[1;32mset your user login password\e[0m'
    passwd_hash=$(mkpasswd -m sha-512  2>/dev/null)
}
while true; do
    echo "The partition is now complete, please select the device you wish to install:"
    echo "1. k-on"
    echo "2. minimal"
    read -p  $'\e[1;32mEnter your choice(number): \e[0m' -r device

    case $device in
        1)
            set_user_passwd
            sed -i "/initialHashedPassword/c\ \ \ \ initialHashedPassword\ =\ \"$passwd_hash\";" ./modules/core.nix
            nixos-install --no-root-passwd --flake .#k-on
            break ;;
        2)
            set_user_passwd
            sed -i "/initialHashedPassword/c\ \ \ \ initialHashedPassword\ =\ \"$passwd_hash\";" ./modules/core.nix
            nixos-install --no-root-passwd --flake .#minimal
            break ;;
        *)
            echo "Invalid choice, please try again."
            ;;
    esac
done
