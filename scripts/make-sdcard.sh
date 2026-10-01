#!/usr/bin/env bash
set -Eeuo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ $# -ne 3 ]]; then
    echo "Usage: $0 INPUT_DIR OUTPUT_DIR standard|rva23" >&2
    exit 2
fi
case "$3" in
    standard) opensbi_image=fw_dynamic-k1.itb ;;
    rva23) opensbi_image=fw_dynamic-k1-rva23.itb ;;
    *) echo "Unknown firmware variant: $3" >&2; exit 2 ;;
esac
command -v genimage >/dev/null
input_dir=$(cd -- "$1" && pwd)
mkdir -p -- "$2"
output_dir=$(cd -- "$2" && pwd)
for artifact in factory/bootinfo_sd.bin factory/FSBL.bin env.bin "$opensbi_image" u-boot.itb; do
    if [[ ! -f "$input_dir/$artifact" ]]; then
        echo "Missing artifact: $input_dir/$artifact" >&2
        exit 1
    fi
done

image_name="k1-sdcard-boot-$3.img"
work_dir=$(mktemp -d)
trap 'rm -rf -- "$work_dir"' EXIT
mkdir -p "$work_dir/root"
sed -e "s/@IMAGE_NAME@/$image_name/g" \
    -e "s/@OPENSBI_IMAGE@/$opensbi_image/g" \
    "$script_dir/genimage-sdcard.cfg" > "$work_dir/genimage.cfg"
genimage --config "$work_dir/genimage.cfg" \
    --inputpath "$input_dir" --outputpath "$output_dir" \
    --rootpath "$work_dir/root" --tmppath "$work_dir/tmp"
(cd -- "$output_dir" && sha256sum "$image_name" > "$image_name.sha256")
echo "SD boot image: $output_dir/$image_name"
