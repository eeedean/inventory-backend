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

### Error
Trying to build the image as described above, it actually fails, because Testcontainers wouldn't find a valid Docker environment when building for aarch64. 

Even adding a working docker environment to my linux-builder did not do the trick.  

**Error log:** 

```log
 2024-03-18T14:39:38.826Z ERROR 3789 --- [    Test worker] o.t.d.DockerClientProviderStrategy       : Could not find a valid Docker environment. Please check configuration. Attempted configurations were:
    As no valid configuration was found, execution cannot continue.
    See https://www.testcontainers.org/on_failure.html for more details.
    2024-03-18T14:39:39.831Z ERROR 3789 --- [    Test worker] com.zaxxer.hikari.pool.HikariPool        : HikariPool-1 - Exception during pool initialization.

    java.lang.IllegalStateException: Could not find a valid Docker environment. Please see logs and check configuration
        at org.testcontainers.dockerclient.DockerClientProviderStrategy.lambda$getFirstValidStrategy$7(DockerClientProviderStrategy.java:256)
        at java.base/java.util.Optional.orElseThrow(Optional.java:403)
        at org.testcontainers.dockerclient.DockerClientProviderStrategy.getFirstValidStrategy(DockerClientProviderStrategy.java:247)
        at org.testcontainers.DockerClientFactory.getOrInitializeStrategy(DockerClientFactory.java:150)
        at org.testcontainers.DockerClientFactory.client(DockerClientFactory.java:186)
        at org.testcontainers.DockerClientFactory$1.getDockerClient(DockerClientFactory.java:104)
        at com.github.dockerjava.api.DockerClientDelegate.authConfig(DockerClientDelegate.java:108)
        at org.testcontainers.containers.GenericContainer.start(GenericContainer.java:321)
        at org.testcontainers.jdbc.ContainerDatabaseDriver.connect(ContainerDatabaseDriver.java:134)
        at com.zaxxer.hikari.util.DriverDataSource.getConnection(DriverDataSource.java:138)
        at com.zaxxer.hikari.pool.PoolBase.newConnection(PoolBase.java:359)
        at com.zaxxer.hikari.pool.PoolBase.newPoolEntry(PoolBase.java:201)
        at com.zaxxer.hikari.pool.HikariPool.createPoolEntry(HikariPool.java:470)
        at com.zaxxer.hikari.pool.HikariPool.checkFailFast(HikariPool.java:561)
        at com.zaxxer.hikari.pool.HikariPool.<init>(HikariPool.java:100)
        at com.zaxxer.hikari.HikariDataSource.getConnection(HikariDataSource.java:112)
```
