#!/usr/bin/env bash

WORKING_DIR="$(pwd)"
OUT_DIR="${WORKING_DIR}/out"

rm -rf "$OUT_DIR" && mkdir "$OUT_DIR"

COMMON_FLAGS=(
    "-Wall"
    "-Os"
    "-ffunction-sections"
    "-fdata-sections"
    "-finline-functions"
    "-flto=full"
    "-fmerge-all-constants"
    "-fshort-enums"
    "-integrated-as"
    "-fvisibility=hidden"
)

ARCH_FLAGS=(
    "-mmcu=atmega328p"
    "-DF_CPU=16000000L"
    "-DARDUINO=10808"
    "-DARDUINO_AVR_UNO"
    "-DARDUINO_ARCH_AVR"
)

CPP_FLAGS=(
    "-std=gnu++11"
    "-fpermissive"
    "-fno-threadsafe-statics"
    "-fno-exceptions"
    "-fno-rtti"
)

C_FLAGS=(
    "-std=gnu11"
    "-fno-fat-lto-objects"
)

AS_FLAGS=(
    "-x"
    "assembler-with-cpp"
)

#LINK_FLAGS

#rm -rf sysroot
#wget "https://github.com/ZakKemble/avr-gcc-build/releases/download/v14.1.0-1/avr-gcc-14.1.0-x64-linux.tar.bz2"
#tar -xf avr-gcc-14.1.0-x64-linux.tar.bz2 && rm -rf avr-gcc-14.1.0-x64-linux.tar.bz2
#mv avr-gcc-14.1.0-x64-linux sysroot
SYSROOT_DIR="${WORKING_DIR}/sysroot"

ARCH_FLAGS+=(
    "--sysroot=${SYSROOT_DIR}"
    "-I${SYSROOT_DIR}/avr/include"
)

#rm -rf "${WORKING_DIR}/core/arduino/avr"
#git clone "https://github.com/ClangBuiltArduino/core_arduino-avr.git" "${WORKING_DIR}/core/arduino/avr" --depth=1
AVR_CORE_DIR="${WORKING_DIR}/core/arduino/avr"

ARCH_FLAGS+=(
    "-I${AVR_CORE_DIR}/cores/arduino"
    "-I${AVR_CORE_DIR}/variants/standard"
)

job_c() {
    local variant="${1}"
    local outfile="$(basename $2).o"
    mkdir -p "${OUT_DIR}/${variant}"
    echo "CC: ${OUT_DIR}/${variant}/${outfile}"

    clang --target=avr "${ARCH_FLAGS[@]}" "${COMMON_FLAGS[@]}" "${C_FLAGS[@]}" -o "${OUT_DIR}/${variant}/${outfile}" -c "$2"
}

job_cpp() {
    local variant="${1}"
    local outfile="$(basename $2).o"
    mkdir -p "${OUT_DIR}/${variant}"
    echo "CPP: ${OUT_DIR}/${variant}/${outfile}"

    local original_common_flags=("${COMMON_FLAGS[@]}")
    if [[ $3 == "nolto" ]]; then
        COMMON_FLAGS+=("-fno-lto")
    fi
    clang++ --target=avr "${ARCH_FLAGS[@]}" "${COMMON_FLAGS[@]}" "${CPP_FLAGS[@]}" -o "${OUT_DIR}/${variant}/${outfile}" -c "$2"
    COMMON_FLAGS=("${original_common_flags[@]}")
}

job_s() {
    local variant="${1}"
    local outfile="$(basename $2).o"
    mkdir -p "${OUT_DIR}/${variant}"
    echo "CC: ${OUT_DIR}/${variant}/${outfile}"

    clang --target=avr "${ARCH_FLAGS[@]}" "${COMMON_FLAGS[@]}" "${AS_FLAGS[@]}" -o "${OUT_DIR}/${variant}/${outfile}" -c "$2"
}

compile_and_link_core() {
    for c_file in "${AVR_CORE_DIR}"/cores/arduino/*.c; do
        if [[ -f "$c_file" ]]; then
            job_c "core" "$c_file"
        fi
    done
    for cpp_file in "${AVR_CORE_DIR}"/cores/arduino/*.cpp; do
        if [[ -f "$cpp_file" ]]; then
            if echo "$cpp_file" | grep -q "cores/arduino/HardwareSerial0.cpp"; then
                echo "nolto: $cpp_file"
                job_cpp "core" "$cpp_file" "nolto"
            else
                job_cpp "core" "$cpp_file"
            fi
        fi
    done
    for s_file in "${AVR_CORE_DIR}"/cores/arduino/*.S; do
        if [[ -f "$s_file" ]]; then
            job_s "core" "$s_file"
        fi
    done
    llvm-ar rc "${OUT_DIR}/libArduinoCore.a" "${OUT_DIR}/core/"*
    llvm-ranlib "${OUT_DIR}/libArduinoCore.a"
}

compile_and_link_core
mkdir -p "${OUT_DIR}/main"
job_cpp "main" "$(pwd)/main.cpp"

clang++ --target=avr -v -o firmware.elf "${ARCH_FLAGS[@]}" -Os -Wl,--strip-debug -Wl,--plugin-opt=-import-instr-limit=5 -Wl,--print-gc-sections -flto=full -finline-functions -ffunction-sections -fdata-sections -fpermissive -fno-exceptions -fno-threadsafe-statics -fno-rtti -L"${SYSROOT_DIR}/lib" -Wl,--gc-sections "${OUT_DIR}/main/main.cpp.o" "${OUT_DIR}/libArduinoCore.a" -fuse-linker-plugin
