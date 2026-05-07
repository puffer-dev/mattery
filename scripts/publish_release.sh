#!/bin/zsh
# Publish a new GitHub Release of Mattery.
#
# Reads the version from project.yml (CFBundleShortVersionString), builds a
# Release .app, zips it with ditto, tags HEAD as v<version>, pushes the tag,
# and creates the GitHub Release with the zip attached.
#
# Bump CFBundleShortVersionString in project.yml and commit before running.

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
cd "$PROJECT_ROOT"

# --- Read version from project.yml ---
VERSION=$(awk '/CFBundleShortVersionString:/ { gsub(/"/, "", $2); print $2; exit }' project.yml)
if [[ -z "${VERSION}" ]]; then
  echo "✗ Failed to read CFBundleShortVersionString from project.yml" >&2
  exit 1
fi

TAG="v${VERSION}"
ZIP_PATH="/tmp/Mattery-${VERSION}.zip"
APP_PATH="build/Build/Products/Release/Mattery.app"

echo "==> Version: ${VERSION} (tag ${TAG})"

# --- Sanity checks ---
if git rev-parse --verify --quiet "${TAG}" >/dev/null; then
  echo "✗ Tag ${TAG} already exists locally. Bump CFBundleShortVersionString in project.yml first." >&2
  exit 1
fi

if git ls-remote --tags origin "${TAG}" | grep -q "${TAG}$"; then
  echo "✗ Tag ${TAG} already exists on origin." >&2
  exit 1
fi

if [[ -n "$(git status --porcelain)" ]]; then
  echo "✗ Working tree has uncommitted changes. Commit or stash before releasing." >&2
  git status --short >&2
  exit 1
fi

# --- Generate + build Release ---
echo "==> xcodegen generate"
xcodegen generate >/dev/null

echo "==> xcodebuild Release (clean build)"
xcodebuild \
  -project Mattery.xcodeproj \
  -scheme Mattery \
  -configuration Release \
  -derivedDataPath build \
  -destination 'platform=macOS' \
  clean build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  >/dev/null

if [[ ! -d "${APP_PATH}" ]]; then
  echo "✗ Build output not found at ${APP_PATH}" >&2
  exit 1
fi

# --- Zip the .app (ditto preserves macOS metadata) ---
echo "==> Zipping ${APP_PATH} → ${ZIP_PATH}"
rm -f "${ZIP_PATH}"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"
SIZE=$(du -h "${ZIP_PATH}" | awk '{print $1}')
echo "    ${SIZE}"

# --- Tag and push ---
echo "==> git tag ${TAG} && push"
git tag -a "${TAG}" -m "Release ${TAG}"
git push origin "${TAG}"

# --- Create GitHub Release ---
NOTES_FILE=$(mktemp)
trap 'rm -f "${NOTES_FILE}"' EXIT
cat > "${NOTES_FILE}" <<EOF
\`Mattery-${VERSION}.zip\` — unzip and move \`Mattery.app\` to \`/Applications/\`.

The binary is ad-hoc signed, not notarized by Apple, so the first launch is blocked by Gatekeeper.

1. Right-click \`Mattery.app\` → **Open** (or Control-click → Open)
2. Click **Open** in the dialog. macOS will remember the choice.

Or strip the quarantine attribute from a terminal:

\`\`\`sh
xattr -dr com.apple.quarantine /Applications/Mattery.app
\`\`\`

**Requirements**: macOS 13 Ventura or later (Apple Silicon).
EOF

echo "==> gh release create ${TAG}"
gh release create "${TAG}" "${ZIP_PATH}" \
  --title "${TAG}" \
  --notes-file "${NOTES_FILE}"

echo "==> Done. https://github.com/puffer-dev/mattery/releases/tag/${TAG}"
