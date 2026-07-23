#!/bin/bash
set -euo pipefail

echo 'installing dependencies'
sudo apt-get update
sudo apt-get install -y python3-pip gawk unzip curl
pip3 install pre-commit

# terraform-docs (pinned; asset OS segment is lowercase 'linux')
TERRAFORM_DOCS_VERSION="0.24.0"
mkdir -p tmp
cd tmp
curl -Lo ./terraform-docs.tar.gz "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-amd64.tar.gz"
tar -xzf terraform-docs.tar.gz
chmod +x terraform-docs
sudo mv terraform-docs /usr/bin/
cd ..
rm -rf tmp

# tflint (pinned direct download; avoids the unauthenticated GitHub API
# rate-limits and fragile URL parsing that made CI flaky)
TFLINT_VERSION="0.61.0"
curl -Lo tflint.zip "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_amd64.zip"
unzip tflint.zip && rm tflint.zip && sudo mv tflint /usr/bin/

# tfenv
git clone https://github.com/tfutils/tfenv.git ~/.tfenv || true
mkdir -p ~/.local/bin/
. ~/.profile
ln -sf ~/.tfenv/bin/* ~/.local/bin

echo 'installing pre-commit hooks'
pre-commit install

echo 'setting pre-commit hooks to auto-install on clone in the future'
git config --global init.templateDir ~/.git-template
pre-commit init-templatedir ~/.git-template

echo 'installing terraform with tfenv'
tfenv install

echo 'installing tflint azurerm ruleset'
tflint --init

# trivy
TRIVY_VERSION="0.72.0"
wget "https://github.com/aquasecurity/trivy/releases/download/v${TRIVY_VERSION}/trivy_${TRIVY_VERSION}_Linux-64bit.deb"
sudo dpkg -i "trivy_${TRIVY_VERSION}_Linux-64bit.deb"
rm -f "trivy_${TRIVY_VERSION}_Linux-64bit.deb"
