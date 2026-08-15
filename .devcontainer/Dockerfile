FROM ubuntu:24.04

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=1000
ARG FLUTTER_CHANNEL=stable
ARG ANDROID_CMDLINE_TOOLS_VERSION=15859902
ARG ANDROID_PLATFORMS="platforms;android-36 platforms;android-37.0"
ARG ANDROID_BUILD_TOOLS="build-tools;36.1.0 build-tools;37.0.0"

ENV FLUTTER_ROOT=/opt/flutter
ENV ANDROID_HOME=/opt/android-sdk
ENV ANDROID_SDK_ROOT=/opt/android-sdk
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ENV PATH=${PATH}:${FLUTTER_ROOT}/bin:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools

# Base packages needed to fetch/build Flutter and Android tooling. This
# project's plugin only targets android/ios (see pubspec.yaml), so no
# Linux desktop toolchain (clang/cmake/ninja/gtk) is installed here.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        openjdk-17-jdk-headless \
        sudo \
        unzip \
        wget \
        xz-utils \
        zip \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user matching the conventional devcontainer "vscode" user.
# ubuntu:24.04 ships a default "ubuntu" user at UID/GID 1000; rename it if
# present, otherwise create a fresh user.
RUN if id -nu ${USER_UID} > /dev/null 2>&1 && [ "$(id -nu ${USER_UID})" != "${USERNAME}" ]; then \
        existing_user="$(id -nu ${USER_UID})"; \
        usermod -l ${USERNAME} -d /home/${USERNAME} -m "${existing_user}"; \
        groupmod -n ${USERNAME} "${existing_user}" 2>/dev/null || true; \
    elif ! id -u ${USERNAME} > /dev/null 2>&1; then \
        groupadd --gid ${USER_GID} ${USERNAME}; \
        useradd --uid ${USER_UID} --gid ${USER_GID} -m -s /bin/bash ${USERNAME}; \
    fi \
    && echo "${USERNAME} ALL=(root) NOPASSWD:ALL" > /etc/sudoers.d/${USERNAME} \
    && chmod 0440 /etc/sudoers.d/${USERNAME}

RUN git clone --depth 1 --branch ${FLUTTER_CHANNEL} https://github.com/flutter/flutter.git ${FLUTTER_ROOT}

RUN mkdir -p ${ANDROID_HOME}/cmdline-tools \
    && curl -fsSL "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_VERSION}_latest.zip" -o /tmp/android-cmdline-tools.zip \
    && unzip -q /tmp/android-cmdline-tools.zip -d /tmp/android-cmdline-tools \
    && mv /tmp/android-cmdline-tools/cmdline-tools ${ANDROID_HOME}/cmdline-tools/latest \
    && rm -rf /tmp/android-cmdline-tools /tmp/android-cmdline-tools.zip

RUN yes | sdkmanager --licenses > /dev/null \
    && sdkmanager "platform-tools" ${ANDROID_BUILD_TOOLS} ${ANDROID_PLATFORMS}

RUN flutter config --no-analytics \
    && flutter config --android-sdk ${ANDROID_HOME} \
    && mkdir -p /home/${USERNAME}/.pub-cache /home/${USERNAME}/.gradle \
    && chown -R ${USERNAME}:${USERNAME} ${FLUTTER_ROOT} ${ANDROID_HOME} /home/${USERNAME}/.pub-cache /home/${USERNAME}/.gradle
