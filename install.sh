#!/usr/bin/env bash
set -euo pipefail

echo "==> Setting up Qubo Air Purifier Omarchy plugin..."

PLUGIN_DIR="${HOME}/.config/omarchy/plugins/qubo.purifier"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="${HOME}/.local/bin"
ENV_DIR="${HOME}/.local/share/qubo-env"

# 1. Setup isolated python virtualenv
if ! command -v uv >/dev/null 2>&1; then
    echo "Creating virtual environment with python3..."
    python3 -m venv "${ENV_DIR}"
    "${ENV_DIR}/bin/pip" install --upgrade pip
    "${ENV_DIR}/bin/pip" install qubopy paho-mqtt
else
    echo "Creating virtual environment with uv..."
    uv venv "${ENV_DIR}"
    uv pip install --python "${ENV_DIR}/bin/python" qubopy paho-mqtt
fi

# 2. Install CLI executable
mkdir -p "${BIN_DIR}"
cp "${SCRIPT_DIR}/qubo-control" "${BIN_DIR}/qubo-control"
chmod +x "${BIN_DIR}/qubo-control"
ln -sf "${ENV_DIR}/bin/qubopy" "${BIN_DIR}/qubopy"

# 3. Install Omarchy Plugin files
mkdir -p "${PLUGIN_DIR}"
cp "${SCRIPT_DIR}/manifest.json" "${PLUGIN_DIR}/"
cp "${SCRIPT_DIR}/Panel.qml" "${PLUGIN_DIR}/"
cp "${SCRIPT_DIR}/ChipsRow.qml" "${PLUGIN_DIR}/"
cp "${SCRIPT_DIR}/LabelledRow.qml" "${PLUGIN_DIR}/"

# 4. Enable plugin in Omarchy
if command -v omarchy >/dev/null 2>&1; then
    echo "Enabling qubo.purifier in Omarchy..."
    omarchy plugin enable qubo.purifier centerEnd 2>/dev/null || true
    if command -v omarchy-restart-shell >/dev/null 2>&1; then
        echo "Restarting Omarchy shell..."
        omarchy-restart-shell || true
    fi
fi

echo "==> Installation complete!"
echo "If this is your first time, log in using:"
echo "    qubopy login --email <email>"
echo "    or: qubopy login-phone --phone <10-digit-phone>"
