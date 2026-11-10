eval "$(/opt/homebrew/bin/brew shellenv)"

# Java 21
export JAVA_HOME="/opt/homebrew/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"

# Maven
export M2_HOME=/opt/homebrew/opt/maven
export MAVEN_HOME=$M2_HOME
export PATH="$M2_HOME/bin:$PATH"

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/anaconda3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/opt/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# local user binaries
export PATH="$HOME/.local/bin:$PATH"


if [ -f "$HOME/.bash_secrets" ]; then
  . "$HOME/.bash_secrets"
fi

# Rust (rustup from Homebrew is keg-only; ~/.cargo/bin holds `cargo install` binaries)
export PATH="/opt/homebrew/opt/rustup/bin:$HOME/.cargo/bin:$PATH"
