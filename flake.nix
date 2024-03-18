{
  description = "Inventory Backend Flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
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
        application = pkgs.stdenv.mkDerivation {
          # disabling sandbox
          __noChroot = true;
          name = "inventory-backend";
          src = self;
          version = version;
          buildInputs = [ pkgs.openjdk17 ];

          buildPhase = ''
            export GRADLE_USER_HOME=$(mktemp -d)
            chmod +x ./gradlew
            ./gradlew clean build --info
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

        packages.dockerImage = dockerImage;

        defaultPackage = self.packages.default;

      }
    );
}
