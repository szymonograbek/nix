{
  description = "Szymon nix-darwin system flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin/master";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";
  };

  outputs = inputs@{ self, nix-darwin, nixpkgs, nix-homebrew }:
  let
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
          pkgs.claude-code
          pkgs.tmux
          pkgs.yaak
          pkgs.localsend
      ];

      nix.settings.experimental-features = "nix-command flakes";

      programs.fish.enable = true;

      # Set Git commit hash for darwin-version.
      system.configurationRevision = self.rev or self.dirtyRev or null;

      # Used for backwards compatibility, please read the changelog before changing.
      # $ darwin-rebuild changelog
      system.stateVersion = 6;

      nixpkgs.hostPlatform = "aarch64-darwin";

      system.primaryUser = "szymonograbek";

      homebrew = {
        enable = true;

        brews = [
          "mas"
        ];
        
        casks = [
          "the-unarchiver"
          "mos"
          "bluesnooze"
          "expo-orbit"
          "cursor"
          "raycast"
          "1password"
          "ghostty"
          "notion-calendar"
          "spotify"
          "zen"
          "claude"
        ];

        masApps = {
          "JOMO" = 1609960918;
        };

        onActivation.autoUpdate = true;
      };

      system = {
        defaults = {
          NSGlobalDomain = {
            AppleShowAllExtensions = true;

            KeyRepeat = 2; 
            InitialKeyRepeat = 15;
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
            user = "szymonograbek";
            autoMigrate = true;
          };
        }
      ];
    };
  };
}
