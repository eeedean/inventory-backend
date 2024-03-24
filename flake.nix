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
        applicationSource = pkgs.stdenv.mkDerivation {
          name = "inventory-backend-src";
          src = self;
          version = version;
          installPhase = ''
            mkdir -p $out
            cp -r ./* $out/
          '';
        };
        application = pkgs.stdenv.mkDerivation {
          # disabling sandbox
          __noChroot = true;
          name = "inventory-backend";
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

        checks.gradletests = pkgs.testers.runNixOSTest {
          name = "Gradle Test: Inventory Backend Stub";

          nodes = {
            machine1 = { pkgs, ... }: {
              environment.systemPackages = [pkgs.openjdk17 applicationSource];
              nix.settings.sandbox = false;
              virtualisation.docker.enable = true;

              virtualisation.memorySize = 2 * 1024;
              virtualisation.msize = 128 * 1024;
              virtualisation.cores = 2;
           };
         };

         testScript = ''
           machine1.wait_for_unit("network-online.target")
           machine1.execute("cp -r ${applicationSource}/* ${applicationSource}/.* .")
           machine1.execute("java -version")
           machine1.succeed("./gradlew test --no-daemon --debug");
         '';
       };
      }
    );
}
