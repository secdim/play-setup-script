#!/bin/sh
set -e

# SecDim Quick Setup Script
# Version 1.0
# https://www.secdim.com

SSH_API="https://id.secdim.com/account/set-ssh-key/?service=default"
SSH_KEY_DEFAULT="${HOME}/.ssh/id_rsa.pub"
HOMEBREW_PREFIX="/usr/local/homebrew/bin"

# ------------------------------------------------------------------------
# https://github.com/client9/shlib - portable posix shell functions
# Public domain - http://unlicense.org
# https://github.com/client9/shlib/blob/master/LICENSE.md
# but credit (and pull requests) appreciated.
# ------------------------------------------------------------------------

is_command() {
  command -v "$1" >/dev/null
}

echo_stderr() (
  echo "$@" 1>&2
)

# ------------------------------------------------------------------------
# End of functions from https://github.com/client9/shlib
# ------------------------------------------------------------------------

is_required_tools_installed() {
    if is_command docker; then
        if is_command git; then
            if is_command make; then
                return
            fi
        fi
    fi
    false
}

is_wsl() {
	case "$(uname -r)" in
	*microsoft* ) true ;; # WSL 2
	*Microsoft* ) true ;; # WSL 1
	* ) false;;
	esac
}

is_darwin() {
	case "$(uname -s)" in
	*darwin* ) true ;;
	*Darwin* ) true ;;
	* ) false;;
	esac
}

is_linux() {
	case "$(uname -s)" in
	*linux* ) true ;;
	*Linux* ) true ;;
	* ) false;;
	esac
}

log_error() {
    echo_stderr "[e]" "${@}"
}

log_info() {
    echo_stderr "[i]" "${@}"
}

log_warn() {
    echo_stderr "[w]" "${@}"
}

ask () {
    printf "[?] %s: " "${@}"
}

success() {
    log_info "You can always update your SSH key on https://id.secdim.com"
    log_info "Setup is successfully completed"
    log_info "Go to https://play.secdim.com and have fun!"
    exit 0
}

failure () {
    log_error "There was an error in setting up your environment"
    log_error "Try the manual setup by using the following guide:"
    log_error "https://discuss.secdim.com/t/new-introductory-video-for-play-challenges/235"
    exit 1
}


upload_ssh_key() {
    log_info "Adding your default SSH public key to your SecDim ID"
    # Generate SSH key if default not exist
    if [ ! -f "${SSH_KEY_DEFAULT}" ]; then
        log_info "Generate a pair of SSH keys"
        ssh-keygen -b 4096 -t rsa -f "${SSH_KEY_DEFAULT%????}" -q -N ""
    fi
    log_info "Using default SSH public key: ${SSH_KEY_DEFAULT}"
    SSH_KEY="${SSH_KEY:-$SSH_KEY_DEFAULT}"
    log_info "Next, please enter your SecDim ID username and password"
    # Upload the SSH key
    ask "Enter your SecDim ID username"
    read -r USERNAME
    if ! curl -X POST --fail --silent --show-error -u "${USERNAME}" -F "key=<${SSH_KEY}" "${SSH_API}"; then
        log_error "There was an error in adding your SSH key to your SecDim ID"
        log_error "You can try to manually add it on https://id.secdim.com"
        ask "Do you want to add your SSH key manually? (n)"
        read -r answer
        answer="${answer:-n}"
        case $answer in
            [Yy]* ) ;;
            [Nn]* ) upload_ssh_key;;
        esac
    fi
}

check_ssh_connection () {
    log_info "Checking SSH connection"
    if ! ssh -q -T git@game.secdim.com > /dev/null 2>/dev/null; then
        log_error "Could not establish SSH connection"
        log_error "Please review if you have added your default SSH public key"
        log_error "If you have used non-default SSH public key, make sure it's been added to 'ssh-agent'"
        ask "Try again? (y)"
        read -r answer
        answer="${answer:-y}"
        case $answer in
            [Yy]* ) check_ssh_connection;;
            [Nn]* ) failure;;
        esac
    fi
}

ask_have_secdim_id () {
    ask "Have you registered on https://id.secdim.com? (y)"
    read -r answer
    answer="${answer:-y}"
    case $answer in
        [Yy]* ) ;;
        [Nn]* )
            log_info "Go to https://id.secdim.com and register an account"
            log_info "Once you are done, press Enter to continue ..."
            read -r answer;;
    esac
}

ask_login_oauth () {
    ask "Have you signed in using GitHub or GitLab? (n)"
    read -r answer
    answer="${answer:-n}"
    case $answer in
        [Yy]* )
            log_info "Go to https://id.secdim.com, add or import your SSH public key"
            log_info "Once you are done, press Enter to continue ..."
            read -r answer;;
        [Nn]* ) upload_ssh_key;;
    esac
}

ask_add_ssh_key () {
    ask "Have you added your SSH public key? (y)"
    read -r answer
    answer="${answer:-y}"
    case $answer in
        [Yy]* ) ;;
        [Nn]* ) ask_login_oauth;;
    esac
}

# Main

echo_stderr ""
echo_stderr "Welcome to SecDim Quick Setup Script v1.0"
echo_stderr "This script will prepare your host to use SecDim Play"
echo_stderr ""

ask_have_secdim_id
ask_add_ssh_key
check_ssh_connection
ask "Continue to install local development tools: git, make and docker? (y)"
read -r answer
answer="${answer:-y}"
case $answer in
    [Yy]* ) ;;
    [Nn]* ) success;;
esac

if is_wsl; then
    log_warn "WSL detected"
    log_warn "Support for WSL is EXPERIMENTAL. Please follow the below guide for manual setup."
    log_warn "https://discuss.secdim.com/t/new-introductory-video-for-play-challenges/235"
    echo_stderr ""

    if ! is_command make || ! is_command git; then
        log_info "Installing make and git"
        if ! sudo apt-get update || ! sudo apt-get install -y make git; then
            log_error "Something went wrong with 'git' and 'make' installation"
            log_error "Install 'git' and 'make' manually"
            log_error "And then run this script again"
            exit 1
        fi
    fi
    if ! is_command docker; then
        log_info "Docker need to be installed"
        log_info "Follow https://docs.docker.com/desktop/windows/wsl/"
        log_info "And then run this script again"
        exit 1
    fi
    if is_required_tools_installed; then
        log_info "You have all required tools installed"
        success
    fi
fi

if is_linux; then
    log_info "Linux detected"
    if ! is_command make || ! is_command git; then
        log_info "Installing make and git"
        if ! sudo apt-get update || ! sudo apt-get install -y make git; then
            log_error "Something went wrong with 'git' and 'make' installation"
            log_error "Install 'git' and 'make' manually"
            log_error "And then run this script again"
            exit 1
        fi
    fi

    if ! is_command docker; then
        log_info "Installing docker"
        if ! curl -fsSL https://get.docker.com/ | sh; then
            log_error "Something went wrong with 'docker' installation"
            log_error "Follow https://docs.docker.com/engine/install/ubuntu/ to install 'docker'"
            log_error "And then run this script again"
            exit 1
        fi
        if ! sudo usermod -aG docker "${USER}"; then
            log_error "Could not add ${USER} to docker group"
            log_error "You need to run future commands using 'sudo'"
        fi
        log_info "Logout and login to linux for the docker permission to take effect"
    fi

    if is_required_tools_installed; then
        log_info "You have all required tools installed"
        success
    fi
fi

if is_darwin; then
    log_info "OSX detected"
    if ! is_command brew; then
        log_info "Installing Homebrew"
        if ! bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
            log_error "Something went wrong with Homebrew installation"
            log_error "Follow https://brew.sh/ to install Homebrew"
            log_error "And then run this script again"
            exit 1
        fi
    fi

    if [ "$(uname -m)" = 'arm64' ]; then
            export HOMEBREW_PREFIX="/opt/homebrew/bin"
        else
            export HOMEBREW_PREFIX="/usr/local/homebrew/bin"
        fi

    if ! is_command make; then
        log_info "Installing make"
        if ! "${HOMEBREW_PREFIX}/brew" install make; then
            log_error "Something went wrong with 'make' installation"
            log_error "Install 'make' manually"
            log_error "And then run this script again"
            exit 1
        fi
    fi

    if ! is_command git; then
        log_info "Installing git"
        if ! "${HOMEBREW_PREFIX}/brew" install git; then
            log_error "Something went wrong with 'git' installation"
            log_error "Install 'git' manually"
            log_error "And then run this script again"
            exit 1
        fi
    fi

    if ! is_command docker; then
        log_info "Installing docker"
        if ! "${HOMEBREW_PREFIX}/brew" install --cask docker; then
            log_error "Something went wrong with 'docker' installation"
            log_error "Follow https://docs.docker.com/desktop/install/mac-install/ to install 'docker'"
            log_error "And then run this script again"
            exit 1
        else
            log_info "Opening /Applications/Docker.app to complete the installation"
            open /Applications/Docker.app
        fi
    fi

    if is_required_tools_installed; then
        log_info "You have all required tools installed"
        success
    else
        case "${SHELL}" in
            */bash*)
                if [ -r "${HOME}/.bash_profile" ]
                then
                shell_profile="${HOME}/.bash_profile"
                else
                shell_profile="${HOME}/.profile"
                fi
                ;;
            */zsh*)
                shell_profile="${HOME}/.zprofile"
                ;;
            *)
                shell_profile="${HOME}/.profile"
                ;;
        esac
        log_info "RUN THE FOLLOWING TWO COMMANDS in your terminal to set the tools path"
        log_info "echo 'eval \"\$(${HOMEBREW_PREFIX}/brew shellenv)\"' >> ${shell_profile}"
        log_info "eval \"\$(${HOMEBREW_PREFIX}/brew shellenv)\""
        success
    fi
fi
