#!/usr/bin/env bash
# Escrita de Libras
# Copyright (C) 2026 Eduardo Barroso Nunes
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Flutter SDK
if ! command -v flutter >/dev/null 2>&1; then
  if [ -d "$HOME/sdk/flutter/bin" ]; then
    export PATH="$HOME/sdk/flutter/bin:$PATH"
  elif [ -d "$HOME/projetos/bin/flutter/flutter/bin" ]; then
    export PATH="$HOME/projetos/bin/flutter/flutter/bin:$PATH"
  fi
fi

# Android SDK
if [ -z "${ANDROID_HOME:-}" ] || [ ! -d "$ANDROID_HOME" ]; then
  if [ -d "$HOME/.local/share/android" ]; then
    export ANDROID_HOME="$HOME/.local/share/android"
  elif [ -d "$HOME/Android/Sdk" ]; then
    export ANDROID_HOME="$HOME/Android/Sdk"
  fi
fi

# Java 17
if [ -z "${JAVA_HOME:-}" ] || [ ! -d "$JAVA_HOME" ]; then
  if [ -d "/usr/lib/jvm/java-17-openjdk" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
  elif [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
  elif [ -d "$HOME/.sdkman/candidates/java/17.0.17-tem" ]; then
    export JAVA_HOME="$HOME/.sdkman/candidates/java/17.0.17-tem"
  elif [ -d "$HOME/.sdkman/candidates/java/current" ]; then
    export JAVA_HOME="$HOME/.sdkman/candidates/java/current"
  fi
fi

# Keystore signing environment
KEYSTORES_DIR="$SCRIPT_DIR/../keystores"
if [ -f "$KEYSTORES_DIR/signing.env" ]; then
  source "$KEYSTORES_DIR/signing.env"
elif [ -f "$HOME/projetos/personal/keystores/signing.env" ]; then
  source "$HOME/projetos/personal/keystores/signing.env"
fi

if [ -n "${ESCRITA_LIBRAS_KEYSTORE:-}" ]; then
  if [ ! -f "$ESCRITA_LIBRAS_KEYSTORE" ] && [ -f "$KEYSTORES_DIR/escrita_de_libras.jks" ]; then
    export KEYSTORE_PATH="$KEYSTORES_DIR/escrita_de_libras.jks"
  else
    export KEYSTORE_PATH="$ESCRITA_LIBRAS_KEYSTORE"
  fi
  export KEYSTORE_PASSWORD="${ESCRITA_LIBRAS_PASSWORD:-}"
  export KEY_ALIAS="${ESCRITA_LIBRAS_ALIAS:-escrita_de_libras}"
  export KEY_PASSWORD="${ESCRITA_LIBRAS_PASSWORD:-}"
  echo "==> Usando keystore de release: $KEYSTORE_PATH"
else
  echo "==> Assinatura release não configurada; o Gradle usará debug key para compilar localmente."
fi

flutter config --jdk-dir="$JAVA_HOME" >/dev/null

echo "==> pub get"
flutter pub get

echo "==> analyze"
flutter analyze

echo "==> test"
flutter test

echo "==> build APK (release)"
flutter build apk --release

echo "==> build AAB (release)"
flutter build appbundle --release

echo ""
echo "APK: build/app/outputs/flutter-apk/app-release.apk"
echo "AAB: build/app/outputs/bundle/release/app-release.aab"
