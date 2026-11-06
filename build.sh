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

export PATH="/home/eduardo/projetos/bin/flutter/flutter/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-/home/eduardo/Android/Sdk}"
if [ -z "${JAVA_HOME:-}" ] || [ ! -d "$JAVA_HOME" ]; then
  if [ -d "$HOME/.sdkman/candidates/java/17.0.17-tem" ]; then
    export JAVA_HOME="$HOME/.sdkman/candidates/java/17.0.17-tem"
  elif [ -d "$HOME/.sdkman/candidates/java/current" ]; then
    export JAVA_HOME="$HOME/.sdkman/candidates/java/current"
  elif [ -d "/usr/lib/jvm/java-17-openjdk-amd64" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
  fi
fi

source "$HOME/projetos/personal/keystores/signing.env"
export KEYSTORE_PATH="$ESCRITA_LIBRAS_KEYSTORE"
export KEYSTORE_PASSWORD="$ESCRITA_LIBRAS_PASSWORD"
export KEY_ALIAS="$ESCRITA_LIBRAS_ALIAS"
export KEY_PASSWORD="$ESCRITA_LIBRAS_PASSWORD"

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
