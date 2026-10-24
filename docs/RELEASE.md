# Build e Release — Escrita de Libras

Guia para compilar o APK/AAB localmente e publicar pelo GitHub Actions.

## 1. Pré-requisitos

| Ferramenta | Versão | Observação |
|---|---|---|
| Flutter | 3.41.x (stable) | o CI usa 3.41.7 |
| Java (JDK) | 17 | exigido pelo Android Gradle Plugin |
| Android SDK | via Android Studio ou `flutter doctor` | — |

## 2. Build local

```bash
flutter pub get
flutter analyze
flutter test

# APK universal (todas as ABIs em um arquivo)
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk

# APKs separados por ABI (menores)
flutter build apk --release --split-per-abi
# -> build/app/outputs/flutter-apk/app-<abi>-release.apk

# App Bundle para a Play Store
flutter build appbundle --release
# -> build/app/outputs/bundle/release/app-release.aab
```

Sem keystore configurado, o Gradle assina com a chave de debug (útil para
testes, mas **não** serve para publicar). O aviso é esperado.

## 3. Assinatura de release (uma vez só)

A Play Store rejeita apps assinados com a chave de debug. Gere um keystore
próprio e guarde-o com backup seguro — **perder o keystore = não poder mais
atualizar o app**:

```bash
mkdir -p ~/keystores
keytool -genkey -v \
  -keystore ~/keystores/escrita-de-libras-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias escrita
```

O `android/app/build.gradle.kts` lê a assinatura destas variáveis de ambiente
(as mesmas usadas pelos outros projetos em `vibe_code/android`):

| Variável | Conteúdo |
|---|---|
| `KEYSTORE_PATH` | caminho absoluto do `.jks` |
| `KEYSTORE_PASSWORD` | senha do keystore |
| `KEY_ALIAS` | alias da chave |
| `KEY_PASSWORD` | senha da chave |

Build local assinado:

```bash
export KEYSTORE_PATH="$HOME/keystores/escrita-de-libras-release.jks"
export KEYSTORE_PASSWORD="..."
export KEY_ALIAS="escrita"
export KEY_PASSWORD="..."

flutter build apk --release --split-per-abi
```

Verificação da assinatura (usa o `apksigner` do Android SDK):

```bash
APKSIGNER="$ANDROID_HOME/build-tools/$(ls "$ANDROID_HOME/build-tools" | sort -V | tail -n1)/apksigner"
"$APKSIGNER" verify --verbose --print-certs build/app/outputs/flutter-apk/app-release.apk
```

`*.jks`, `*.keystore` e `android/key.properties` já estão no `.gitignore` —
**nunca** faça commit de chaves.

## 4. Secrets do GitHub

Em *Settings → Secrets and variables → Actions*, crie:

| Secret | Conteúdo |
|---|---|
| `KEYSTORE_BASE64` | `base64 -w0 ~/keystores/escrita-de-libras-release.jks` |
| `KEYSTORE_PASSWORD` | senha do keystore |
| `KEY_ALIAS` | `escrita` |
| `KEY_PASSWORD` | senha da chave |

Sem esses secrets o workflow continua funcionando, mas gera artefatos
assinados com a chave de debug (e emite um `::warning::` no log). Use apenas
para testes.

## 5. CI/CD

### `.github/workflows/ci.yml`

Roda em push para `main`, pull requests e execução manual:

1. `flutter pub get`
2. `flutter analyze`
3. `flutter test`
4. Testes do tooling Python (`python -m unittest discover -s tools/signpuddle/tests`)

### `.github/workflows/build-release.yml`

Roda em push de tag `v*` e em execução manual (*Actions → Build and Release APK
→ Run workflow*):

1. Confere se a tag `vX.Y.Z` bate com o `version:` do `pubspec.yaml`
2. `flutter analyze` + `flutter test`
3. Decodifica o keystore dos secrets
4. Gera APK split por ABI, APK universal e AAB
5. Verifica a assinatura de cada APK com `apksigner`
6. Publica os artefatos (sempre) e cria o GitHub Release (somente em tags)

Artefatos gerados:

```
escrita_de_libras-<versão>-arm64-v8a.apk
escrita_de_libras-<versão>-armeabi-v7a.apk
escrita_de_libras-<versão>-x86_64.apk
escrita_de_libras-<versão>-universal.apk
escrita_de_libras-<versão>.aab
SHA256SUMS.txt
```

Em `workflow_dispatch` a versão vira `vX.Y.Z-dev.<run_number>` e **não** cria
Release — serve para validar o build. Em tags, a versão é exatamente a tag.

## 6. Fluxo de release

```bash
# 1. Atualize a versão no pubspec.yaml (ex.: 1.0.1+2 — sempre incremente o +N)
# 2. Commit e tag:
git commit -am "release: v1.0.1"
git tag v1.0.1
git push origin main v1.0.1
# 3. O CI publica APKs + AAB no GitHub Release.
```

O `+N` do `pubspec.yaml` é o `versionCode` do Android: ele **precisa** aumentar
em todo release que vá para a Play Store. A tag deve ser `v` + a parte antes do
`+`.

## 7. Publicação na Google Play (opcional)

O workflow já gera o `.aab`; o envio à Play Store é manual:

1. Crie o app no [Play Console](https://play.google.com/console) (a primeira
   versão precisa ser enviada manualmente).
2. Envie `escrita_de_libras-<versão>.aab` e aceite o **Play App Signing**.
3. Para automatizar depois, adicione um secret `PLAY_SERVICE_ACCOUNT_JSON`
   (conta de serviço com papel "Gerente de lançamentos") e uma etapa com
   `r0adkll/upload-google-play@v1`, como em
   `libras_dicionario/.github/workflows/build-release.yml`.
