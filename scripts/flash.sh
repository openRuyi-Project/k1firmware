#!/usr/bin/env bash
set -Eeuo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"

variant=${1:-standard}
case "${variant}" in
standard)
    opensbi_image=fw_dynamic-k1.itb
    ;;
rva23)
    opensbi_image=fw_dynamic-k1-rva23.itb
    ;;
*)
    echo "Usage: $0 [standard|rva23]" >&2
    exit 2
    ;;
esac

required_files=(
    factory/FSBL.bin
    factory/bootinfo_spinor.bin
    partition_2M.json
    env.bin
    "${opensbi_image}"
    u-boot.itb
)

if ! command -v fastboot >/dev/null 2>&1; then
    echo "Error: fastboot was not found in PATH." >&2
    exit 1
fi

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "Error: missing artifact: $file" >&2
        exit 1
    fi
done

run_fastboot() {
    echo "+ fastboot $*"
    fastboot "$@"
}

echo "Staging FSBL..."
run_fastboot stage factory/FSBL.bin
run_fastboot continue
sleep 1

echo "Staging U-Boot..."
run_fastboot stage u-boot.itb
run_fastboot continue
sleep 1

echo "Flashing SPI NOR..."
run_fastboot flash mtd partition_2M.json
run_fastboot flash bootinfo factory/bootinfo_spinor.bin
run_fastboot flash fsbl factory/FSBL.bin
run_fastboot flash env env.bin
run_fastboot flash opensbi "${opensbi_image}"
run_fastboot flash uboot u-boot.itb

echo "SPI NOR flashing completed successfully."
