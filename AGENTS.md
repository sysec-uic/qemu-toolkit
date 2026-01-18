# Repository Guidelines

## Project Structure & Module Organization
- `create_vm_image.sh` and `launch_vm.sh` are the primary entry points for image creation and VM launch.
- `img/` stores downloaded base cloud images (keep large binaries out of git).
- `out/` is the default output location for generated VM images and cloud-init ISOs.
- `images.env` defines optional base image aliases for `create_vm_image.sh`.
- `README.md` contains the end-user walkthrough and examples.

## Build, Test, and Development Commands
- `./create_vm_image.sh -b ./img/<base>.img -n <name>.img -u <user> -s 64G` creates a new QCOW2 image and cloud-init ISO in `out/`.
- `./launch_vm.sh -i out/<name>.img -p 2222 -c 2 -m 4 -t vm-session` starts QEMU in a tmux session with SSH forwarding.
- `ssh <user>@localhost -p 2222` connects to the running VM (user networking).

## Coding Style & Naming Conventions
- Bash scripts use 2-space indentation and clear step-by-step comments.
- Use uppercase for environment-style constants (e.g., `DEFAULT_VCPU`) and lowercase for locals (e.g., `vm_image`).
- Prefer descriptive filenames with underscores (`create_vm_image.sh`) and keep scripts in repo root.
- Keep scripts compatible with `/bin/bash`; avoid non-portable shell features.

## Testing Guidelines
- There is no automated test suite. Validate changes manually:
  - Build a VM image, boot it, and confirm SSH works via the forwarded port.
  - Verify cloud-init output in `out/` and confirm hostnames/users are set.
- If adding checks, document how to run them in `README.md`.

## Commit & Pull Request Guidelines
- Commit messages are short and action-oriented; Conventional Commit prefixes like `chore:` appear in history but are not strictly required.
- PRs should include:
  - A brief description of the change and why it is needed.
  - Example commands used for validation (e.g., `./create_vm_image.sh ...`).
  - Notes about any new dependencies or networking requirements.

## Security & Configuration Tips
- Avoid committing cloud images or generated `out/` artifacts.
- Do not hardcode secrets; use `-p` flags or environment overrides during local runs.
