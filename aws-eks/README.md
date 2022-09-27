# aws-eks

To deploy the Lacework agent to an EKS cluster the offical Helm chart is recommended: <https://docs.lacework.com/onboarding/deploy-on-kubernetes#install-using-helm>.

```bash
helm upgrade --install --namespace lacework --create-namespace -f values.yaml lacework-agent lacework/lacework-agent
```

See [values.yaml](values.yaml) for example configuration.

Make sure to replace everything within angle brackets `<...>` with correct values.
