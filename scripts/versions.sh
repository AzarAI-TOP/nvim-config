# Pinned bootstrap assets, shared by the Linux and Windows bootstrap scripts
# and checked by the CI drift guard. SHA-256 values come from the corresponding
# GitHub Release asset digest fields. The Windows font archive (0xProto.zip)
# differs from the Linux one (0xProto.tar.xz), hence two hashes.
# shellcheck shell=bash
# shellcheck disable=SC2034 # values are consumed by the sourcing bootstrap scripts

NVIM_VERSION="0.12.4"
NVIM_SHA256_X86_64="012bf3fcac5ade43914df3f174668bf64d05e049a4f032a388c027b1ebd78628"
NVIM_SHA256_ARM64="ceb7e88c6b681f0515d135dcdfad54f5eb4373b25ce6172197cd9a69c758063f"

FZF_VERSION="0.74.2"
FZF_SHA256_AMD64="b3648f48675612b69ee35371cf6dc99ca96d767e89b912d079080916ac8ba8bd"
FZF_SHA256_ARM64="1373e3f5ed3c468179d4529942ddd96c234bcad1bcacaf238916e26a5234b5b2"

NERD_FONTS_VERSION="3.5.0"
OXPROTO_SHA256_XZ="b6cd12d383255548292c12fc3f8b03e197407d8299393fb27e351aba42224965"
OXPROTO_SHA256_ZIP="96044c9b041dbe6341a2e8b831259ba8e60f4646e55b721b5f6577505381df1f"
