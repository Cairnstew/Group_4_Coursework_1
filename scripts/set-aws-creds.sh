#!/usr/bin/env bash

AWS_DIR="$HOME/.aws"
CRED_FILE="$AWS_DIR/credentials"

mkdir -p "$AWS_DIR"

echo "Paste your AWS credentials below."
echo "Press Ctrl+D when finished."
echo ""

cat > "$CRED_FILE"

echo ""
echo "Credentials saved to $CRED_FILE"