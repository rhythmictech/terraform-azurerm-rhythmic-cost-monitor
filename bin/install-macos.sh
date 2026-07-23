#!/bin/bash
set -euo pipefail

echo 'installing brew packages'
brew update
brew install tfenv tflint terraform-docs trivy pre-commit azure-cli coreutils
brew upgrade tfenv tflint terraform-docs trivy pre-commit azure-cli coreutils

echo 'installing pre-commit hooks'
pre-commit install

echo 'setting pre-commit hooks to auto-install on clone in the future'
git config --global init.templateDir ~/.git-template
pre-commit init-templatedir ~/.git-template

echo 'installing terraform with tfenv'
tfenv install

echo 'installing tflint azurerm ruleset'
tflint --init
