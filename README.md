# Neutral CUDA-Q worker

This public repository derives a generic managed worker from NVIDIA's signed,
digest-pinned CUDA-Q 0.16.0 CUDA 13 image. OpenSSH is installed at image-build
time; billed startup performs no package installation. Only a runtime-provided
public key is accepted.

The source and image contain no credentials, SSH private keys, model weights,
benchmark fixtures, hidden references, graders, private mappings, client data,
private source code, or organization-specific metadata.
