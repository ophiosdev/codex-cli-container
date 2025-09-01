# Codex CLI Container<!-- omit from toc -->

- [Container Architecture](#container-architecture)
- [Building the Container Image](#building-the-container-image)
  - [Build Arguments](#build-arguments)
- [Authentication Setup](#authentication-setup)
  - [Using OPENAI_API_KEY](#using-openai_api_key)
  - [Environment File Option](#environment-file-option)
  - [Optional Variables](#optional-variables)
  - [Verifying Authentication](#verifying-authentication)
- [Azure OpenAI Setup](#azure-openai-setup)
  - [Environment Variables](#environment-variables)
  - [Configure ~/.codex/config.toml](#configure-codexconfigtoml)
  - [Docker Run Examples (Azure)](#docker-run-examples-azure)
- [Working with Codex CLI from the Container](#working-with-codex-cli-from-the-container)
  - [Basic Usage Pattern](#basic-usage-pattern)
  - [Volume Mounts Explained](#volume-mounts-explained)
  - [Working Directory Context](#working-directory-context)
- [Usage Examples](#usage-examples)
  - [Interactive Session](#interactive-session)
  - [Single Command Execution](#single-command-execution)
  - [Shell Alias for Convenience](#shell-alias-for-convenience)
- [File Permissions](#file-permissions)
  - [Option 1: Build with Custom UID](#option-1-build-with-custom-uid)
  - [Option 2: Fix Permissions After Creation](#option-2-fix-permissions-after-creation)
- [Troubleshooting](#troubleshooting)
  - [Authentication Issues](#authentication-issues)
  - [File Access Issues](#file-access-issues)
  - [Container Issues](#container-issues)

A containerized environment for running the OpenAI Codex CLI. This image provides a rootless, minimal setup so you can run `codex` commands with local file access and API key–based authentication.

## Container Architecture

- **Rootless execution**: Runs as user `codex` (UID 1000) instead of root
- **Minimal base**: Uses `node:22-slim` for a smaller attack surface
- **CLI entrypoint**: Container entrypoint is `codex`

## Building the Container Image

Build from the provided Dockerfile:

```bash
docker build -t codex-cli:dev .
```

### Build Arguments

Customize via build args if needed:

```bash
docker build \
  --build-arg CODEX_CLI_VERSION=latest \
  --build-arg USERNAME=codex \
  --build-arg UID=1000 \
  --build-arg GID=1000 \
  -t codex-cli:dev .
```

## Authentication Setup

The Codex CLI authenticates with OpenAI using an API key. Pass your key as an environment variable when running the container.

### Using OPENAI_API_KEY

Avoid placing secrets directly on the command line (they can leak via shell history and process inspection). Use an ephemeral prompt and pass the variable through:

```bash
# Prompts without echoing; does not store secret in history
read -s OPENAI_API_KEY && \
docker run -it \
  -v ${PWD}:/work \
  -e OPENAI_API_KEY \
  --rm codex-cli:dev --help; \
unset OPENAI_API_KEY
```

### Environment File Option

```bash
# Create a protected env file (avoid echoing secrets in your history)
install -m 600 /dev/null .env

# Edit securely with your editor to add keys
${EDITOR:-vi} .env

# Example contents to add (edit in the editor):
# OPENAI_API_KEY=...
# OPENAI_ORG_ID=org_...
# OPENAI_PROJECT=proj_...
# OPENAI_BASE_URL=https://api.openai.com/v1

# Use the environment file with Docker
docker run -it -v ${PWD}:/work --env-file .env --rm codex-cli:dev --help
```

Security tips for env files:

- Keep `.env` out of version control (add to `.gitignore`).
- Restrict permissions to owner read/write only (`chmod 600 .env`).
- Prefer short‑lived keys and rotate regularly.

### Optional Variables

- `OPENAI_ORG_ID`: Organization identifier if required by your account
- `OPENAI_PROJECT`: Project identifier for scoping usage
- `OPENAI_BASE_URL`: Alternate base URL if using a proxy or compatible endpoint

### Verifying Authentication

Run a simple command and confirm it executes without auth errors:

```bash
docker run -it -v ${PWD}:/work --env-file .env --rm codex-cli:dev --version
```

## Azure OpenAI Setup

Use this if your OpenAI models are deployed on Azure OpenAI. You will need:

- An Azure OpenAI resource and at least one model deployment name (e.g., a chat model and optionally an embeddings model)
- The Azure OpenAI API key for that resource

There are two supported ways to configure Codex for Azure: via environment variables or via a config file at `~/.codex/config.toml` (as described in Microsoft’s guide).

### Environment Variables

Set these to point Codex at your Azure OpenAI endpoint:

- `AZURE_OPENAI_API_KEY`: Your Azure OpenAI resource API key
- `OPENAI_BASE_URL`: Your Azure endpoint base URL, typically `https://<resource-name>.openai.azure.com/openai`
- `OPENAI_API_VERSION`: The Azure OpenAI API version, for example `2024-05-01-preview`

When targeting a specific deployment, pass it as the model name (the deployment name), for example with `--model <your-deployment-name>` when invoking Codex commands.

Example `.env` for Azure:

```env
AZURE_OPENAI_API_KEY=xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
OPENAI_BASE_URL=https://<your-resource>.openai.azure.com/openai
OPENAI_API_VERSION=2024-05-01-preview
```

### Configure ~/.codex/config.toml

Codex also supports a TOML config file in your home directory. This is useful to persist Azure settings and deployment names without repeating flags. Create `~/.codex/config.toml` on your host with content like:

```toml
# ~/.codex/config.toml
[default]
provider = "azure-openai"

[providers.azure-openai]
# Your Azure OpenAI resource endpoint (no trailing /openai path needed here)
endpoint = "https://<your-resource>.openai.azure.com"
api_version = "2024-05-01-preview"

# Deployment names you created in the Azure OpenAI resource
chat_deployment = "<your-chat-deployment>"
embedding_deployment = "<your-embeddings-deployment>"

# Use this environment variable for the API key
api_key_env = "AZURE_OPENAI_API_KEY"
```

Notes:

- Mount your host home directory into the container so Codex can read `~/.codex/config.toml` at `/home/codex/.codex/config.toml`.
- Keep your API key out of the file; the key is read from the environment variable specified by `api_key_env`.

### Docker Run Examples (Azure)

Using environment variables only (without exposing secrets on the command line):

```bash
# Prompt for the Azure key without echoing
read -s AZURE_OPENAI_API_KEY && \
docker run -it --rm \
  -v ${PWD}:/work \
  -e AZURE_OPENAI_API_KEY \
  -e OPENAI_BASE_URL="https://<your-resource>.openai.azure.com/openai" \
  -e OPENAI_API_VERSION="2024-05-01-preview" \
  codex-cli:dev --help; \
unset AZURE_OPENAI_API_KEY
```

Using `~/.codex/config.toml` plus an `.env` file that only carries the key:

```bash
# Ensure ~/.codex/config.toml exists on host; .env carries only the key
# Create protected .env (once):
install -m 600 /dev/null .env
${EDITOR:-vi} .env

# In .env, add only:
# AZURE_OPENAI_API_KEY=...

docker run -it --rm \
  -v $HOME:/home/codex \
  -v ${PWD}:/work \
  --env-file .env \
  codex-cli:dev --help
```

## Working with Codex CLI from the Container

Use a working directory mount so Codex can read/write files in your project.

### Basic Usage Pattern

```bash
docker run -it -v ${PWD}:/work --env-file .env --rm codex-cli:dev [CODEX_ARGS]
```

Replace `[CODEX_ARGS]` with the arguments supported by your installed `@openai/codex` version (see `--help`).

### Volume Mounts Explained

- `-v ${PWD}:/work`: Maps your current directory into the container working directory
- `--rm`: Removes the container after the command finishes
- `-it`: Interactive TTY for prompts and multi-step workflows

### Working Directory Context

The image sets `/work` as the working directory. This means:

- Files in your current directory are accessible within the container
- Output files are written back to your current directory
- Relative paths behave as expected

## Usage Examples

### Interactive Session

Start an interactive session to run multiple Codex commands:

```bash
docker run -it -v ${PWD}:/work --env-file .env --rm codex-cli:dev
```

### Single Command Execution

Run a single command, for example to see help or version information:

```bash
# Help
docker run -it -v ${PWD}:/work --env-file .env --rm codex-cli:dev --help

# Version
docker run -it -v ${PWD}:/work --env-file .env --rm codex-cli:dev --version
```

### Shell Alias for Convenience

Create a shell alias for shorter commands:

```bash
# Add to your ~/.bashrc or ~/.zshrc
alias codex='docker run -it -v ${PWD}:/work --env-file .env --rm codex-cli:dev'

# Then simply use:
codex --help
```

## File Permissions

The container runs as user `codex` with UID 1000. If your host user has a different UID/GID, you may encounter permission issues. To resolve this:

### Option 1: Build with Custom UID

```bash
docker build \
  --build-arg UID=$(id -u) \
  --build-arg GID=$(id -g) \
  -t codex-cli:dev .
```

### Option 2: Fix Permissions After Creation

```bash
# If files are created with unexpected ownership
sudo chown -R $(id -u):$(id -g) ./path-to-files
```

## Troubleshooting

### Authentication Issues

- Missing or invalid API key: Ensure `OPENAI_API_KEY` is set (via `-e` or `--env-file`)
- Org/project scoping: If required, set `OPENAI_ORG_ID` and/or `OPENAI_PROJECT`

### File Access Issues

- Files not visible: Confirm `-v ${PWD}:/work` is included
- Wrong ownership: Rebuild with your UID/GID or adjust ownership afterward

### Container Issues

- Container fails to start: Verify Docker is running and the image built successfully
- Command not found: Ensure arguments come after the image name and use `--help` to list supported commands
