# ChisFlash-MBC5

> An open-source `Game Boy / Game Boy Color` MBC5 flash cartridge project based on a `CPLD (EPM240)`. It includes multiple versions: `8M`, `8M Plus`, `32M MAX`, and `32M MAX R0603`, supporting both single-game cartridges and multi-game cartridge configurations.

Simplified Chinese | [English](README_EN.md)

Documentation: [docs/README.md](docs/README.md)

[![License: GPL v3](https://img.shields.io/badge/License-GPLv3-blue.svg)](LICENSE)
![Platform: GB/GBC](https://img.shields.io/badge/Platform-GB%20%2F%20GBC-4f8bff.svg)
![CPLD: EPM240](https://img.shields.io/badge/CPLD-EPM240-ff8c42.svg)

![ChisFlash_MBC5_8M](picture/ChisFlash_MBC5_8M.png)

## Project Overview

`ChisFlash-MBC5` is an open-source flash cartridge solution for GB / GBC. Its core concept is to use a `CPLD` to replace the increasingly scarce original `MBC5` chip, reducing reliance on salvaged MBC5 chips.

The project is based on the open-source `NekoCart-GB` project. The PCB and schematic were redrawn, the power supply design was modified, and the firmware was adapted, resulting in the current range of MBC5 cartridge designs that can be manufactured, programmed, and further improved.

## Key Features

- Uses a `CPLD (EPM240)` to replace the original MBC5 controller
- The repository includes `Verilog` source code, `POF` firmware, `PCB` design files, `Gerber` production files, `GBX config` configuration files, and menu ROMs
- Covers multiple versions: `8M`, `8M Plus`, `32M MAX`, and `32M MAX R0603`
- The `8M` version supports `single cartridge / 3-in-1 / 4-in-1`
- The `MAX` version supports `16-in-1`
- Can be programmed using `gbcburn` on an NDS, reducing the need to purchase a separate programmer

## Documentation Index

- Documentation: [docs/README.md](docs/README.md)
- Hardware versions and corresponding files: [docs/variants.md](docs/variants.md)
- Assembly and programming instructions: [docs/build-notes.md](docs/build-notes.md)
- Compatibility and current status: [docs/compatibility.md](docs/compatibility.md)
- Repository structure: [docs/source-layout.md](docs/source-layout.md)
- Licensing information: [docs/licensing.md](docs/licensing.md)

## Version Overview

| Version | Capacity | Main File | Description |
| --- | --- | --- | --- |
| `ChisFlash_MBC5_8M` | 8M | `pcb/ProDoc_ChisFlash-MBC5-v1.21_8M.epro` | Standard version |
| `ChisFlash_MBC5_8M_PLUS` | 8M | `pcb/ProDoc_ChisFlash-MBC5-Plus-v1.21_8M.epro` | Plus version, uses level-shifting ICs |
| `ChisFlash_MBC5_MAX_32M` | 32M | `pcb/ProDoc_ChisFlash-MBC5-MAX-v1.22_32M.epro` | MAX version, supports larger capacities and more multi-game configurations |
| `ChisFlash_MBC5_MAX_32M_R0603` | 32M | `pcb/ProDoc_ChisFlash-MBC5-MAX-v1.22-R0603_32M..epro` | MAX R0603 version |

## Repository Navigation

- `verilog/`: CPLD logic source code
- `pof/`: CPLD firmware ready for programming
- `pcb/`: Original PCB design files
- `gerber/`: Compressed Gerber production files
- `menu/`: Multi-game cartridge menu program
- `GBX_config/`: Configuration files for GBxCart / GB Operator
- `picture/`: PCB images

## Quick Start

1. First, confirm which hardware version you want to build. Refer to [docs/variants.md](docs/variants.md).
2. Select the corresponding `PCB` project or `Gerber` files and order the boards for manufacture.
3. Complete the soldering according to the assembly notes in [docs/build-notes.md](docs/build-notes.md).
4. Program the CPLD with the `POF` firmware matching your hardware version.
5. If building a multi-game cartridge, continue by using the menu ROM from `menu/` together with the configuration files in `GBX_config/`.
6. Before testing the cartridge in a console, first verify that the battery, resistor network, firmware version, and hardware version are correctly matched.

## Assembly Notes

- After soldering is complete, measure the voltage from the positive battery terminal to one side of the resistor. If the voltage slowly drops or there is no voltage, the battery is usually not making good contact with the PCB underneath. Add a small amount of solder to the underside to provide better contact with the battery.
- On the `Plus` version resistor network, the leftmost resistor is `30Ω`, while the other seven resistors are `470Ω`.
- `v1.1` firmware is compatible with hardware versions `v1.1 / v1.2 / v1.21`.
- `v1.21` firmware is only compatible with hardware versions `v1.21 / v1.22`.

## Features and Compatibility Status

- The `8M` version supports single cartridges, `3-in-1 (1+2+4)`, and `4-in-1 (1+2+2+2)`
- The `MAX` version supports `16-in-1`
- Theoretically supports `MBC5` games and is also compatible with some `MBC1 / MBC2 / MBC3` games
- The `Plus` version uses level-shifting ICs. Full compatibility of the standard version with AP handheld consoles still requires further testing
- Future plans include support for rumble functionality and additional multi-game configurations

See [docs/compatibility.md](docs/compatibility.md) for more information.

## Licensing

- The repository currently includes a `GPL-3.0` license file.
- If you plan to manufacture commercial products based on this project, it is recommended that you contact the author first to clarify the source/version, attribution requirements, and collaboration boundaries.

## Changelog

- `2024-10-09`: Updated the standard `v1.1` and enhanced `v1.1` versions
- `2024-11-28`: Updated the standard `v1.2` and enhanced `v1.2` versions; disconnected `RST` from the NOR flash and pulled it high, enabling programming using an `NDS`
- `2024-12-19`: Updated the standard `v1.21`, enlarging the negative battery terminal solder pad; updated the enhanced `v1.21`, adding compatible resistor-network pads and enlarging the negative battery terminal solder pad
- `2025-02-26`: Updated the `1.2` firmware; the `8M` version now supports `3-in-1 (1+2+4)`, `4-in-1 (1+2+2+2)`, and single-cartridge configurations

## Acknowledgements and Related Projects

- `NekoCart-GB`: https://github.com/zephray/NekoCart-GB
- Contributor who provided the NDS programming solution: `@shn`
- Open-source GBA flash cartridge `ChisFlash`: https://github.com/ChisBread/ChisFlash
- GBA-sized `mini-ChisMBC5`: <https://oshwhub.com/cidazl/mini-chis-mbc5gbc-burn-card>
- Cartridge programmer designed specifically for GBA, `ChisLink`: https://github.com/ChisBread/ChisLink
- Programmer for ChisFlash, `beggar_socket`: https://github.com/julpage/beggar_socket
- `beggar_socket` web application: https://github.com/tautcony/beggar_socket

## Images

### ChisFlash_MBC5_8M

![ChisFlash_MBC5_8M](picture/ChisFlash_MBC5_8M.png)

### ChisFlash_MBC5_8M_PLUS

![ChisFlash_MBC5_8M_PLUS](picture/ChisFlash_MBC5_8M_PLUS.png)

### ChisFlash_MBC5_MAX_32M

![ChisFlash_MBC5_MAX_32M](picture/ChisFlash_MBC5_MAX_32M.png)

### ChisFlash_MBC5_MAX_32M_R0603

![ChisFlash_MBC5_MAX_32M_R0603](picture/ChisFlash_MBC5_MAX_32M_R0603.png)
