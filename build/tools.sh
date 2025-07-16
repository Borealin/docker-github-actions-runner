#!/usr/bin/env bash
set -euo pipefail

function install_git() {
  ( apt-get install -y --no-install-recommends git \
   || apt-get install -t stable -y --no-install-recommends git )
}

function install_liblttng-ust() {
  if [[ $(apt-cache search -n liblttng-ust0 | awk '{print $1}') == "liblttng-ust0" ]]; then
    apt-get install -y --no-install-recommends liblttng-ust0
  fi

  if [[ $(apt-cache search -n liblttng-ust1 | awk '{print $1}') == "liblttng-ust1" ]]; then
    apt-get install -y --no-install-recommends liblttng-ust1
  fi
}

function install_aws-cli() {
  ( curl "https://awscli.amazonaws.com/awscli-exe-linux-$(uname -m).zip" -o "awscliv2.zip" \
    && unzip -q awscliv2.zip -d /tmp/ \
    && /tmp/aws/install \
    && rm awscliv2.zip \
  ) \
    || pip3 install --no-cache-dir awscli
}

function install_git-lfs() {
  local DPKG_ARCH
  DPKG_ARCH="$(dpkg --print-architecture)"

  curl -s "https://github.com/git-lfs/git-lfs/releases/download/v${GIT_LFS_VERSION}/git-lfs-linux-${DPKG_ARCH}-v${GIT_LFS_VERSION}.tar.gz" -L -o /tmp/lfs.tar.gz
  tar -xzf /tmp/lfs.tar.gz -C /tmp
  "/tmp/git-lfs-${GIT_LFS_VERSION}/install.sh"
  rm -rf /tmp/lfs.tar.gz "/tmp/git-lfs-${GIT_LFS_VERSION}"
}

function install_docker-cli() {
  apt-get install -y docker-ce-cli --no-install-recommends --allow-unauthenticated
}

function install_docker() {
  apt-get install -y docker-ce docker-ce-cli docker-buildx-plugin containerd.io docker-compose-plugin --no-install-recommends --allow-unauthenticated

  echo -e '#!/bin/sh\ndocker compose --compatibility "$@"' > /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose

  sed -i 's/ulimit -Hn/# ulimit -Hn/g' /etc/init.d/docker
}

function install_container-tools() {
  ( apt-get install -y --no-install-recommends podman buildah skopeo || : )
}

function install_github-cli() {
  local DPKG_ARCH GH_CLI_VERSION GH_CLI_DOWNLOAD_URL

  DPKG_ARCH="$(dpkg --print-architecture)"
  
  # Use GitHub token if available to avoid rate limiting
  local CURL_ARGS=(-sL -H "Accept: application/vnd.github+json")
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  GH_CLI_VERSION=$(curl "${CURL_ARGS[@]}" \
    https://api.github.com/repos/cli/cli/releases/latest \
      | jq -r '.tag_name' | sed 's/^v//g')

  GH_CLI_DOWNLOAD_URL=$(curl "${CURL_ARGS[@]}" \
    https://api.github.com/repos/cli/cli/releases/latest \
      | jq ".assets[] | select(.name == \"gh_${GH_CLI_VERSION}_linux_${DPKG_ARCH}.deb\")" \
      | jq -r '.browser_download_url')

  curl -sSLo /tmp/ghcli.deb "${GH_CLI_DOWNLOAD_URL}"
  apt-get -y install /tmp/ghcli.deb
  rm /tmp/ghcli.deb
}

function install_yq() {
  local DPKG_ARCH YQ_DOWNLOAD_URL

  DPKG_ARCH="$(dpkg --print-architecture)"
  
  # Use GitHub token if available to avoid rate limiting
  local CURL_ARGS=(-sL -H "Accept: application/vnd.github+json")
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  YQ_DOWNLOAD_URL=$(curl "${CURL_ARGS[@]}" \
    https://api.github.com/repos/mikefarah/yq/releases/latest \
      | jq ".assets[] | select(.name == \"yq_linux_${DPKG_ARCH}.tar.gz\")" \
      | jq -r '.browser_download_url')

  curl -s "${YQ_DOWNLOAD_URL}" -L -o /tmp/yq.tar.gz
  tar -xzf /tmp/yq.tar.gz -C /tmp
  mv "/tmp/yq_linux_${DPKG_ARCH}" /usr/local/bin/yq
}

function install_powershell() {
  local DPKG_ARCH PWSH_VERSION PWSH_DOWNLOAD_URL

  DPKG_ARCH="$(dpkg --print-architecture)"
  
  # Use GitHub token if available to avoid rate limiting
  local CURL_ARGS=(-sL -H "Accept: application/vnd.github+json")
  if [[ -n "${GITHUB_TOKEN}" ]]; then
    CURL_ARGS+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  PWSH_VERSION=$(curl "${CURL_ARGS[@]}" \
    https://api.github.com/repos/PowerShell/PowerShell/releases/latest \
      | jq -r '.tag_name' \
      | sed 's/^v//g')

  PWSH_DOWNLOAD_URL=$(curl "${CURL_ARGS[@]}" \
    https://api.github.com/repos/PowerShell/PowerShell/releases/latest \
      | jq -r ".assets[] | select(.name == \"powershell-${PWSH_VERSION}-linux-${DPKG_ARCH//amd64/x64}.tar.gz\") | .browser_download_url")

  curl -L -o /tmp/powershell.tar.gz "$PWSH_DOWNLOAD_URL"
  mkdir -p /opt/powershell
  tar zxf /tmp/powershell.tar.gz -C /opt/powershell
  chmod +x /opt/powershell/pwsh
  ln -s /opt/powershell/pwsh /usr/bin/pwsh
}

function install_android-sdk() {
  local ANDROID_SDK_VERSION="11076708"
  local ANDROID_HOME="/opt/android-sdk"
  local ANDROID_SDK_ROOT="${ANDROID_HOME}"
  local DPKG_ARCH
  DPKG_ARCH="$(dpkg --print-architecture)"
  
  # Create directories
  mkdir -p "${ANDROID_HOME}" "${ANDROID_HOME}/cmdline-tools"
  
  # Download and install Android SDK Command Line Tools
  local SDK_URL="https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_SDK_VERSION}_latest.zip"
  curl -o /tmp/cmdline-tools.zip "${SDK_URL}"
  unzip -q /tmp/cmdline-tools.zip -d "${ANDROID_HOME}/cmdline-tools"
  mv "${ANDROID_HOME}/cmdline-tools/cmdline-tools" "${ANDROID_HOME}/cmdline-tools/latest"
  rm /tmp/cmdline-tools.zip
  
  # Set environment variables
  echo "export ANDROID_HOME=${ANDROID_HOME}" >> /etc/environment
  echo "export ANDROID_SDK_ROOT=${ANDROID_SDK_ROOT}" >> /etc/environment
  echo "export PATH=\$PATH:\$ANDROID_HOME/cmdline-tools/latest/bin:\$ANDROID_HOME/platform-tools:\$ANDROID_HOME/tools:\$ANDROID_HOME/tools/bin" >> /etc/environment
  
  # Source environment for current session
  export ANDROID_HOME="${ANDROID_HOME}"
  export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT}"
  export PATH="${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/tools:${ANDROID_HOME}/tools/bin"
  
  # Accept licenses and install essential packages
  yes | sdkmanager --licenses || true
  
  # Install multiple build-tools versions (matching GitHub Actions)
  local BUILD_TOOLS=("36.0.0" "35.0.0" "34.0.0" "33.0.0" "32.0.0")
  for build_tool in "${BUILD_TOOLS[@]}"; do
    echo "Installing build-tools ${build_tool}..."
    sdkmanager "build-tools;${build_tool}" || true
  done
  
  # Install platform-tools
  sdkmanager "platform-tools"
  
  # Install Android platforms
  local PLATFORMS=("34" "33" "32" "31" "30")
  for platform in "${PLATFORMS[@]}"; do
    echo "Installing android-${platform}..."
    sdkmanager "platforms;android-${platform}" || true
  done
  
  # Install NDK versions (1 latest non-LTS, 2 latest LTS)
  local NDK_VERSIONS=("28.2.13676358" "27.2.12479018" "26.3.11579264")
  for ndk_version in "${NDK_VERSIONS[@]}"; do
    echo "Installing NDK ${ndk_version}..."
    sdkmanager "ndk;${ndk_version}" || true
  done
  
  # Set default NDK version
  local DEFAULT_NDK="27.2.12479018"
  echo "export ANDROID_NDK_ROOT=${ANDROID_HOME}/ndk/${DEFAULT_NDK}" >> /etc/environment
  echo "export ANDROID_NDK=${ANDROID_HOME}/ndk/${DEFAULT_NDK}" >> /etc/environment
  
  # Set permissions
  chown -R root:root "${ANDROID_HOME}"
  chmod -R 755 "${ANDROID_HOME}"
  
  # Make SDK accessible to all users
  chmod -R a+rX "${ANDROID_HOME}"
}

function install_go() {
  # Install Go versions (3 latest minor versions)
  local GO_ROOT="/usr/local/go"
  
  # Detect architecture
  local DPKG_ARCH
  DPKG_ARCH="$(dpkg --print-architecture)"
  local GO_ARCH="amd64"
  
  case "${DPKG_ARCH}" in
    amd64)
      GO_ARCH="amd64"
      ;;
    arm64)
      GO_ARCH="arm64"
      ;;
    *)
      echo "Unsupported architecture: ${DPKG_ARCH}"
      return 1
      ;;
  esac
  
  local GO_DIR="${GO_ROOT}"
  
  # Download and install Go
  curl -L "https://go.dev/dl/go1.23.10.linux-${GO_ARCH}.tar.gz" -o "/tmp/go1.23.10.tar.gz"
  mkdir -p "${GO_DIR}"
  tar -C "${GO_DIR}" --strip-components=1 -xzf "/tmp/go1.23.10.tar.gz"
  rm "/tmp/go1.23.10.tar.gz"
  
  # Set environment variables
  echo "export GOROOT=${GO_ROOT}" >> /etc/environment
  echo "export GOPATH=/go" >> /etc/environment
  echo "export PATH=\$PATH:\$GOROOT/bin:\$GOPATH/bin" >> /etc/environment
  
  # Create GOPATH directory
  mkdir -p /go/{bin,pkg,src}
  chmod -R 777 /go
}

function install_tools() {
  local function_name
  # shellcheck source=/dev/null
  source "$(dirname "${BASH_SOURCE[0]}")/config.sh"

  script_packages | while read -r package; do
    function_name="install_${package}"
    if declare -f "${function_name}" > /dev/null; then
      "${function_name}"
    else
      echo "No install script found for package: ${package}"
      exit 1
    fi
  done
}
