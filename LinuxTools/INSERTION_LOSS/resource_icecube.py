"""Hardware Config for Meta IceCube Platform"""

# pylint:disable=line-too-long, too-many-lines, too-many-function-args, bare-except

import enum
import pathlib
import sys
import re
from unidiag.modules.resource.resource_meta import (
    IOB_I2C_MAPPING,
    DOM1_I2C_MAPPING,
    DOM2_I2C_MAPPING,
)

from unidiag.modules.resource.resource_meta import GPIO_NAME_FBOSS

PCBA = enum.Enum(
    "PCBA",
    (
        "SMB",
        "MCB",
        "COMe",
        "PIC_T",
        "PIC_B",
        "BMC",
        "IO_R",
        "QSFP28",
    ),
)

PHASE = enum.IntFlag("PHASE", ("EVT", "DVT", "PVT", "MP"))

# I2C Dict
# Naming: I2C_DEV_[PCBA]_[PHASE]
# Key: Device name: str
# Value: Tuple:
#            0. If hosted by BMC: bool
#            1. PCBA location: enum(int)
#            2. Project phase: enum.flag
#            3. subversion (None for no second-source pcba): int or None
#            4. Controller info (to locate the system i2c bus): tuple
#            5. logic address: int
#            6. Driver name: str|None
#            7. Test func: Callable|None
I2C_DEV = {
    # IOB as the host:
    "Platform EEPROM": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("i801",),
        0x53,
        "24c02",
        None,
    ),
    "BMC EEPROM": (
        False,
        PCBA.BMC,
        PHASE.EVT,
        None,
        ("IOB", 0),
        0x51,
        "24c64",
        None,
    ),
    "Thermal Sensor LM75": (
        False,
        PCBA.BMC,
        PHASE.EVT,
        None,
        ("IOB", 0),
        0x4A,
        "lm75b",
        None,
    ),
    "PCA9546": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 1),
        0x70,
        "pca9546",
        None,
    ),
    "SCM CPLD": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 2),
        0x35,
        "icecube_scmcpld",
        None,
    ),
    "Clock Gen#1 Si5361": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        None,
        ("IOB", 3),
        0x54,
        None,
        None,
    ),
    "SMB ADC1 ADC128D818": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        None,
        ("IOB", 3),
        0x1F,
        "adc128d818",
        None,
    ),
    "48V/12V PWR Brick 1": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 4),
        0x60,
        None,
        None,
    ),
    "48V/12V PWR Brick 2": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 4),
        0x61,
        None,
        None,
    ),
    "LM75B COMe Inlet Thermal Sensor": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 5),
        0x4D,
        "lm75b",
        None,
    ),
    "LM75B PWR Brick Inlet Thermal Sensor": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 5),
        0x4F,
        "lm75b",
        None,
    ),
    "Clock Gen#2 Si5361": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        None,
        ("IOB", 6),
        0x54,
        None,
        None,
    ),
    "SMB ADC2 ADC128D818": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        None,
        ("IOB", 6),
        0x35,
        "adc128d818",
        None,
    ),
    # "TH6 Switch ASIC": (False, PCBA.SMB, PHASE.EVT, None, ("IOB", 7), 0xff, None, None),
    "48V/12V PWR Brick 3": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 8),
        0x62,
        None,
        None,
    ),
    "PCA9548": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        None,
        ("IOB", 9),
        0x70,
        "pca9548",
        None,
    ),
    "Inlet TH6 Thermal Sensor LM75B": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        None,
        ("IOB", 10),
        0x48,
        "lm75b",
        None,
    ),
    "Outlet TH6 Thermal Sensor LM75B": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        None,
        ("IOB", 10),
        0x49,
        "lm75b",
        None,
    ),
    "SMB CPLD": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        None,
        ("IOB", 11),
        0x33,
        "icecube_scmcpld",
        None,
    ),
    "SMB IDEEPROM": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        None,
        ("IOB", 11),
        0x50,
        "24c64",
        None,
    ),
    "PCIe Gen4 Clk Buffer RC19004": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 12),
        0x6F,
        None,
        None,
    ),
    "LM75B COMe Outlet Thermal Sensor": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 12),
        0x4E,
        "lm75b",
        None,
    ),
    "MCB CPLD FAN Control": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 13),
        0x33,
        "icecube_fancpld",
        None,
    ),
    "MCB CPLD MCB Control": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 13),
        0x60,
        "icecube_mcbcpld",
        None,
    ),
    "Chassis EEPROM x86": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 14),
        0x53,
        "24c64",
        None,
    ),
    "PTPS25990 Load Switch": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 15),
        0x4C,
        "tps25990",
        None,
    ),
    "88E6321 EEPROM": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 16),
        0x50,
        "24c02",
        None,
    ),
    "COMe CPLD #1": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("IOB", 17),
        0x0F,
        None,
        None,
    ),
    "COMe CPLD #2": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("IOB", 17),
        0x1F,
        None,
        None,
    ),
    "COMe FRU": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("IOB", 17),
        0x56,
        "24c128",
        None,
    ),
    "COMe OUTLET Sensor": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("IOB", 17),
        0x4A,
        "tmp75",
        None,
    ),
    "COMe INLET Sensor": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("IOB", 17),
        0x48,
        "tmp75",
        None,
    ),
    "Fan1_Sensor INA238": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 18),
        0x40,
        "ina238",
        None,
    ),
    "Fan2_Sensor INA238": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 19),
        0x41,
        "ina238",
        None,
    ),
    "Fan3_HSC INA238": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 20),
        0x44,
        "ina238",
        None,
    ),
    "Fan4_HSC INA238": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 21),
        0x45,
        "ina238",
        None,
    ),
    "48V HSC LTC4287": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 22),
        0x11,
        "ltc4287",
        None,
    ),
    "MCB ADC1 ADC128D818": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 23),
        0x35,
        "adc128d818",
        None,
    ),
    "MCB ADC2 ADC128D818": (
        False,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("IOB", 23),
        0x37,
        "adc128d818",
        None,
    ),
    "E1.S SSD": (False, PCBA.IO_R, PHASE.EVT, None, ("IOB", 24), 0x6A, None, None),
    "PIC_T CPLD": (
        False,
        PCBA.PIC_T,
        PHASE.EVT,
        None,
        ("IOB", 25),
        0x33,
        "icecube_piccpld",
        None,
    ),
    "PIC_T IDEEPROM": (
        False,
        PCBA.PIC_T,
        PHASE.EVT,
        None,
        ("IOB", 25),
        0x50,
        "24c64",
        None,
    ),
    "PIC_B CPLD": (
        False,
        PCBA.PIC_B,
        PHASE.EVT,
        None,
        ("IOB", 26),
        0x33,
        "icecube_piccpld",
        None,
    ),
    "PIC_B IDEEPROM": (
        False,
        PCBA.PIC_B,
        PHASE.EVT,
        None,
        ("IOB", 26),
        0x50,
        "24c64",
        None,
    ),
    # "QSFP28 TH6 MGMT": (
    #     False,
    #     PCBA.QSFP28,
    #     PHASE.EVT,
    #     None,
    #     ("IOB", 27),
    #     0xFF,
    #     None,
    #     None,
    # ),
    # PCA9546 as the host:
    "COMe CPLD #3": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("PCA9546", 0),
        0x40,
        None,
        None,
    ),
    # COMe Main Source
    "VNN_PCH MAIN": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        1,
        ("PCA9546", 1),
        0x11,
        "tda38640",
        None,
    ),
    "1V05_STBY MAIN": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        1,
        ("PCA9546", 1),
        0x22,
        "tda38640",
        None,
    ),
    "1V8_STBY MAIN": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        1,
        ("PCA9546", 1),
        0x76,
        "xdpe15284",
        None,
    ),
    "VDDQ MAIN": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        1,
        ("PCA9546", 1),
        0x45,
        "tda38640",
        None,
    ),
    "VCCANA_CPU MAIN": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        1,
        ("PCA9546", 1),
        0x66,
        "tda38640",
        None,
    ),
    # COMe Second Source
    "VNN_PCH SECOND": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        2,
        ("PCA9546", 1),
        0x11,
        "mp9941",
        None,
    ),
    "1V05_STBY SECOND": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        2,
        ("PCA9546", 1),
        0x22,
        "mp9941",
        None,
    ),
    "1V8_STBY SECOND": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        2,
        ("PCA9546", 1),
        0x76,
        "mp2993",
        None,
    ),
    "VDDQ SECOND": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        2,
        ("PCA9546", 1),
        0x45,
        "mp9941",
        None,
    ),
    "VCCANA_CPU SECOND": (
        False,
        PCBA.COMe,
        PHASE.PVT,
        2,
        ("PCA9546", 1),
        0x66,
        "mp9941",
        None,
    ),
    # "I210": (False, PCBA.COMe, PHASE.EVT, None, ("PCA9546", 3), 0x49, None, None),
    # PCA9548 as the host:
    ## IFX source:
    "Infineon - XDPE12284C_0": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 0),
        0xE0,
        "xdpe12284",
        None,
    ),
    "Infineon - XDPE12284C_1": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 1),
        0xE0,
        "xdpe12284",
        None,
    ),
    "Infineon - XDPE12284C_2": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 2),
        0xE0,
        "xdpe12284",
        None,
    ),
    "Infineon - XDPE1A2G5B": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 2),
        0x76,
        "pmbus",
        None,
    ),
    "Infineon - XDPE12284C_3": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 3),
        0xE0,
        "xdpe12284",
        None,
    ),
    "Infineon - XDPE12284C_4": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 4),
        0xE0,
        "xdpe12284",
        None,
    ),
    "Infineon - XDPE12284C_5_0": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 5),
        0xE0,
        "xdpe12284",
        None,
    ),
    "Infineon - XDPE12284C_5_1": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 5),
        0xD4,
        "xdpe12284",
        None,
    ),
    "Infineon - XDPE12284C_6": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 6),
        0xE0,
        "xdpe12284",
        None,
    ),
    "Infineon - XDPE12284C_7": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        1,
        ("PCA9548", 7),
        0xE0,
        "xdpe12284",
        None,
    ),
    ## Renesas source:
    "P0R8V_PT_0 Controller - RAA228244": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 0),
        0x7B,
        "pmbus",
        None,
    ),
    "P0R8V_PT_2 Controller - RAA228244": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 1),
        0x7B,
        "pmbus",
        None,
    ),
    "P0R72V_PB_TRVDD Controller - RAA228244": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 2),
        0x7B,
        "pmbus",
        None,
    ),
    "VDDcore Controller - RAA228249": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 2),
        0x21,
        "pmbus",
        None,
    ),
    "P0R8V_PT_7 Controller RAA228244": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 3),
        0x7B,
        "pmbus",
        None,
    ),
    "P1R5V_RVDD_0 Controller RAA228244": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 4),
        0x7B,
        "pmbus",
        None,
    ),
    "P1R5V_RVDD_1 Controller RAA228244": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 5),
        0x7B,
        "pmbus",
        None,
    ),
    "XP0R8V_PT_5 Controller - RAA228244": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 5),
        0x7D,
        "pmbus",
        None,
    ),
    "P0R9V_TRVDD_0 Controller - RAA228244": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 6),
        0x7B,
        "pmbus",
        None,
    ),
    "P0R9V_TRVDD_1 Controller - RAA228244": (
        False,
        PCBA.SMB,
        PHASE.EVT,
        2,
        ("PCA9548", 7),
        0x7B,
        "pmbus",
        None,
    ),
    # DOM as the host
    ## Renesas source
    "PIC_T XP3R3V_OSFP_L RAA228244": (
        False,
        PCBA.PIC_T,
        PHASE.EVT,
        2,
        ("DOM1", 33),
        0x21,
        "pmbus",
        None,
    ),
    "PIC_T XP3R3V_OSFP_R RAA228249": (
        False,
        PCBA.PIC_T,
        PHASE.EVT,
        2,
        ("DOM1", 33),
        0x23,
        "pmbus",
        None,
    ),
    ## IFX source
    "PIC_T XP3R3V_OSFP_L XDPE1A2G5B": (
        False,
        PCBA.PIC_T,
        PHASE.EVT,
        1,
        ("DOM1", 33),
        0x66,
        "pmbus",
        None,
    ),
    "PIC_T XP3R3V_OSFP_R XDPE1A2G5B": (
        False,
        PCBA.PIC_T,
        PHASE.EVT,
        1,
        ("DOM1", 33),
        0x70,
        "pmbus",
        None,
    ),
    "PIC_T ADC ADC128D818": (
        False,
        PCBA.PIC_T,
        PHASE.EVT,
        None,
        ("DOM1", 32),
        0x1F,
        "adc128d818",
        None,
    ),
    "PIC_T Thermal Sensor LM75B #1": (
        False,
        PCBA.PIC_T,
        PHASE.EVT,
        None,
        ("DOM1", 32),
        0x48,
        "lm75b",
        None,
    ),
    "PIC_T Thermal Sensor LM75B #2": (
        False,
        PCBA.PIC_T,
        PHASE.EVT,
        None,
        ("DOM1", 32),
        0x49,
        "lm75b",
        None,
    ),
    ## Renesas source
    "PIC_B XP3R3V_OSFP_L RAA228249": (
        False,
        PCBA.PIC_B,
        PHASE.EVT,
        2,
        ("DOM2", 33),
        0x21,
        "pmbus",
        None,
    ),
    "PIC_B XP3R3V_OSFP_R RAA228249": (
        False,
        PCBA.PIC_B,
        PHASE.EVT,
        2,
        ("DOM2", 33),
        0x23,
        "pmbus",
        None,
    ),
    ## IFX source
    "PIC_B XP3R3V_OSFP_L XDPE1A2G5B": (
        False,
        PCBA.PIC_B,
        PHASE.EVT,
        1,
        ("DOM2", 33),
        0x66,
        "pmbus",
        None,
    ),
    "PIC_B XP3R3V_OSFP_R XDPE1A2G5B": (
        False,
        PCBA.PIC_B,
        PHASE.EVT,
        1,
        ("DOM2", 33),
        0x70,
        "pmbus",
        None,
    ),
    "PIC_B ADC ADC128D818": (
        False,
        PCBA.PIC_B,
        PHASE.EVT,
        None,
        ("DOM2", 32),
        0x1F,
        "adc128d818",
        None,
    ),
    "PIC_B Thermal Sensor LM75B #1": (
        False,
        PCBA.PIC_B,
        PHASE.EVT,
        None,
        ("DOM2", 32),
        0x48,
        "lm75b",
        None,
    ),
    "PIC_B Thermal Sensor LM75B #2": (
        False,
        PCBA.PIC_B,
        PHASE.EVT,
        None,
        ("DOM2", 32),
        0x49,
        "lm75b",
        None,
    ),
    # BMC I2C devices:
    ## Note: channel number is bus number + 1
    ## (Based on the HW diagram)
    "COMe CPLD #1 BMC": (
        True,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("BMC", 1),
        0x0F,
        None,
        None,
    ),
    "COMe CPLD #2 BMC": (
        True,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("BMC", 1),
        0x1F,
        None,
        None,
    ),
    "COMe FRU BMC": (
        True,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("BMC", 1),
        0x56,
        "24c128",
        None,
    ),
    "COMe OUTLET Sensor BMC": (
        True,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("BMC", 1),
        0x4A,
        "tmp75",
        None,
    ),
    "COMe INLET Sensor BMC": (
        True,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("BMC", 1),
        0x48,
        "tmp75",
        None,
    ),
    "SCM CPLD BMC": (True, PCBA.MCB, PHASE.EVT, None, ("BMC", 2), 0x35, None, None),
    "Chassis EEPROM BMC": (
        True,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("BMC", 7),
        0x53,
        "24c64",
        None,
    ),
    ## COMe VR Parts access by BMC
    "VNN_PCH BMC": (
        True,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("BMC", 12),
        0x11,
        None,
        None,
    ),
    "1V05_STBY BMC": (
        True,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("BMC", 12),
        0x22,
        None,
        None,
    ),
    "1V8_STBY BMC": (
        True,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("BMC", 12),
        0x76,
        None,
        None,
    ),
    "VDDQ BMC": (True, PCBA.COMe, PHASE.PVT, None, ("BMC", 12), 0x45, None, None),
    "VCCANA_CPU BMC": (
        True,
        PCBA.COMe,
        PHASE.PVT,
        None,
        ("BMC", 12),
        0x66,
        None,
        None,
    ),
    "MCB CPLD BMC": (
        True,
        PCBA.MCB,
        PHASE.EVT,
        None,
        ("BMC", 13),
        0x33,
        None,
        None,
    ),
}


def bus_finder_pca9548(
    channel: int,
    _bus_pca9548: int = IOB_I2C_MAPPING[I2C_DEV["PCA9548"][4][1]],
    _addr_pca9548: int = I2C_DEV["PCA9548"][5],
) -> int:
    """
    Find the extended channel's system bus on PCA9548
    """
    _path = pathlib.Path(f"/sys/bus/i2c/devices/{_bus_pca9548}-{_addr_pca9548:04x}")
    try:
        if (_path / "name").read_text(encoding="utf-8").rstrip() != "pca9548":
            print(
                f"Warning: PCA9548 at {_bus_pca9548}-{_addr_pca9548:04x} not found!",
                file=sys.stderr,
            )
            return -1
        _subpaths = list((_path / f"channel-{channel}" / "i2c-dev").glob("i2c-*"))
    except FileNotFoundError:
        print(
            f"Warning: I2C bus not found on PCA9546 channel {channel}!", file=sys.stderr
        )
        return -1
    if len(_subpaths) > 1:
        print(
            f"Warning: More than one I2C bus found on PCA9548 channel {channel}. Accepting the first one.",
            file=sys.stderr,
        )
    elif len(_subpaths) == 0:
        print(
            f"Warning: I2C bus not found on PCA9546 channel {channel}!", file=sys.stderr
        )
        return -1
    return int(_subpaths[0].name.removeprefix("i2c-"))


def bus_finder_pac9546(
    channel: int,
    _bus_pac9546: int = IOB_I2C_MAPPING[I2C_DEV["PCA9546"][4][1]],
    _addr_pac9546: int = I2C_DEV["PCA9546"][5],
) -> int:
    """
    Find the extended channel's system bus on PCA9546
    """
    _path = pathlib.Path(f"/sys/bus/i2c/devices/{_bus_pac9546}-{_addr_pac9546:04x}")
    if (_path / "name").read_text(encoding="utf-8").rstrip() != "pca9546":
        print(
            f"Warning: PCA9546 at {_bus_pac9546}-{_addr_pac9546:04x} not found!",
            file=sys.stderr,
        )
        return -1
    _subpaths = list((_path / f"channel-{channel}" / "i2c-dev").glob("i2c-*"))
    if len(_subpaths) > 1:
        print(
            f"Warning: More than one I2C bus found on PCA9546 channel {channel}. Accepting the first one.",
            file=sys.stderr,
        )
    elif len(_subpaths) == 0:
        print(
            f"Warning: I2C bus not found on PCA9546 channel {channel}!", file=sys.stderr
        )
        return -1
    return int(_subpaths[0].name.removeprefix("i2c-"))


def bus_finder_i801() -> int:
    """
    Find the system bus of i801
    """
    for path in pathlib.Path(r"/sys/bus/pci/drivers/i801_smbus").iterdir():
        if re.match(r"[\da-f]{4}\:[\da-f]{2}\:[\da-f]{2}\.[\da-f]+", path.name):
            sysfs_path = str(path)
            break
    else:
        raise FileNotFoundError("i801 not found!")
    for path in pathlib.Path(sysfs_path).iterdir():
        if path.name.startswith("i2c-"):
            return int(path.name.removeprefix("i2c-"))
    raise FileNotFoundError("i801 not found!")


def bus_finder_bmc(channel: int) -> int:
    """
    Find the system bus of BMC
    """
    return channel - 1


BUS_FINDER = {
    "IOB": lambda channel: IOB_I2C_MAPPING[channel],
    "DOM1": lambda channel: DOM1_I2C_MAPPING[channel],
    "DOM2": lambda channel: DOM2_I2C_MAPPING[channel],
    "PCA9548": bus_finder_pca9548,
    "PCA9546": bus_finder_pac9546,
    "i801": bus_finder_i801,
    "BMC": bus_finder_bmc,
}

PCBA_PHASE_MAP = dict.fromkeys(PCBA, PHASE.EVT)
PCBA_SOURCE_MAP = dict.fromkeys(PCBA, 1)
PCBA_SOURCE_MAP[PCBA.COMe] = 2
PCBA_SOURCE_MAP[PCBA.PIC_B] = 1
PCBA_SOURCE_MAP[PCBA.PIC_T] = 1
PCBA_FRU_SET = {
    "Platform EEPROM",
    "BMC EEPROM",
    "SMB IDEEPROM",
    "Chassis EEPROM x86",
    "Chassis EEPROM BMC",
    "PIC_T IDEEPROM",
    "PIC_B IDEEPROM",
    "COMe FRU",
    "COMe FRU BMC",
}

PCBA_FRU_MAP = {
    PCBA.SMB: "SMB IDEEPROM",
    PCBA.MCB: "Platform EEPROM",
    PCBA.COMe: "COMe FRU",
    PCBA.PIC_T: "PIC_T IDEEPROM",
    PCBA.PIC_B: "PIC_B IDEEPROM",
    PCBA.BMC: "BMC EEPROM",
}

# Change this value with the project
PCBA_DEFAULT_VER = {
    PCBA.SMB: [1, 1, 10],
    PCBA.MCB: [1, 1, 0],
    PCBA.COMe: [1, 1, 0],
    PCBA.PIC_T: [1, 1, 10],
    PCBA.PIC_B: [1, 1, 10],
    PCBA.BMC: [1, 1, 0],
    PCBA.QSFP28: [1, 1, 0],
    PCBA.IO_R: [1, 1, 0],
}


def _get_pcba_ver(pcba, use_cached=True) -> bytes:
    if use_cached:
        try:
            return pathlib.Path(f"/run/unidiag/version/{pcba.name}").read_bytes()
        except:
            return _get_pcba_ver(pcba, use_cached=False)
    pathlib.Path("/run/unidiag/version/").mkdir(parents=True, exist_ok=True)
    ret = [0xFF, 0xFF, 0xFF]
    fru = PCBA_FRU_MAP[pcba]
    bus = BUS_FINDER[I2C_DEV[fru][4][0]](*I2C_DEV[fru][4][1:])
    addr = I2C_DEV[fru][5]
    if not pathlib.Path(f"/sys/bus/i2c/devices/{bus}-{addr:04x}/eeprom").exists():
        print(
            f"Warning: No eeprom device found at i2c-{bus} {addr:#04x}. Please create it manually or use bootstrap.",
            file=sys.stderr,
        )
        return bytes(PCBA_DEFAULT_VER[pcba])
    with open(f"/sys/bus/i2c/devices/{bus}-{addr:04x}/eeprom", "rb") as _f:
        _header = _f.read(4)
        if _header not in {b"\xfb\xfb\x05\xff", b"\xfb\xfb\x06\xff"}:
            print(
                f"Warning: File header {_header} not recognized! EEPROM at i2c-{bus} {addr:#04x}.",
                file=sys.stderr,
            )
            return bytes(PCBA_DEFAULT_VER[pcba])
        try:
            while (_tc := _f.read(1)) is not None and _tc[0] != 250:
                _content = _f.read(_f.read(1)[0])
                if _tc[0] in (8, 9, 10):
                    ret[_tc[0] - 8] = _content[0]

        except:
            print(
                f"Waning: Failed to find all attributes for {pcba.name}! Using default {PCBA_DEFAULT_VER}.",
                file=sys.stderr,
            )
            return bytes(PCBA_DEFAULT_VER[pcba])
    pathlib.Path(f"/run/unidiag/version/{pcba.name}").write_bytes(bytes(ret))
    return bytes(ret)


def generate_ver_map(use_cached=True) -> dict:
    """Generate a pcba ver map"""
    return {pcba: _get_pcba_ver(pcba, use_cached=use_cached) for pcba in PCBA_FRU_MAP}


# pylint:disable=too-many-return-statements
def get_part_serial_number(type_code: int, use_cached=True) -> bytes:
    """Get the part number from Chassis EEPROM"""
    if type_code == 6:
        _name = "pn"
    elif type_code == 7:
        _name = "sn"
    else:
        raise ValueError("Need to specify a valid type code within 6 and 7.")
    if use_cached:
        try:
            return pathlib.Path(f"/run/unidiag/version/chassis_{_name}").read_bytes()
        except:
            return get_part_serial_number(type_code, use_cached=False)
    bus = BUS_FINDER[I2C_DEV["Chassis EEPROM x86"][4][0]](
        *I2C_DEV["Chassis EEPROM x86"][4][1:]
    )
    addr = I2C_DEV["Chassis EEPROM x86"][5]
    if not pathlib.Path(f"/sys/bus/i2c/devices/{bus}-{addr:04x}/eeprom").exists():
        print(
            f"Warning: No eeprom device initialised at i2c-{bus} {addr:#04x}. Please create it manually or use bootstrap.",
            file=sys.stderr,
        )
        return b"N/A"
    with open(f"/sys/bus/i2c/devices/{bus}-{addr:04x}/eeprom", "rb") as _f:
        _header = _f.read(4)
        if _header not in {b"\xfb\xfb\x05\xff", b"\xfb\xfb\x06\xff"}:
            print(
                f"Warning: File header {_header} not recognized! EEPROM at i2c-{bus} {addr:#04x}.",
                file=sys.stderr,
            )
            return b"N/A"
        try:
            while (_tc := _f.read(1)) is not None and _tc[0] != 250:
                _content = _f.read(_f.read(1)[0])
                if _tc[0] == type_code:
                    pathlib.Path(f"/run/unidiag/version/chassis_{_name}").write_bytes(
                        _content
                    )
                    return _content
            print(
                f"Warning: Failed to find type code {type_code} in Chassis EEPROM at i2c-{bus} {addr:#04x}!",
                file=sys.stderr,
            )
            return b"N/A"

        except:
            print(
                f"Warning: Error during looking for type code {type_code} in Chassis EEPROM at i2c-{bus} {addr:#04x}!",
                file=sys.stderr,
            )
            return b"N/A"


CPLD_SET = {
    "SCM CPLD",
    "SMB CPLD",
    "MCB CPLD MCB Control",
    "PIC_T CPLD",
    "PIC_B CPLD",
}


GPIO_IOB_NAME = GPIO_NAME_FBOSS
GPIO_IOB_LINE = enum.Enum(
    "GPIO_IOB_LINE",
    (
        ("IOB_SCM_CPLD_MUX_SEL", 1),
        ("IOB_I210_MUX_SEL", 2),
        ("MCB_CPLD_SPI_SEL", 3),
        ("R_MCB_JTAG_SEL", 4),
        ("SMB_CPLD_SPI_SEL", 7),
        ("ASIC_BOOT_QSPI_SEL3", 8),
        ("DOM_1_SPI_SEL", 9),
        ("DOM_BOT_SPI_SEL0", 9),  # controls buffer from DOM or PIC
        ("DOM_2_SPI_SEL", 10),
        ("DOM_TOP_SPI_SEL0", 10),
        ("IOB_SCM_9546_RST_L", 12),
        ("DOM_TOP_SPI_SEL1", 65),  # controls flash to DOM/PIC or IOB
        ("DOM_BOT_SPI_SEL1", 66),
    ),
)

# SPI device:
# 0. SPI controller number;
# 1. SPI controller chipselect (typically 0)
# 1. SPI flashchip size (int in Bytes)
# 2. SPI flashchip model(s) (list of str)
# 3. detection setup (list of commands)
# 4. detection teardown (list of commands)
SPI_DEV_IOB = {
    "IOB FPGA Config Flash": (
        0,
        0,
        16777216,
        ("W25Q128.V..M", "N25Q128..3E", "MT25QL128"),
        None,
        None,
    ),
    "DOM #1 FPGA Config Flash": (
        1,
        0,
        16777216,
        ("W25Q128.V..M",),
        (
            f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_BOT_SPI_SEL1.value}=1",
            f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_BOT_SPI_SEL0.value}=1",
        ),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_BOT_SPI_SEL1.value}=0",),
    ),
    "DOM #2 FPGA Config Flash": (
        2,
        0,
        16777216,
        ("W25Q128.V..M",),
        (
            f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_TOP_SPI_SEL1.value}=1",
            f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_TOP_SPI_SEL0.value}=1",
        ),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_TOP_SPI_SEL1.value}=0",),
    ),
    "MCB CPLD external Flash": (
        3,
        0,
        262144,
        ("W25X20",),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.MCB_CPLD_SPI_SEL.value}=1",),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.MCB_CPLD_SPI_SEL.value}=0",),
    ),
    "SMB CPLD external Flash": (
        4,
        0,
        262144,
        ("W25X20",),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.SMB_CPLD_SPI_SEL.value}=1",),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.SMB_CPLD_SPI_SEL.value}=0",),
    ),
    "ASIC FW SPI EEPROM": (
        5,
        0,
        262144,
        ("W25X20",),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.ASIC_BOOT_QSPI_SEL3.value}=1",),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.ASIC_BOOT_QSPI_SEL3.value}=0",),
    ),
    "SCM SPI Path": (
        6,
        0,
        262144,
        ("W25X20",),
        (
            # f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.IOB_I210_MUX_SEL.value}=0",
            f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.IOB_SCM_CPLD_MUX_SEL.value}=1",
        ),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.IOB_SCM_CPLD_MUX_SEL.value}=0"),
    ),
    "PIC-B CPLD external Flash": (
        1,
        0,
        262144,
        ("W25X20",),
        (
            f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_BOT_SPI_SEL1.value}=1",
            f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_BOT_SPI_SEL0.value}=0",
        ),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_BOT_SPI_SEL1.value}=0",),
    ),
    "PIC-T CPLD external Flash": (
        2,
        0,
        262144,
        ("W25X20",),
        (
            f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_TOP_SPI_SEL1.value}=1",
            f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_TOP_SPI_SEL0.value}=0",
        ),
        (f"gpioset {GPIO_IOB_NAME} {GPIO_IOB_LINE.DOM_TOP_SPI_SEL1.value}=0",),
    ),
}

# PCIe Devices
SW_ASIC_SPEED = 16
SSD_SPEED = 8
PCIE_DEV_LIST = {
    "I210 NIC": {
        "slot": (0, 0x01, 0, 0),
        "vendor": 0x8086,
        "device": 0x1537,
        "width": 1,
        "speed": 2.5,
    },
    "TH6 ASIC": {
        "slot": (0, 0x18, 0, 0),
        "vendor": 0x14E4,
        "device": 0xF900,
        "width": 4,
        "speed": SW_ASIC_SPEED,
    },
    "NVMe SSD": {
        "slot": (0, 0x16, 0, 0),
        "width": 4,
        "speed": SSD_SPEED,
    },
    "IOB FPGA": {
        "slot": (0, 0x17, 0, 0),
        "vendor": 0x1D9B,
        "device": 0x0011,
        "width": 2,
        "speed": 5,
    },
}
