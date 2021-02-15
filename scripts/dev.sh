#!/usr/bin/env bash
set -euo pipefail

hugo server --bind "0.0.0.0" --baseURL "http://goldfynch.local:1313/"
