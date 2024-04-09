{
  description = "Inventory Backend Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gradle-dot-nix.url = "github:eeedean/gradle-dot-nix";
  };

  outputs = { self, nixpkgs, flake-utils, gradle-dot-nix, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            (self: super: {
              gradle_8 = super.gradle_8.override {
                java = self.openjdk17;
              };
            })
          ];
        };
        version = "0.0.1-SNAPSHOT";
        inventory-jre = pkgs.stdenv.mkDerivation {
          name = "inventory-jre";
          buildInputs = [ pkgs.openjdk17 ];
          src = self;
          buildPhase = ''
            jlink --add-modules java.base,java.xml --output custom-jre
          '';
          installPhase = ''
            mkdir -p $out
            cp -r custom-jre/* $out/
            chmod +x $out/bin/*
          '';
        };
	gradle-init-script = (import gradle-dot-nix {
                                               inherit pkgs;
                                               gradle-verification-metadata-file = ./gradle/verification-metadata.xml;
                                               unprotected-maven-repos = ''
                                                  [
                                                    "https://repo.maven.apache.org/maven2",
                                                    "https://plugins.gradle.org/m2",
                                                    "https://maven.google.com",
                                                    "https://repo.spring.io/milestone"
                                                  ]
                                               '';
                                             }).gradle-init;
        application = pkgs.stdenv.mkDerivation {
          name = "inventory-backend";
          version = version;
	  src = self;
          buildInputs = [ pkgs.openjdk17 pkgs.gradle_8 ];

          buildPhase = ''
            export GRADLE_USER_HOME=$(mktemp -d)
            gradle clean build --info -I ${gradle-init-script} --offline --full-stacktrace -x test
          '';

          installPhase = ''
            mkdir -p $out
            cp -r build/libs/inventory-backend-${version}.jar $out/
          '';
        };

        dockerImage = pkgs.dockerTools.buildImage {
          name = "inventory-backend";
          tag = "latest";
          created = builtins.substring 0 8 self.lastModifiedDate;
          copyToRoot = [application inventory-jre];

          config = {
            Cmd = [ "${inventory-jre}/bin/java" "-jar" "${application}/inventory-${version}.jar" ];
            ExposedPorts = {
              "8080/tcp" = {};
            };
            Volumes = {
              "/tmp" = {};
            };
          };
        };
      in {
        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.openjdk17 ];
        };

        packages.default = application;
	packages.application = application;

        packages.dockerImage = dockerImage;

        checks.gradletests = pkgs.testers.runNixOSTest {
          name = "Gradle Test: Inventory Backend Stub";

          nodes = {
            machine1 = { pkgs, ... }: {
              environment.systemPackages = [pkgs.openjdk17 pkgs.gradle_8];
              nix.settings.sandbox = false;
              virtualisation.docker.enable = true;

              virtualisation.memorySize = 2 * 1024;
              virtualisation.msize = 128 * 1024;
              virtualisation.cores = 2;
           };
         };

         testScript = ''
           machine1.wait_for_unit("network-online.target")
           machine1.succeed("cp -r ${self}/* .")
           machine1.succeed("gradle test --no-daemon --debug");
         '';
       };
      }
    );
}
