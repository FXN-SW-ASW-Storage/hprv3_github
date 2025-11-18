"""OSFP Database"""

# pylint:disable=import-error
import time
import struct
import smbus2

OFFSET_IDENTIFIER = 0
VALUE_IDENTIFIER_QSFP_28 = 0x11
VALUE_IDENTIFIER_OSFP_8X = 0x19

OFFSET_BANK_SEL = 126
OFFSET_PAGE_SEL = 127

OFFSET_CMIS_OSFP_VENDOR_NAME = 129
LENGTH_CMIS_OSFP_VENDOR_NAME = 16
OFFSET_CMIS_OSFP_VENDOR_PN = 148
LENGTH_CMIS_OSFP_VENDOR_PN = 16
OFFSET_CMIS_OSFP_VENDOR_SN = 166
LENGTH_CMIS_OSFP_VENDOR_SN = 16
OFFSET_CMIS_OSFP_TEMP_MON = 14
LENGTH_CMIS_OSFP_TEMP_MON = 2
OFFSET_CMIS_OSFP_VOLT_MON = 0x10
LENGTH_CMIS_OSFP_VOLT_MON = 2

OFFSET_CMIS_QSFP_VENDOR_NAME = 148
LENGTH_CMIS_QSFP_VENDOR_NAME = 16
OFFSET_CMIS_QSFP_VENDOR_PN = 168
LENGTH_CMIS_QSFP_VENDOR_PN = 16
OFFSET_CMIS_QSFP_VENDOR_SN = 196
LENGTH_CMIS_QSFP_VENDOR_SN = 16
OFFSET_CMIS_QSFP_TEMP_MON = 22
LENGTH_CMIS_QSFP_TEMP_MON = 2
OFFSET_CMIS_QSFP_VOLT_MON = 0x1A
LENGTH_CMIS_QSFP_VOLT_MON = 2

IDENTIFIER_NAME_MAP = {
    VALUE_IDENTIFIER_QSFP_28: "QSFP",
    VALUE_IDENTIFIER_OSFP_8X: "OSFP",
}

I2C_OP_DELAY = 0.01


def get_identifier(i2c_bus: int, i2c_addr: int) -> int:
    """Return the identifier value of the module"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        try:
            return i2c_fd.read_byte_data(i2c_addr, OFFSET_IDENTIFIER)
        except OSError:
            return -1


def get_osfp_vendor(i2c_bus: int, i2c_addr: int) -> str:
    """Getting OSFP Vendor Name based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        assert VALUE_IDENTIFIER_OSFP_8X == (
            _id := i2c_fd.read_byte_data(i2c_addr, OFFSET_IDENTIFIER)
        ), f"Unmatched Identifier Value ({_id:#04x})! Expecting {VALUE_IDENTIFIER_OSFP_8X:#04x}."
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        return bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_OSFP_VENDOR_NAME, LENGTH_CMIS_OSFP_VENDOR_NAME
            )
        ).decode(encoding="ascii", errors="backslashreplace")


def get_osfp_pn(i2c_bus: int, i2c_addr: int) -> str:
    """Getting OSFP Vendor PN based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        assert VALUE_IDENTIFIER_OSFP_8X == (
            _id := i2c_fd.read_byte_data(i2c_addr, OFFSET_IDENTIFIER)
        ), f"Unmatched Identifier Value ({_id:#04x})! Expecting {VALUE_IDENTIFIER_OSFP_8X:#04x}."
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        return bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_OSFP_VENDOR_PN, LENGTH_CMIS_OSFP_VENDOR_PN
            )
        ).decode(encoding="ascii", errors="backslashreplace")


def get_osfp_sn(i2c_bus: int, i2c_addr: int) -> str:
    """Getting OSFP Vendor PN based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        assert VALUE_IDENTIFIER_OSFP_8X == (
            _id := i2c_fd.read_byte_data(i2c_addr, OFFSET_IDENTIFIER)
        ), f"Unmatched Identifier Value ({_id:#04x})! Expecting {VALUE_IDENTIFIER_OSFP_8X:#04x}."
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        return bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_OSFP_VENDOR_SN, LENGTH_CMIS_OSFP_VENDOR_SN
            )
        ).decode(encoding="ascii", errors="backslashreplace")


def get_qsfp_vendor(i2c_bus: int, i2c_addr: int) -> str:
    """Getting QSFP Vendor Name based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        assert VALUE_IDENTIFIER_QSFP_28 == (
            _id := i2c_fd.read_byte_data(i2c_addr, OFFSET_IDENTIFIER)
        ), f"Unmatched Identifier Value ({_id:#04x})! Expecting {VALUE_IDENTIFIER_QSFP_28:#04x}."
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        return bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_QSFP_VENDOR_NAME, LENGTH_CMIS_QSFP_VENDOR_NAME
            )
        ).decode(encoding="ascii", errors="backslashreplace")


def get_qsfp_pn(i2c_bus: int, i2c_addr: int) -> str:
    """Getting QSFP Vendor PN based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        assert VALUE_IDENTIFIER_QSFP_28 == (
            _id := i2c_fd.read_byte_data(i2c_addr, OFFSET_IDENTIFIER)
        ), f"Unmatched Identifier Value ({_id:#04x})! Expecting {VALUE_IDENTIFIER_QSFP_28:#04x}."
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        return bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_QSFP_VENDOR_PN, LENGTH_CMIS_QSFP_VENDOR_PN
            )
        ).decode(encoding="ascii", errors="backslashreplace")


def get_qsfp_sn(i2c_bus: int, i2c_addr: int) -> str:
    """Getting QSFP Vendor SN based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        assert VALUE_IDENTIFIER_QSFP_28 == (
            _id := i2c_fd.read_byte_data(i2c_addr, OFFSET_IDENTIFIER)
        ), f"Unmatched Identifier Value ({_id:#04x})! Expecting {VALUE_IDENTIFIER_QSFP_28:#04x}."
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        return bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_QSFP_VENDOR_SN, LENGTH_CMIS_QSFP_VENDOR_SN
            )
        ).decode(encoding="ascii", errors="backslashreplace")


FUNC_GET_VENDOR = {
    VALUE_IDENTIFIER_QSFP_28: get_qsfp_vendor,
    VALUE_IDENTIFIER_OSFP_8X: get_osfp_vendor,
}

FUNC_GET_PN = {
    VALUE_IDENTIFIER_QSFP_28: get_qsfp_pn,
    VALUE_IDENTIFIER_OSFP_8X: get_osfp_pn,
}

FUNC_GET_SN = {
    VALUE_IDENTIFIER_QSFP_28: get_qsfp_sn,
    VALUE_IDENTIFIER_OSFP_8X: get_osfp_sn,
}


def get_osfp_temp(i2c_bus: int, i2c_addr: int, _temp_thres: float = None) -> str:
    """Getting Temperature of OSFP module based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        val = bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_OSFP_TEMP_MON, LENGTH_CMIS_OSFP_TEMP_MON
            )
        )
    temp = struct.unpack(">h", val)[0] / 256
    _overheat = ""
    if _temp_thres and temp > _temp_thres:
        _overheat = " OVERHEAT"
    return f"{temp:.2f} 'C" + _overheat


def get_qsfp_temp(i2c_bus: int, i2c_addr: int, _temp_thres: float = None) -> str:
    """Getting Temperature of QSFP module based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        val = bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_QSFP_TEMP_MON, LENGTH_CMIS_QSFP_TEMP_MON
            )
        )
    temp = struct.unpack(">h", val)[0] / 256
    _overheat = ""
    if _temp_thres and temp > _temp_thres:
        _overheat = " OVERHEAT"
    return f"{temp:.2f} 'C" + _overheat


FUNC_GET_TEMP = {
    VALUE_IDENTIFIER_OSFP_8X: get_osfp_temp,
    VALUE_IDENTIFIER_QSFP_28: get_qsfp_temp,
}


def get_osfp_volt(i2c_bus, i2c_addr) -> str:
    """Getting Voltage of OSFP module based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        val = bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_OSFP_VOLT_MON, LENGTH_CMIS_OSFP_VOLT_MON
            )
        )
    volt = struct.unpack(">H", val)[0]
    return f"{volt*100e-6:.2f} V"


def get_qsfp_volt(i2c_bus, i2c_addr) -> str:
    """Getting Voltage of QSFP module based on CMIS"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        val = bytes(
            i2c_fd.read_i2c_block_data(
                i2c_addr, OFFSET_CMIS_QSFP_VOLT_MON, LENGTH_CMIS_QSFP_VOLT_MON
            )
        )
    volt = struct.unpack(">H", val)[0]
    return f"{volt*100e-6:.2f} V"


FUNC_GET_VOLT = {
    VALUE_IDENTIFIER_OSFP_8X: get_osfp_volt,
    VALUE_IDENTIFIER_QSFP_28: get_qsfp_volt,
}


def get_LR3SQ102_SD_R_curr(i2c_bus: int, i2c_addr: int) -> str:
    """Getting the current of Luxshare LR3SQ102-SD-R Loopback"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        val = bytes(i2c_fd.read_i2c_block_data(i2c_addr, 18, 2))
    curr = struct.unpack(">H", val)[0]
    return f"{curr*1e-3:.2f} A"


FUNC_GET_CURR = {
    VALUE_IDENTIFIER_OSFP_8X: {
        ("LUXSHARE-TECH   ", "LR3SQ102-SD-R   "): get_LR3SQ102_SD_R_curr,
    },
    VALUE_IDENTIFIER_QSFP_28: {},
}


def osfp_int_trigger_multilane(i2c_bus: int, i2c_addr: int):
    """
    Page 03h, register 255, bit[1:0]\n
    Digital Control of INTL:\n
    00: Normal Operation\n
    10: Force the INTL to logic 0\n
    11: Force the INTL to logic 1
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0x03:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0x03)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 255, 0b11)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)


def osfp_int_untrigger_multilane(i2c_bus: int, i2c_addr: int):
    """Untrigger the Multilane ELB interrupt"""
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0x03:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0x03)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 255, 0)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)


OSFP_LOOPBACK_INT_TRIGGER = {
    ("MULTILANE       ", "ML4064-LB112-24W"): (
        osfp_int_trigger_multilane,
        osfp_int_untrigger_multilane,
    ),
}

QSFP_LOOPBACK_INT_TRIGGER = {}

LOOPBACK_INT_TRIGGER = {
    VALUE_IDENTIFIER_QSFP_28: QSFP_LOOPBACK_INT_TRIGGER,
    VALUE_IDENTIFIER_OSFP_8X: OSFP_LOOPBACK_INT_TRIGGER,
}


def osfp_elb_colorchip_t_100_o_elb_300_16w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "ColorChip       "
    Part Number: "T-100-O-ELB-300C"
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        for reg in range(213, 221):
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, reg, 0x20)
    return 16


def osfp_elb_colorchip_t_100_o_elb_300_0w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "ColorChip       "
    Part Number: "T-100-O-ELB-300C"
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        for reg in range(213, 221):
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, reg, 0)
    return 0


def osfp_elb_colorchip_t_100_o_elb_240m_16w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "ColorChip       "
    Part Number: "T-100-O-ELB-240M"
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        for reg in (213, 214, 216, 217):
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, reg, 0x30)
        for reg in (215, 218):
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, reg, 0x20)
    return 16


def osfp_elb_colorchip_t_100_o_elb_240m_0w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "ColorChip       "
    Part Number: "T-100-O-ELB-240M"
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        for reg in range(213, 219):
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, reg, 0)
    return 0


def osfp_elb_luxshare_LR3SQ102_SD_R_16w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "LUXSHARE-TECH   "
    Part Number: "LR3SQ102-SD-R   "
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 200, 0x20)
    return 16


def osfp_elb_luxshare_LR3SQ102_SD_R_0w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "LUXSHARE-TECH   "
    Part Number: "LR3SQ102-SD-R   "
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 200, 0)
    return 0


def osfp_elb_multilane_ml4064_lb112_24w_16w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "MULTILANE       "
    Part Number: "ML4064-LB112-24W"
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0x03:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0x03)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 250, 0b00011111)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 251, 0xFF)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 252, 0)
    return 15.95


def osfp_elb_multilane_ml4064_lb112_24w_0w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "MULTILANE       "
    Part Number: "ML4064-LB112-24W"
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0x03:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0x03)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 250, 0)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 251, 0)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 252, 0)
    return 0


def qsfp_elb_celestica_pzcom_f0004_01_3w5(i2c_bus: int, i2c_addr: int) -> float:
    """
    Vendor: "CELESTICA       "
    Part Number: "PZCOM-F0004-01  "
    Set to 3.5 watt
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        i2c_fd.write_byte_data(i2c_addr, 98, 0xFF)
    return 3.5


def qsfp_elb_celestica_pzcom_f0004_01_1w5(i2c_bus: int, i2c_addr: int) -> float:
    """
    Vendor: "CELESTICA       "
    Part Number: "PZCOM-F0004-01  "
    Set to 1.5 watt (default)
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        i2c_fd.write_byte_data(i2c_addr, 98, 0)
    return 1.5


OSFP_LOOPBACK_POWER_16W = {
    ("ColorChip       ", "T-100-O-ELB-300C"): (
        osfp_elb_colorchip_t_100_o_elb_300_16w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("ColorChip       ", "T-100-O-ELB-300 "): (
        osfp_elb_colorchip_t_100_o_elb_300_16w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("Wandtec         ", "T-100-O-ELB-300C"): (
        osfp_elb_colorchip_t_100_o_elb_300_16w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("Wandtec         ", "T-100-O-ELB-300 "): (
        osfp_elb_colorchip_t_100_o_elb_300_16w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("ColorChip       ", "T-100-O-ELB-240M"): (
        osfp_elb_colorchip_t_100_o_elb_240m_16w,
        osfp_elb_colorchip_t_100_o_elb_240m_0w,
    ),
    ("LUXSHARE-TECH   ", "LR3SQ102-SD-R   "): (
        osfp_elb_luxshare_LR3SQ102_SD_R_16w,
        osfp_elb_luxshare_LR3SQ102_SD_R_0w,
    ),
    ("MULTILANE       ", "ML4064-LB112-24W"): (
        osfp_elb_multilane_ml4064_lb112_24w_16w,
        osfp_elb_multilane_ml4064_lb112_24w_0w,
    ),
}

QSFP_LOOPBACK_POWER_16W = {
    ("CELESTICA       ", "PZCOM-F0004-01  "): (
        qsfp_elb_celestica_pzcom_f0004_01_3w5,
        qsfp_elb_celestica_pzcom_f0004_01_1w5,
    )
}

LOOPBACK_POWER_16W = {
    VALUE_IDENTIFIER_QSFP_28: QSFP_LOOPBACK_POWER_16W,
    VALUE_IDENTIFIER_OSFP_8X: OSFP_LOOPBACK_POWER_16W,
}


def osfp_elb_colorchip_t_100_o_elb_300_22w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "ColorChip       "
    Part Number: "T-100-O-ELB-300C"
    Set to 22 watt by (3*6+2*2)
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        for reg in (213, 214, 215, 217, 218, 219):
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, reg, 0x30)
        for reg in (216, 220):
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, reg, 0x20)
    return 22


def osfp_elb_luxshare_LR3SQ102_SD_R_22w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "LUXSHARE-TECH   "
    Part Number: "LR3SQ102-SD-R   "
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 200, 0x2C)
    return 22


def osfp_elb_multilane_ml4064_lb112_24w_22w(i2c_bus: int, i2c_addr: int) -> float:
    """
    Vendor: "MULTILANE       "
    Part Number: "ML4064-LB112-24W"
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0x03:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0x03)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 250, 0b01011111)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 251, 0xFF)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 252, 0xFF)
    return 21.95


OSFP_LOOPBACK_POWER_22W = {
    ("ColorChip       ", "T-100-O-ELB-300C"): (
        osfp_elb_colorchip_t_100_o_elb_300_22w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("ColorChip       ", "T-100-O-ELB-300 "): (
        osfp_elb_colorchip_t_100_o_elb_300_22w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("Wandtec         ", "T-100-O-ELB-300C"): (
        osfp_elb_colorchip_t_100_o_elb_300_22w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("Wandtec         ", "T-100-O-ELB-300 "): (
        osfp_elb_colorchip_t_100_o_elb_300_22w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("LUXSHARE-TECH   ", "LR3SQ102-SD-R   "): (
        osfp_elb_luxshare_LR3SQ102_SD_R_22w,
        osfp_elb_luxshare_LR3SQ102_SD_R_0w,
    ),
    ("MULTILANE       ", "ML4064-LB112-24W"): (
        osfp_elb_multilane_ml4064_lb112_24w_22w,
        osfp_elb_multilane_ml4064_lb112_24w_0w,
    ),
}

QSFP_LOOPBACK_POWER_22W = {
    ("CELESTICA       ", "PZCOM-F0004-01  "): (
        qsfp_elb_celestica_pzcom_f0004_01_3w5,
        qsfp_elb_celestica_pzcom_f0004_01_1w5,
    )
}

LOOPBACK_POWER_22W = {
    VALUE_IDENTIFIER_QSFP_28: QSFP_LOOPBACK_POWER_22W,
    VALUE_IDENTIFIER_OSFP_8X: OSFP_LOOPBACK_POWER_22W,
}


def osfp_elb_colorchip_t_100_o_elb_300_20w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "ColorChip       "
    Part Number: "T-100-O-ELB-300C"
    Set to 20 watt by (3*4+2*4)
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        for reg in (213, 214, 215, 216):
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, reg, 0x30)
        for reg in (217, 218, 219, 220):
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, reg, 0x20)
    return 3 + 3 + 3 + 3 + 2 + 2 + 2 + 2


def osfp_elb_luxshare_LR3SQ102_SD_R_20w(i2c_bus: int, i2c_addr: int) -> int:
    """
    Vendor: "LUXSHARE-TECH   "
    Part Number: "LR3SQ102-SD-R   "
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 200, 0x28)
    return 20


def osfp_elb_multilane_ml4064_lb112_24w_20w(i2c_bus: int, i2c_addr: int) -> float:
    """
    Vendor: "MULTILANE       "
    Part Number: "ML4064-LB112-24W"
    """
    with smbus2.SMBus(i2c_bus, force=True) as i2c_fd:
        time.sleep(I2C_OP_DELAY)
        if i2c_fd.read_byte_data(i2c_addr, OFFSET_PAGE_SEL) != 0x03:
            time.sleep(I2C_OP_DELAY)
            i2c_fd.write_byte_data(i2c_addr, OFFSET_PAGE_SEL, 0x03)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 250, 0b01111101)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 251, 0xD2)
        time.sleep(I2C_OP_DELAY)
        i2c_fd.write_byte_data(i2c_addr, 252, 0xFF)
    return 20


OSFP_LOOPBACK_POWER_20W = {
    ("ColorChip       ", "T-100-O-ELB-300C"): (
        osfp_elb_colorchip_t_100_o_elb_300_20w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("ColorChip       ", "T-100-O-ELB-300 "): (
        osfp_elb_colorchip_t_100_o_elb_300_20w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("Wandtec         ", "T-100-O-ELB-300C"): (
        osfp_elb_colorchip_t_100_o_elb_300_20w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("Wandtec         ", "T-100-O-ELB-300 "): (
        osfp_elb_colorchip_t_100_o_elb_300_20w,
        osfp_elb_colorchip_t_100_o_elb_300_0w,
    ),
    ("LUXSHARE-TECH   ", "LR3SQ102-SD-R   "): (
        osfp_elb_luxshare_LR3SQ102_SD_R_20w,
        osfp_elb_luxshare_LR3SQ102_SD_R_0w,
    ),
    ("MULTILANE       ", "ML4064-LB112-24W"): (
        osfp_elb_multilane_ml4064_lb112_24w_20w,
        osfp_elb_multilane_ml4064_lb112_24w_0w,
    ),
}

QSFP_LOOPBACK_POWER_20W = {
    ("CELESTICA       ", "PZCOM-F0004-01  "): (
        qsfp_elb_celestica_pzcom_f0004_01_3w5,
        qsfp_elb_celestica_pzcom_f0004_01_1w5,
    )
}

LOOPBACK_POWER_20W = {
    VALUE_IDENTIFIER_QSFP_28: QSFP_LOOPBACK_POWER_20W,
    VALUE_IDENTIFIER_OSFP_8X: OSFP_LOOPBACK_POWER_20W,
}
