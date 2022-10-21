# proxy-scanner

This folder contains examples on how to deploy and configure Lacework Proxy Scanner.

## Lacework Proxy Scanner Integration

To configure the proxy scanner later on and connect it to your Lacework account a proxy scanner integration needs to be created.
To to so long on to your Lacework account and navigate to Settings -> Container registries -> Add New and select Proxy Scanner, give it a name and save. ([Screenshot Example](lacework-new-container-registries-integration.png))

After the integration is created, select in in the overview and copy the Authorization Token and save it for later use. ([Screenshot Example](lacework-container-registries.png))

Also make sure to note your Lacework accout name. This is the URL to access the Lacework console excluding the `.lacework.net`, for example for the URL `youraccount.fra.lacework.net` the account name is `youraccount.fra`.

For more details follow the official documentation: <https://docs.lacework.com/onboarding/integrate-proxy-scanner#navigate-to-proxy-scanner-integration>.

## Deployment

Proxy Scanner is shipped as container image which can be run on Docker host or Kubernetes (via Helm).
Below you will find some examples how to deploy proxy scanner.

For more details follow the official [Proxy Scanner docs](https://docs.lacework.com/onboarding/integrate-proxy-scanner).

### Docker Deployment

Prerequesits:

- Up to date Docker version installed
- Folder to persist proxy scanner configuration and cache

First create a directory to host the proxy scanner config and cache directory.

```bash
mkdir -p /opt/proxy-scanner/cache
chown -R 1000:65533 /opt/proxy-scanner/cache
```

Once the directories are created with the correct permission, create the default proxy scanner configuration called `config.yml`.

```bash
touch /opt/proxy-scanner/config.yml
```

Add a minimal default configuration to the `config.yml` using an editor of your choice.

```yaml
static_cache_location: /opt/lacework
scan_public_registries: true
lacework:
  account_name: youraccount.fra
  integration_access_token: _123456789abcdef123456789abcd
```

Example file: [config.yml](config.yml)

Now, that we have a configuration, we start the proxy scanner to test its functionality.

```bash
docker run -d  \
    -v /opt/proxy-scanner/config.yml:/opt/lacework/config/config.yml \
    -v /opt/proxy-scanner/cache:/opt/lacework/config/cache \
    -p 8080:8080 -e LOG_LEVEL=debug --name lacework-proxy-scanner lacework/lacework-proxy-scanner:latest
```

Check if the container is up and running.

```bash
docker container ls

CONTAINER ID   IMAGE                                    COMMAND         CREATED          STATUS          PORTS                                       NAMES
06ab7288a1e7   lacework/lacework-proxy-scanner:latest   "sh ./run.sh"   27 seconds ago   Up 26 seconds   0.0.0.0:8080->8080/tcp, :::8080->8080/tcp   lacework-proxy-scanner
```

You can also check the logs using `docker logs lacework-proxy-scanner`.

In order to test if the proxy scanner works we can trigger an on-demand scan using `curl`:

```bash
curl --location --request POST 'localhost:8080/v1/scan' \
--header 'Content-Type: application/json' \
--data-raw '{
    "registry": "index.docker.io",
    "image_name": "library/nginx",
    "tag": "latest"
}'
```

If the output looks like `{"data":"Success.","error":"","ok":true,"status_code":200}` the scan was successful.

### Helm deployment

Prerequesits:

- Up to date Kubernetes cluster
- kubectl and helm CLIs being installed

Laceworks provides are ready to go Helm chart to deploy the proxy scanner on Kubernetes.

First, add the Lacework report to your Helm chart repository:

```bash
helm repo add lacework https://lacework.github.io/helm-charts/
```

To deploy the Helm chart we need to customize the `values.yaml. Due to some limitation of the Helm chart we have to define a default registry.
For this we use public Docker Hub.

All other values of the Helm chart can be left untouched.

```yaml
config:
  static_cache_location: /opt/lacework
  scan_public_registries: true
  lacework:
    account_name: youraccount.fra
    integration_access_token: _123456789abcdef123456789abcd
  default_registry: index.docker.io
  registries:
    - domain: index.docker.io
      name: Docker Hub
      is_public: true
      ssl: true
      auto_poll: false
      disable_non_os_package_scanning: false
      go_binary_scanning:
        enable: true
```

Example file: [values.yaml](values.yaml)

To deploy the proxy-scanner we recommend to deploy it to a seperate namespace called `lacework`.
To do so run the following command.

```bash
helm upgrade --install --create-namespace --namespace lacework \
--values values.yaml \
lacework-proxy-scanner lacework/proxy-scanner
```

To check if the deployment was succesful run the following command:

```bash
kubectl get pods -n lacework

NAME                                      READY   STATUS    RESTARTS   AGE
cluster-lacework-agent-86f5d45cbf-5qf5j   1/1     Running   0          7m25s
lacework-agent-r2twz                      1/1     Running   0          5m42s
lacework-agent-wcxw9                      1/1     Running   0          5m26s
lacework-proxy-scanner-56b5d95cc9-qswgj   1/1     Running   0          10s
```

To check if scanning works simply port-forward port 8080 of the `lacework-proxy-scanner` pod and run quick test via `curl`.

```bash
kubectl -n lacework port-forward lacework-proxy-scanner-56b5d95cc9-qswgj 8080:8080
Forwarding from 127.0.0.1:8080 -> 8080
Forwarding from [::1]:8080 -> 8080

curl --location --request POST 'localhost:8080/v1/scan' \
--header 'Content-Type: application/json' \
--data-raw '{
    "registry": "index.docker.io",
    "image_name": "library/nginx",
    "tag": "latest"
}'
```

If the output looks like `{"data":"Success.","error":"","ok":true,"status_code":200}` the scan was successfull.

## Configuration

Besides the minimal default configuration, which allows scanning of public registries on demand we also want to integrate with private registries like Harbor, ECR, Nexus and others.

Below you will find examples. All of this examples can be appended to the default configurations we used before. Just add another entry to registry.

Based on your deployment you need to either change `config.yml` (Docker-based deployment) or `values.yaml` (Kubernetes-based deployment). We will only include `config.yml` example as the can be easily copied to the `config:` section of the `values.yaml`.

Once you have the configuration updates as per documentetion below, make sure you restart your Docker container (`docker restart lacework-proxy-scanner`) or upgrade your Helm deployment in order for the new configuration to take effect.

For a full overview of all configurations parameters, see: [Configure the Proxy Scanner](https://docs.lacework.com/onboarding/integrate-proxy-scanner#configure-the-proxy-scanner).

### Harbor

In order to set up integration with Harbor a dedicated Harbor user needs to be created and assigned to the project you want integrate with proxy scanner.
When adding the user the role `Limited Guest` has all required permissions. Using a robot user didn't work in my own testing.

Example screenshots:

- [New User](harbor-new-user.png)
- [User Assigned to Project](harbor-assign-user-project.png)

Replace the `domain` value (in this example replacing `registry.harbor.example`) with the FQDN of your Harbor instance.
If Harbor is running on a different port then 443, please append the port like this: `registry.harbor.example:8443`.
Also replace the values of `user_name` and `password` with the previously created user.

```yaml
static_cache_location: /opt/lacework
scan_public_registries: true
lacework:
    account_name: youraccount.fra
    integration_access_token: _123456789abcdef123456789abcd
default_registry: index.docker.io
registries:
  - domain: index.docker.io
    name: Docker Hub
    is_public: true
    ssl: true
    auto_poll: false
    disable_non_os_package_scanning: false
    go_binary_scanning:
        enable: true
  - domain: registry.harbor.example
    name: Harbor
    ssl: true
    is_public: false
    auto_poll: false
    credentials:
        user_name: "proxy-scanner"
        password: "Proxyscanner1"
    notification_type: harbor
    disable_non_os_package_scanning: false
    go_binary_scanning:
        enable: true
```

Example file: [config-harbor.yml](config-harbor.yml)

Now that the proxy scanner is able to communicate with the Harbor registry, we need to set up a webhook in Harbor to tell the proxy-scanner when a new container image is published so that it will be scanned for vulnerabilites.

To do so create a webhook in the project you want to trigger vulnerability scans when a new container image is published.
The configuration of the webhook should look like this:

- Name: of your choise
- Notify Type: http
- Event Type: Artifact pushed
- Endpoint URL: <http://proxy-scanner-fqdn:8080/v1/notification?registry_name=Harbor>

For the Endpoint URL make sure the `registry_name` value is the same as configured in the proxy-scanner configuration.

[Example Screenshot](harbor-webhook.png)

To test if the configuration was succesful have a look at the proxy scanner logs (for example, `docker logs lacework-proxy-scanner -f`) while pushing a new image. You should see a new scan being triggered
Also, the results of the scan should be visible within Lacework, see [screenhot example](lacework-proxy-scanner-habor-result.png).
You can search for the FQDN of your Harbor instance and/or request source matches "proxy_scanner".
