# Java + Gradle + Nix = 💀
I'm trying to get my first realistic Java-Gradle-Nix setup flying.
This does **not** work right now unfortunately. 

## Goal
- Using Java 17
- Spring Boot
- Custom JRE (as small as possible)
- Testcontainers for integration testing with JUnit
- Docker image being built

## Dev station setup
- MacBook Pro 16" 2021; M1 Max; 32 GB RAM
- macOS Sonoma 14.4
- nix-darwin Setup
- linux-builder enabled:
```nix
linux-builder = {
    enable = true;
    ephemeral = true;
    maxJobs = 4;
    config = {
      nix.settings.sandbox = false;
      networking = {
        nameservers = [ "8.8.8.8" "1.1.1.1" ];
      };
      virtualisation = {
        darwin-builder = {
          diskSize = 40 * 1024;
          memorySize = 8 * 1024;
        };
        docker = {
          enable = true;
          rootless = {
            enable = true;
            setSocketVariable = true;
          };
        };
        cores = 6;
      };
    };
  };
```

## Building
In order to build the docker image, I'm running `nix build -vvv .#packages.aarch64-linux.dockerImage --print-out-paths`, because I want to create a docker image to be run on aarch64-linux docker.

## Current problem(s):
### Impurity
I just cannot get any pure solution to work. I just can't 🫠.
