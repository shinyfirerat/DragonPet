#!/bin/zsh
set -euo pipefail
cd "$(dirname "$0")/.."
QA_DIR=$(mktemp -d "${TMPDIR:-/tmp}/dragonpet-tests.XXXXXX")
export DRAGONPET_TEST_ROOT="$QA_DIR/runtime-test"
trap 'python3 -c "import shutil,sys; shutil.rmtree(sys.argv[1], ignore_errors=True)" "$QA_DIR"' EXIT
COMMON=(Sources/Preferences.swift Sources/LocalLines.swift Sources/TokenHistory.swift Sources/Companion.swift Sources/Configuration.swift Sources/APIClient.swift Sources/Usage.swift)
swiftc "${COMMON[@]}" Tests/Configuration/main.swift -framework AppKit -framework Security -o "$QA_DIR/config"
"$QA_DIR/config"
swiftc "${COMMON[@]}" Tests/Companion/main.swift -framework AppKit -framework Security -o "$QA_DIR/timeout"
"$QA_DIR/timeout" "$PWD/Tests/Companion/fake-server.py"
python3 -c 'from pathlib import Path; Path("Tests/CompanionBurst/count.tmp").unlink(missing_ok=True)'
swiftc "${COMMON[@]}" Tests/CompanionBurst/main.swift -framework AppKit -framework Security -o "$QA_DIR/burst"
"$QA_DIR/burst" "$PWD/Tests/CompanionBurst/fake-server.py"
python3 -c 'from pathlib import Path; Path("Tests/CompanionBurst/count.tmp").unlink(missing_ok=True)'
swiftc Sources/Skin.swift Sources/PetView.swift "${COMMON[@]}" Tests/main.swift -framework AppKit -framework Security -o "$QA_DIR/interaction"
"$QA_DIR/interaction" "$PWD/Resources/Skins/white-dragon"

swiftc "${COMMON[@]}" Tests/TokenHistory/main.swift -framework AppKit -framework Security -o "$QA_DIR/history"
"$QA_DIR/history"

swiftc "${COMMON[@]}" Tests/CompanionUsage/main.swift -framework AppKit -framework Security -o "$QA_DIR/usage"
"$QA_DIR/usage" "$PWD/Tests/CompanionUsage/fake-cli.py"
