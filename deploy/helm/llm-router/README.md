# LLM Router Helm Chart

This Helm chart deploys the LLM Router with all required components on Kubernetes.

## Components

- **Router Server**: Triton Server that hosts the router models. Requires GPU.
- **Router Controller**: API server that interacts with LLMs via the Router Server.
- **Demo App**: Sample application for testing the router.

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- GPU nodes with NVIDIA drivers and device plugin for components requiring GPU
- PersistentVolume provisioner support in the underlying infrastructure (for persisting data)

## Building and Deploying

### Build Docker Images

Before installing the chart, you need to build and push the Docker images to a registry accessible by your Kubernetes cluster:

```bash
# Login to NVIDIA Container Registry (requires NVIDIA NGC account)
# This is required for the router-controller image which uses nvcr.io/nvidia/base/ubuntu
docker login nvcr.io

# Build all required images
docker build -t <your-registry>/router-server:latest -f src/router-server/router-server.dockerfile .
docker build -t <your-registry>/router-controller:latest -f src/router-controller/router-controller.dockerfile .
docker build -t <your-registry>/llm-router-client:app -f demo/app/app.dockerfile .

# Push images to your registry
docker push <your-registry>/router-server:latest
docker push <your-registry>/router-controller:latest
docker push <your-registry>/llm-router-client:app
```

> **Note**: When building the router-controller image, make sure that the config.yaml uses environment variable placeholders like `${NVIDIA_API_KEY}` rather than actual API keys. The real keys are provided via Kubernetes secrets.

### Configuration Override

The chart comes with a sample configuration file `values.override.yaml.sample` that you can use as a template. This file contains all the necessary configuration options with placeholder values.

1. Copy the sample file:
```bash
cp values.override.yaml.sample values.override.yaml
```

2. Edit `values.override.yaml` and fill in your specific values:
   - Replace `YOUR_NVIDIA_API_KEY_HERE` with your actual NVIDIA API key
   - Set your preferred storage class (e.g., "standard", "microk8s-hostpath")
   - Configure your image registry (e.g., "localhost:32000/", "docker.io/")
   - Update the model repository and app directory paths
   - Adjust resource limits and requests as needed

> **Important**: Never commit your actual `values.override.yaml` file to version control as it may contain sensitive information. The `.gitignore` file is configured to exclude this file.

### Install the Helm Chart

```bash
# Install the chart
helm install llm-router ./deploy/helm/llm-router -f values.override.yaml

# Verify deployment
kubectl get pods
```

## Configuration

The following table lists key configurable parameters of the LLM Router chart and their default values.

| Parameter | Description | Default |
|-----------|-------------|---------|
| `global.imageRegistry` | Global Docker image registry | `""` |
| `global.imagePullSecrets` | Global Docker image pull secrets | `[]` |
| `global.storageClass` | Global StorageClass for Persistent Volume(s) | `""` |
| `apiKeys.nvidia_api_key` | API key for NVIDIA AI Foundation Models | `""` |
| `routerServer.enabled` | Enable Router Server deployment | `true` |
| `routerServer.resources.limits.nvidia.com/gpu` | GPU resource limits for Router Server | `1` |
| `routerServer.resources.limits.memory` | Memory limits for Router Server | `"8Gi"` |
| `routerServer.shm_size` | Shared memory size for Router Server | `"8G"` |
| `routerController.enabled` | Enable Router Controller deployment | `true` |
| `routerController.service.type` | Service type for Router Controller | `"ClusterIP"` |
| `app.enabled` | Enable Demo App deployment | `true` |
| `app.service.type` | Service type for Demo App | `"ClusterIP"` |
| `ingress.enabled` | Enable ingress for external access | `false` |

For a complete list of configuration options, refer to the `values.override.yaml.sample` file.

## Router Controller Configuration

The Router Controller uses a YAML configuration file to define routing policies and LLM models. The configuration is mounted as a ConfigMap in the deployment.

### Policy Configuration

Each policy in the configuration defines:
- `name`: Unique identifier for the policy
- `url`: Endpoint for the Triton model that handles routing decisions
- `llms`: List of LLM models that can be selected by the router

Example policy configuration:
```yaml
policies:
  - name: "task_router"
    url: http://router-server:8000/v2/models/task_router_ensemble/infer
    llms:
      - name: Brainstorming
        api_base: https://integrate.api.nvidia.com
        api_key: ${NVIDIA_API_KEY}
        model: meta/llama-3.1-70b-instruct
      - name: Chatbot
        api_base: https://integrate.api.nvidia.com
        api_key: ${NVIDIA_API_KEY}
        model: mistralai/mixtral-8x22b-instruct-v0.1
      # ... more LLMs ...
```

### Important Notes

1. The order of LLMs in the policy configuration is crucial as it corresponds to the one-hot encoded vector returned by the Triton model.
2. API keys should be provided via Kubernetes secrets and referenced using environment variables.
3. The configuration supports multiple policies, each with its own set of LLMs and routing model.

## Persistence

The chart mounts volumes for various components:

- Router Server: Model repository
- Demo App: Application directory

## Usage

### With Ingress (Recommended)

If you've enabled ingress in your configuration, you can access the services via domain names:

- **Demo App**: http://llm-router.local/app/
- **Router Controller API**: http://llm-router.local/router-controller/
- **Router Controller Health**: http://llm-router.local/router-controller/health
- **Router Controller Config**: http://llm-router.local/router-controller/config
- **Router Controller Metrics**: http://llm-router.local/router-controller/metrics
- **Router Server Metrics**: http://llm-router.local/router-server/

### Without Ingress (Development)

You can use port-forwarding to access the services locally:

```bash
# Router Controller API
kubectl port-forward svc/llm-router-router-controller 8084:8084

# Demo App
kubectl port-forward svc/llm-router-app 8008:8008

# Router Server (HTTP endpoint)
kubectl port-forward svc/llm-router-router-server 8000:8000
```

## Accessing Services

### Setting up Ingress

1. **For microk8s**: Ingress is already enabled if you see it in `microk8s status`

2. **Enable ingress in your values.override.yaml** (simplified - defaults handle the rest):
```yaml
ingress:
  enabled: true
  hosts:
    - host: llm-router.local  # Change to your domain
```

> **Note**: The chart now includes production-ready ingress defaults with proper path routing and NGINX annotations. No complex configuration needed!

3. **Add host entry to /etc/hosts** (for local testing):
```bash
echo "127.0.0.1 llm-router.local" | sudo tee -a /etc/hosts
``` 