#!/usr/bin/env bash
set -e

echo "========================================="
echo "  Building Flutter APK..."
echo "========================================="

flutter build apk --release 2>&1

echo ""
echo "========================================="
echo "  APK built successfully!"
echo "  Location: build/app/outputs/flutter-apk/app-release.apk"
echo "========================================="
