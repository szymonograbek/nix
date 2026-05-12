{
  description = "Szymon nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    brew-src = {
      url = "github:Homebrew/brew/5.1.10";
      flake = false;
    };
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew, brew-src }:
  let
    # PyPI CLI tools installed via `uv tool install` on activation.
    # Add a package name to the list and run `darwin-rebuild switch`.
    pythonTools = [
    ];

    # Bun global packages installed via `bun add -g` on activation.
    # Add a package name (optionally `name@version`) and run `darwin-rebuild switch`.
    bunTools = [
      "eas-cli"
      "@earendil-works/pi-coding-agent"
      "mcporter"
    ];

    primaryUser = "szymonograbek";

    configuration = { pkgs, ... }: {
      nixpkgs.config.allowUnfree = true;

      # List packages installed in system profile. To search by name, run:
      # $ nix-env -qaP | grep wget
      environment.systemPackages = [
          pkgs.neovim
          pkgs.obsidian
          pkgs.aerospace
          pkgs.bun
          pkgs.fish
          pkgs.nodejs_24
          pkgs.ruby
          pkgs.git
          pkgs.tmux
          pkgs.yaak
          pkgs.localsend
          pkgs.starship
          pkgs.zoxide
          pkgs.devenv
          pkgs.cocoapods
          pkgs.pnpm
          pkgs.opam
          pkgs.zulu17
          pkgs.ffmpeg
          pkgs.corepack
          pkgs.ripgrep
          pkgs.fzf
          pkgs.rustup
          pkgs.google-cloud-sdk
          pkgs.uv
      ];

      system.activationScripts.postActivation.text = ''
        echo "installing PyPI CLI tools via uv..."
        UV=${pkgs.uv}/bin/uv
        SUDO_UV="/usr/bin/sudo -u ${primaryUser} -H $UV"
        declared="${builtins.concatStringsSep " " pythonTools}"

        # Normalize declared specs to base package names (strip extras + version constraints)
        declared_names=""
        for spec in $declared; do
          name=$(echo "$spec" | ${pkgs.gnused}/bin/sed -E 's/\[.*\]//; s/[<>=!~].*//')
          declared_names="$declared_names $name"
        done

        for spec in $declared; do
          $SUDO_UV tool install --quiet "$spec" || true
        done

        # Prune tools no longer declared
        installed=$($SUDO_UV tool list 2>/dev/null | ${pkgs.gawk}/bin/awk '/^[A-Za-z0-9]/ {print $1}')
        for tool in $installed; do
          case " $declared_names " in
            *" $tool "*) ;;
            *) echo "pruning uv tool: $tool"; $SUDO_UV tool uninstall "$tool" || true ;;
          esac
        done

        echo "installing bun global packages..."
        BUN=${pkgs.bun}/bin/bun
        SUDO_BUN="/usr/bin/sudo -u ${primaryUser} -H $BUN"
        bun_declared="${builtins.concatStringsSep " " bunTools}"

        # Normalize declared specs to base package names (strip @version, keep scope)
        bun_declared_names=""
        for spec in $bun_declared; do
          case "$spec" in
            @*) name=$(echo "$spec" | ${pkgs.gnused}/bin/sed -E 's/^(@[^/]+\/[^@]+).*/\1/') ;;
            *)  name=$(echo "$spec" | ${pkgs.gnused}/bin/sed -E 's/@.*//') ;;
          esac
          bun_declared_names="$bun_declared_names $name"
        done

        for spec in $bun_declared; do
          $SUDO_BUN add -g "$spec" || true
        done

        echo "upgrading bun global packages..."
        $SUDO_BUN update -g || true

        # Prune globals no longer declared (read top-level deps from global manifest)
        bun_manifest="/Users/${primaryUser}/.bun/install/global/package.json"
        if [ -f "$bun_manifest" ]; then
          installed_bun=$(/usr/bin/sudo -u ${primaryUser} -H ${pkgs.jq}/bin/jq -r '.dependencies // {} | keys[]' "$bun_manifest" 2>/dev/null)
          for entry in $installed_bun; do
            case " $bun_declared_names " in
              *" $entry "*) ;;
              *) echo "pruning bun global: $entry"; $SUDO_BUN remove -g "$entry" || true ;;
            esac
          done
        fi
      '';

      nix.settings.experimental-features = "nix-command flakes";

      programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      nixpkgs.hostPlatform = "aarch64-darwin";

      system.primaryUser = primaryUser;

      homebrew = {
        enable = true;

        taps = [
          "tw93/tap"
          "atlassian/homebrew-acli"
        ];

        brews = [
          "mas"
          "direnv"
          "mole"
          "watchman"
          "yt-dlp"
          "gh"
          "atlassian/homebrew-acli/acli"
          "jj"
          "dmmulroy/tap/jj-starship"
        ];
        
        casks = [
          "the-unarchiver"
          "mos"
          "bluesnooze"
          "expo-orbit"
          "raycast"
          "1password"
          "ghostty"
          "notion-calendar"
          "tailscale-app"
          "spotify"
          "zen"
          "claude"
          "android-studio"
          "visual-studio-code"
          "slack"
          "google-chrome"
          "telegram"
          "claude-code@latest"
          "localsend"
          "figma"
          "cmux"
          "orbstack"
        ];

        masApps = {};

        onActivation.autoUpdate = true;
        onActivation.cleanup = "zap";
        onActivation.upgrade = true;
      };

      system = {
        defaults = {
          NSGlobalDomain = {
            AppleShowAllExtensions = true;

            KeyRepeat = 2; 
            InitialKeyRepeat = 15;
            #"com.apple.mouse.tapBehavior" = 1;
          };

          dock = {
            tilesize = 48;
            autohide = true;
          };
        };
      };
    };
  in
  {
    # Build darwin flake using:
    # $ darwin-rebuild build --flake .#-macbook-Szymon
    darwinConfigurations."macbook-Szymon" = nix-darwin.lib.darwinSystem {
      modules = [ 
        configuration
        nix-homebrew.darwinModules.nix-homebrew
        {
          nix-homebrew = {
            enable = true;
            enableRosetta = true;
            user = primaryUser;
            autoMigrate = true;
            package = brew-src // {
              name = "brew-5.1.10";
              version = "5.1.10";
            };
          };
        }
      ];
    };
  };
}
