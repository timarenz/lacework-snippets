# aws-ecs-fargate

This repo contains example how to integrate the Lacework agent (datacollector) with ECS fargate tasks.

For all exmples we use the offical nginx container images:

- nginx:1.23.1
- nginxinc/nginx-unprivileged:1.23.1

Everything is based on the official Lacework documentation on [AWS ECS Fargate](https://docs.lacework.com/onboarding/aws-ecs-fargate)

## Check if your container runs as root or non-root

You can check if you are running a non-root container application using the command below:

```bash
docker pull nginxinc/nginx-unprivileged:1.23.1
docker image inspect nginxinc/nginx-unprivileged:1.23.1  --format='{{json .Config.User}}'
"101"
```

If there is an output like in our example `101` this means the application in the container runs as non-root (unpriviledged) user.
If there is no output (`""`) that typically means the container application runs as root.

## Extract `ENTRYPOINT` and `CMD`

In order to integrate the Lacework agent (embedded or sidecar) the default parameters for `ENTRYPOINT` and `CMD` need to be extracted.
This is required as those need to be modified to include the Lacework agent entrypoint.

```bash
docker image inspect nginxinc/nginx-unprivileged:1.23.1 --format='{{json .Config.Entrypoint}}'
["/docker-entrypoint.sh"]

docker image inspect nginxinc/nginx-unprivileged:1.23.1 --format='{{json .Config.Cmd}}'
["nginx","-g","daemon off;"]
```

## Implement patterns

Based on if your container runs as priviledge (root) or unpriviliedged (non-root) container there are different ways to do the integration.
In general there is the possibility to embed the agent or run it as sidecar.

Embedding the agent always requires you to modify the existing container image and publish a new one.
The benefit is that you only need to deploy a single container and the ECS task configuration is simplier.
However, updating the Lacework agent requires you to update and publish a new container image.

The sidecar pattern differs a bit from the traditional sidecar pattern. In our case the sidecar container acts as volume mount but the Lacework agent runs as process in the primary/main container.
Typically this doesn't require any modification of the primary container image (in this example, nginx) with the excption of non-root containers which we cover later.
Also, updating the Lacework agent doesn't require to rebuild the primary container image.
However, a higher level modification of the ECS task definition is required.

## Implementation examples

Below you will find implementation examples for all four patterns.

### Root container with embedded agent

Embedding the Lacework agent for ECS Fargate for a container that runs root is quite simple.
Create Dockerfile for a multi-stage build that copies the Lacework agent binaries and prepend the `ENTRYPOINT` parameter with the Lacework agent start script `"/var/lib/lacework-backup/lacework-sidecar.sh"`.

```Dockerfile
FROM lacework/datacollector:latest-sidecar AS agent-build-image

FROM nginx:1.23.1

COPY --from=agent-build-image /var/lib/lacework-backup /var/lib/lacework-backup

ENTRYPOINT ["/var/lib/lacework-backup/lacework-sidecar.sh","/docker-entrypoint.sh"]
CMD ["nginx","-g","daemon off;"]
```

Example file: [Dockerfile-root-embedded](Dockerfile-root-embedded)

The ECS task definition needs to be adjusted to use the updated image and the environment variables `LaceworkServerUrl` and `LaceworkAccessToken` need to be set to configure the Lacework agent.

```json
            "image": "timarenz/nginx:root-embedded",
            "environment": [
                {
                    "name": "LaceworkAccessToken",
                    "value": "abcdef"
                },
                {
                    "name": "LaceworkServerUrl",
                    "value": "https://api.fra.lacework.net"
                }
            ]
```

Example file: [nginx-root-embedded.json](nginx-root-embedded.json)

### Root container with "sidecar" agent

For the sidecar pattern with a root container only the ECS task defintiion needs to be update.

The `entryPoint` parameter needs to be set and include the entrypoint script of the Lacework agent (`/var/lib/lacework-backup/lacework-sidecar.sh`) and the original entrypoint script (`/docker-entrypoint.sh`).
Also `command` parameter needs to be set to the original `CMD` value.
Then the environment variables `LaceworkAccessToken` and `LaceworkServerUrl` need to be set to configure the Lacework agent.
In order to be able to read the Lacework agent entrypoint script and succesfully run it the Lacework agent container needs to be mapped as volume and a dependecy needs to be set (see example below).
Last the Lacework agent needs to added as non essential container as well.

```json
            "entryPoint": [
                "/var/lib/lacework-backup/lacework-sidecar.sh",
                "/docker-entrypoint.sh"
            ],
            "command": [
                "nginx",
                "-g",
                "daemon off;"
            ],
            "environment": [
                {
                    "name": "LaceworkAccessToken",
                    "value": "abcdef"
                },
                {
                    "name": "LaceworkServerUrl",
                    "value": "https://api.fra.lacework.net"
                }
            ],
            "volumesFrom": [
                {
                    "sourceContainer": "datacollector-sidecar",
                    "readOnly": true
                }
            ],
            "dependsOn": [
                {
                    "containerName": "datacollector-sidecar",
                    "condition": "SUCCESS"
                }
            ]
        },
        {
            "essential": false,
            "name": "datacollector-sidecar",
            "image": "lacework/datacollector:latest-sidecar"
        }
```

Example file: [nginx-root-sidecar.json](nginx-root-sidecar.json)

### Non-root container with embedded agent

In order to embed the Lacework agent in a non-root container a new container needs to be build that embeds the Lacework agent and passwordless sudoless for the container user needs to be enabled.

In that Dockerfile we switch back the context to the root user and then install sudo and add the username for the UID `101` used by the container.
Then we switch back the context to that user `101`.
To finish up we need to adjust the entrypoint to run the Lacework agent start script as root (the actuall process will later run as UID `101`) and add the old `ENTRYPOINT` as parameters as per the example below.

```Dockerfile
FROM lacework/datacollector:latest-sidecar AS agent-build-image

FROM nginxinc/nginx-unprivileged:1.23.1

COPY --from=agent-build-image /var/lib/lacework-backup /var/lib/lacework-backup

USER root

RUN apt-get update && apt-get install -y sudo && \
    usermod -aG sudo $(id -nu 101) && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER 101

ENTRYPOINT ["sh","-c","sudo -E /var/lib/lacework-backup/lacework-sidecar.sh && /docker-entrypoint.sh nginx -g 'daemon off;'"]
```

Example file: [Dockerfile-nonroot-embedded](Dockerfile-nonroot-embedded)

After the image is build and published we need to add the linux capability `SYS_PTRACE` and configured it using the environment variables `LaceworkAccessToken` and `LaceworkServerUrl` in the ECS task config.
Also the newly build image needs to be used.

```json
            "image": "timarenz/nginx:nonroot-embedded",
            "environment": [
                {
                    "name": "LaceworkAccessToken",
                    "value": "abcdef"
                },
                {
                    "name": "LaceworkServerUrl",
                    "value": "https://api.fra.lacework.net"
                }
            ],
            "linuxParameters": {
                "capabilities": {
                    "add": [
                        "SYS_PTRACE"
                    ]
                }
            }
```

Example file: [nginx-nonroot-embedded.json](nginx-nonroot-embedded.json)

### Non-root container with sidecar agent

Another way of running the Lacework agent in a non-root container is using a `sidecar` pattern.
However, the non-root container image still needs to be modified in order to allow passwordless sudo.

For this we build a new container.
In that Dockerfile we switch back the context to the root user and then install sudo and add the username for the UID `101` used by the container.
Then we switch back the context to that user `101`.

```Dockerfile
FROM nginxinc/nginx-unprivileged:1.23.1

USER root

RUN apt-get update && apt-get install -y sudo && \
    usermod -aG sudo $(id -nu 101) && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER 101
```
Example file: [Dockerfile-nonroot-sidecar](Dockerfile-nonroot-sidecar)

After the new container image is build we need to update the ECS task definition.
The `entryPoint` parameter needs to be updated as per the embedded non-root pattern. Also ``
Then the environment variables `LaceworkAccessToken` and `LaceworkServerUrl` need to be set to configure the Lacework agent.
In order to be able to read the Lacework agent entrypoint script and succesfully run it the Lacework agent container needs to be mapped as volume and a dependecy needs to be set (see example below).
Last the Lacework agent needs to added as non essential container as well.

```json
            "image": "timarenz/nginx:nonroot-sidecar",
            "entryPoint": [
                "sh",
                "-c",
                "sudo -E /var/lib/lacework-backup/lacework-sidecar.sh && /docker-entrypoint.sh nginx -g 'daemon off;'"
            ],
            "environment": [
                {
                    "name": "LaceworkAccessToken",
                    "value": "abcdef"
                },
                {
                    "name": "LaceworkServerUrl",
                    "value": "https://api.fra.lacework.net"
                }
            ],
            "linuxParameters": {
                "capabilities": {
                    "add": [
                        "SYS_PTRACE"
                    ]
                }
            },
            "volumesFrom": [
                {
                    "sourceContainer": "datacollector-sidecar",
                    "readOnly": true
                }
            ],
            "dependsOn": [
                {
                    "containerName": "datacollector-sidecar",
                    "condition": "SUCCESS"
                }
            ]
        },
        {
            "essential": false,
            "name": "datacollector-sidecar",
            "image": "lacework/datacollector:latest-sidecar"
        }
```

Example file: [nginx-nonroot-sidecar.json](nginx-nonroot-sidecar.json)

### Non-root container running as root with sidecar agent

With some containers that by default run as non-root it is also supported to run them as root. 
In this case not modification of the image is required and it can be deployed as sidecar pattern.
In addition to the adjustemsn required in the ECS task definition for running the agent as sidecar one just needs to set the `user` parameter to `root`.

```json
            "user": "root",
            "entryPoint": [
                "/var/lib/lacework-backup/lacework-sidecar.sh",
                "/docker-entrypoint.sh"
            ],
            "command": [
                "nginx",
                "-g",
                "daemon off;"
            ],
            "environment": [
                {
                    "name": "LaceworkAccessToken",
                    "value": "abcdef"
                },
                {
                    "name": "LaceworkServerUrl",
                    "value": "https://api.fra.lacework.net"
                }
            ],
            "volumesFrom": [
                {
                    "sourceContainer": "datacollector-sidecar",
                    "readOnly": true
                }
            ],
            "dependsOn": [
                {
                    "containerName": "datacollector-sidecar",
                    "condition": "SUCCESS"
                }
            ]
        },
        {
            "essential": false,
            "name": "datacollector-sidecar",
            "image": "lacework/datacollector:latest-sidecar"
        }
    ],
```
Example file: [nginx-nonrootasroot-sidecar.json](nginx-nonrootasroot-sidecar.json)