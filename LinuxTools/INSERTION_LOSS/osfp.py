# /bin/env python3
"""Icecube OSFP test cases"""
# pylint:disable=import-error, line-too-long
import argparse
from typing import Literal, Callable, Optional, Sequence, Text, Tuple
import sys
import time
import pathlib
import smbus2
from resource_meta import (
    IOB_PCI_DRIVER,
    XCVR_CTRL_MAPPING,
    DOM2_FPGA_INFO_PATH,
)
from osfp_vdm import get_cmis_info
from osfp_util import (
    set_single_port_prbs_mode,
    get_single_port_prbs_info,
)
from shell_base import module_executor
from resource_icecube import I2C_DEV, BUS_FINDER
from i2c_base import _i2c_scan_come


# pylint: disable=unused-import
from osfp_base import (
    get_qsfp_vendor,
    get_osfp_vendor,
    get_osfp_pn,
    get_qsfp_pn,
    get_identifier,
    VALUE_IDENTIFIER_OSFP_8X,
    VALUE_IDENTIFIER_QSFP_28,
    FUNC_GET_VENDOR,
    FUNC_GET_PN,
    FUNC_GET_SN,
    LOOPBACK_INT_TRIGGER,
    LOOPBACK_POWER_16W,
    LOOPBACK_POWER_20W,
    LOOPBACK_POWER_22W,
    IDENTIFIER_NAME_MAP,
    FUNC_GET_VOLT,
    FUNC_GET_CURR,
    FUNC_GET_TEMP,
)

RESET_SYSFS_BASE = f"/sys/bus/auxiliary/devices/{IOB_PCI_DRIVER}.xcvr_ctrl.{{xcvr}}/xcvr_reset_{{port}}"
LPMODE_SYSFS_BASE = f"/sys/bus/auxiliary/devices/{IOB_PCI_DRIVER}.xcvr_ctrl.{{xcvr}}/xcvr_low_power_{{port}}"

smbcpld_dev = I2C_DEV["SMB CPLD"]
SMB_CPLD_BUS = BUS_FINDER[smbcpld_dev[4][0]](smbcpld_dev[4][1])
SMB_CPLD_ADDR = smbcpld_dev[5]

OSFP_PORT_REGS_INTERVAL = 0x10
PORT_INT_STAT = 0x31
OSFP_PORT_PRSN_STATUS_REGISTER_OFFSET = 0x34
OSFP_PORT_ADDR = 0x50

try:
    DOM2_FW_VER = int(
        (DOM2_FPGA_INFO_PATH / "fw_ver").read_text("utf-8").split(".")[-1]
    )
except ValueError:
    DOM2_FW_VER = 0
# On dom ver >= 42, qsfp port polarity consistent with osfp ports.
DOM2_FW_VER_QSFP_POLARITY_REVERSED = 42

# hard-coded for test only, update later
PORT_NUM = 64
# if BOARD_REV_IOB.startswith("EVT"):
#    PORT_NUM = 64
# else:
#    PORT_NUM = 65

# OM_TEMP_UPPER_THRESHOLD = 70
OM_TEMP_UPPER_THRESHOLD = 85


def _get_port_present(port_num: int) -> bool:
    _xcvr = XCVR_CTRL_MAPPING[port_num]
    try:
        return (
            int(
                pathlib.Path(
                    # pylint: disable=line-too-long
                    f"/sys/bus/auxiliary/devices/{IOB_PCI_DRIVER}.xcvr_ctrl.{_xcvr}/xcvr_present_{port_num}"
                ).read_text(encoding="utf-8"),
                0,
            )
            == 0
        )
    except FileNotFoundError:
        print(
            f"Cannot find present sysfs node for port {port_num}!",
            file=sys.stderr,
            flush=True,
        )
        return False
    except ValueError as e:
        print(f"Unexpected sysfs node value: {e!s}!", file=sys.stderr, flush=True)
        return False


def _get_port_present_smb_cpld(port_num: int) -> bool:
    """Get the port present status from SMB CPLD"""
    bank = (port_num - 1) // 8
    bit_pos = (port_num - 1) % 8
    with smbus2.SMBus(SMB_CPLD_BUS, force=True) as _fd:
        return (
            _fd.read_byte_data(
                SMB_CPLD_ADDR,
                bank * 0x10 + OSFP_PORT_PRSN_STATUS_REGISTER_OFFSET,
            )
            >> bit_pos
            & 1
            == 0
        )


def _get_port_bus(port_num: int) -> int:
    if port_num <= 32:
        return BUS_FINDER["DOM1"](port_num - 1)
    if port_num == 65:
        return BUS_FINDER["DOM2"](34)
    return BUS_FINDER["DOM2"](port_num - 1 - 32)


def detect_osfp_i2c_device() -> tuple[int, str]:
    """Scan OSFP/QSFP port"""
    missing_ports = []
    print(
        "----------------------------------------------------------------------------------------------\n"
        " PORT | PRSN | I2C | DETECT | TYPE |      VENDOR      |   PART NUMBER    |   SERIAL NUMBER    \n"
        "----------------------------------------------------------------------------------------------"
    )
    for port_num in range(1, PORT_NUM + 1):
        port = f"E{port_num}"
        print(f" {port:4s} ", end=" ")
        _bus = _get_port_bus(port_num)
        if _get_port_present(port_num):
            print(
                f' {"YES":<4s}   {_bus:>3d} ',
                end=" ",
            )
            if _i2c_scan_come(_bus, OSFP_PORT_ADDR):
                print("  PASS  ", end=" ")
                _id = get_identifier(_bus, OSFP_PORT_ADDR)
                if _name := IDENTIFIER_NAME_MAP.get(_id, ""):
                    print(f" {_name} ", end=" ")
                    try:
                        _vendor = FUNC_GET_VENDOR.get(_id)(_bus, OSFP_PORT_ADDR)
                    except OSError:
                        _vendor = "[I2C READ ERROR]"
                    try:
                        _partnum = FUNC_GET_PN.get(_id)(_bus, OSFP_PORT_ADDR)
                    except OSError:
                        _partnum = "[I2C READ ERROR]"
                    try:
                        _serialnum = FUNC_GET_SN.get(_id)(_bus, OSFP_PORT_ADDR)
                    except OSError:
                        _serialnum = "[I2C READ ERROR]"
                    print(f" {_vendor}   {_partnum}   {_serialnum}", flush=True)
                else:
                    print(f" Unsupported identifier: {_id:#04x}", flush=True)
            else:
                print("  FAIL  ", flush=True)
                missing_ports.append(port)
        else:
            print(f' {"NO":<4s}   {_bus:>3d}   SKIPPED')
            missing_ports.append(port)
    if missing_ports:
        return (
            -1,
            f"{len(missing_ports)} port(s) cannot be detected! Missing port(s):{missing_ports}."
            "\n OSFP/QSFP Scan failed!",
        )
    return 0, "OSFP/QSFP scan succeeded."


def enable_all_ports():
    """Release the reset signal of all ports"""
    for port in range(1, PORT_NUM + 1):
        xcvr = XCVR_CTRL_MAPPING[port]
        with open(
            RESET_SYSFS_BASE.format(xcvr=xcvr, port=port), "w", encoding="utf-8"
        ) as fd:
            if port == 65 and DOM2_FW_VER < DOM2_FW_VER_QSFP_POLARITY_REVERSED:
                print("1", file=fd, flush=True)
                continue
            print("0", file=fd, flush=True)
    return 0, "All ports' reset signals are released."


def disable_all_ports():
    """Hold the signal of all ports"""
    for port in range(1, PORT_NUM + 1):
        xcvr = XCVR_CTRL_MAPPING[port]
        with open(
            RESET_SYSFS_BASE.format(xcvr=xcvr, port=port), "w", encoding="utf-8"
        ) as fd:
            if port == 65 and DOM2_FW_VER < DOM2_FW_VER_QSFP_POLARITY_REVERSED:
                print("0", file=fd, flush=True)
                continue
            print("1", file=fd, flush=True)
    return 0, "All ports' reset signals are held."


def get_all_port_present_status() -> tuple[int, str]:
    """Get the present status of all ports from SMB CPLD"""
    absent_ports = []
    mismatch_ports = []
    ret = ""
    print(
        "----------------------------------------\n"
        " PORT | PRESENT (FPGA) | PRESENT (CPLD) \n"
        "----------------------------------------"
    )
    for port_num in range(1, PORT_NUM + 1):
        port = f"E{port_num}"
        prsn = _get_port_present(port_num)
        try:
            if port_num != 65:
                prsn_smb = _get_port_present_smb_cpld(port_num)
                prsn_smb_str = "YES" if prsn_smb else "NO"
                if prsn != prsn_smb:
                    mismatch_ports.append(port)
            else:
                prsn_smb_str = "N/A"
        except OSError:
            prsn_smb = False
            prsn_smb_str = "[I2C ERROR]"
        print(f' {port:4s}   {"YES" if prsn else "NO":^14s}   {prsn_smb_str:^14s}')
        if not prsn:
            absent_ports.append(port)
    if not absent_ports:
        ret += "All OSFP ports are present."
    else:
        ret += f" Following OSFP ports are missing! {absent_ports}."
    if mismatch_ports:
        ret += f" Following ports have different results on FPGA and CPLD! {mismatch_ports}."
    if bool(absent_ports) or bool(mismatch_ports):
        return -1, ret
    return 0, ret


def get_all_port_reset_status() -> tuple[int, str]:
    """Get the reset status of all ports from DOM FPGA"""
    print(
        "-------------------------\n"
        " PORT |  RESET  | VALUE \n"
        "-------------------------"
    )
    for port in range(1, PORT_NUM + 1):
        xcvr = XCVR_CTRL_MAPPING[port]
        with open(
            RESET_SYSFS_BASE.format(xcvr=xcvr, port=port), "r", encoding="utf-8"
        ) as fp:
            value = fp.read().strip()
        if port == 65 and DOM2_FW_VER < DOM2_FW_VER_QSFP_POLARITY_REVERSED:
            reset_val = 1
        else:
            reset_val = 0
        status = "Release" if int(value, 16) == reset_val else "Hold"
        print(f"  E{port:<2}   {status:^7s}   {value:^5s}")
    return 0, "All port reset status checked."


def get_all_port_lpmod_status() -> tuple[int, str]:
    """Get the lpmode status of all ports from DOM FPGA"""
    print(
        "-----------------------\n"
        " PORT | LPMODE | VALUE \n"
        "-----------------------"
    )
    for port in range(1, PORT_NUM + 1):
        xcvr = XCVR_CTRL_MAPPING[port]
        with open(
            LPMODE_SYSFS_BASE.format(xcvr=xcvr, port=port), "r", encoding="utf-8"
        ) as fp:
            value = fp.read().strip()
        status = "YES" if int(value, 16) == 1 else "NO"
        print(f"  E{port:<2}   {status:^6s}   {value:^5s}")
    return 0, "All port lpmode status checked."


def _check_port_int_status(group: int, bit_pos: int) -> Literal[0, 1]:
    with smbus2.SMBus(SMB_CPLD_BUS, force=True) as _fd:
        return (
            _fd.read_byte_data(SMB_CPLD_ADDR, group * 0x10 + PORT_INT_STAT) >> bit_pos
        ) & 1


def get_all_port_interrupt_status():
    """Get the INT status of all ports"""
    for port in range(1, PORT_NUM + 1):
        port_name = f"E{port}"
        if _check_port_int_status((port - 1) // 8, (port - 1) % 8):
            print(f" {port_name:<4s} {'Not Interrupted'}")
        else:
            print(f" {port_name:<4s} {'Interrupted'}")
    return 0, "All ports interrupt status checked."


def set_all_port_reset_status() -> tuple[int, str]:
    """Release the reset signal of all ports and check the I2C path"""
    missing_ports = []
    print(
        "----------------------------\n"
        " PORT | PRSN | I2C | RESULT \n"
        "----------------------------"
    )
    for port_num in range(1, PORT_NUM + 1):
        port = f"E{port_num}"
        print(f" {port:4s} ", end=" ")
        _bus = _get_port_bus(port_num)
        if _get_port_present(port_num):
            print(
                f' {"YES":<4s}   {_bus:>3d} ',
                end=" ",
            )
            xcvr = XCVR_CTRL_MAPPING[port_num]
            with open(
                RESET_SYSFS_BASE.format(xcvr=xcvr, port=port_num), "w", encoding="utf-8"
            ) as fd:
                if port_num == 65 and DOM2_FW_VER < DOM2_FW_VER_QSFP_POLARITY_REVERSED:
                    print("1", file=fd, flush=True, end="")
                else:
                    print("0", file=fd, flush=True, end="")
                time.sleep(0.1)
            if _i2c_scan_come(_bus, OSFP_PORT_ADDR):
                print("   PASS")
            else:
                print("   FAIL")
                missing_ports.append(port)
        else:
            print(f' {"NO":<4s}   {_bus:>3d}  SKIPPED')
            missing_ports.append(port)

    if missing_ports:
        return -1, f"Port reset release test failed! Failed ports: {missing_ports}"
    return 0, "Port reset release test passed."


def set_all_port_not_reset_status() -> tuple[int, str]:
    """Hold the reset signal of all ports and check the I2C path"""
    missing_ports = []
    print(
        "----------------------------\n"
        " PORT | PRSN | I2C | RESULT \n"
        "----------------------------"
    )
    for port_num in range(1, PORT_NUM + 1):
        port = f"E{port_num}"
        print(f" {port:4s} ", end=" ")
        _bus = _get_port_bus(port_num)
        if _get_port_present(port_num):
            print(
                f' {"YES":<4s}   {_bus:>3d} ',
                end=" ",
            )
            xcvr = XCVR_CTRL_MAPPING[port_num]
            with open(
                RESET_SYSFS_BASE.format(xcvr=xcvr, port=port_num), "w", encoding="utf-8"
            ) as fd:
                if port_num == 65 and DOM2_FW_VER < DOM2_FW_VER_QSFP_POLARITY_REVERSED:
                    print("0", file=fd, flush=True, end="")
                else:
                    print("1", file=fd, flush=True, end="")
                time.sleep(0.1)
            if not _i2c_scan_come(_bus, OSFP_PORT_ADDR):
                print("   PASS")
            else:
                print("   FAIL")
                missing_ports.append(port)
        else:
            print(f' {"NO":<4s}   {_bus:>3d}  SKIPPED')
            missing_ports.append(port)

    if missing_ports:
        return -1, f"Port reset hold test failed! Failed ports: {missing_ports}"
    return 0, "Port reset hold test passed."


def set_all_port_high_lpmode_status() -> tuple[int, str]:
    """De-assert lpmode signal for all ports"""
    for port in range(1, PORT_NUM + 1):
        xcvr = XCVR_CTRL_MAPPING[port]
        with open(
            LPMODE_SYSFS_BASE.format(xcvr=xcvr, port=port), "w", encoding="utf-8"
        ) as fd:
            fd.write("0")
            fd.flush()
    return 0, "All ports have cancelled LPmode."


def set_all_port_low_lpmode_status() -> tuple[int, str]:
    """Assert lpmode signal for all ports"""
    for port in range(1, PORT_NUM + 1):
        xcvr = XCVR_CTRL_MAPPING[port]
        with open(
            LPMODE_SYSFS_BASE.format(xcvr=xcvr, port=port), "w", encoding="utf-8"
        ) as fd:
            fd.write("1")
            fd.flush()
    return 0, "All ports have activated LPmode."


def set_high_power_elb_16w() -> tuple[int, str]:
    """Set all supported ELB to 16 watt"""
    print(
        "-----------------------------------------------------------\n"
        " PORT | PRSN |      VENDOR      |   PART NUMBER    | POWER \n"
        "-----------------------------------------------------------"
    )
    for port in range(1, PORT_NUM + 1):
        port_name = "E" + str(port)
        print(f" {port_name:<4s} ", end=" ")
        print(f" {'YES' if _get_port_present(port) else 'NO':<4s} ", end=" ")
        if _get_port_present(port):
            _bus = _get_port_bus(port)
            _id = get_identifier(_bus, OSFP_PORT_ADDR)
            try:
                _vendor = FUNC_GET_VENDOR[_id](_bus, OSFP_PORT_ADDR)
                _part_num = FUNC_GET_PN[_id](_bus, OSFP_PORT_ADDR)
                trigger_func = LOOPBACK_POWER_16W[_id].get((_vendor, _part_num), None)
            except KeyError:
                print(f"Unsupported Identifier {_id:#04x}.")
                continue
            except OSError:
                print("I2C Communication Failed.")
                continue
            print(f" {_vendor}   {_part_num} ", end=" ")
            if trigger_func is not None:
                _pwr = trigger_func[0](_bus, OSFP_PORT_ADDR)
                print(f" {_pwr:>3} Watt")
            else:
                print(" Not Supported")
        else:
            print(" Skipped")
    return 0, "Set all supported ELB to 16 Watt."


def set_high_power_elb_20w() -> tuple[int, str]:
    """Set all supported ELB to 20 watt"""
    print(
        "-----------------------------------------------------------\n"
        " PORT | PRSN |      VENDOR      |   PART NUMBER    | POWER \n"
        "-----------------------------------------------------------"
    )
    for port in range(1, PORT_NUM + 1):
        port_name = "E" + str(port)
        print(f" {port_name:<4s} ", end=" ")
        print(f" {'YES' if _get_port_present(port) else 'NO':<4s} ", end=" ")
        if _get_port_present(port):
            _bus = _get_port_bus(port)
            _id = get_identifier(_bus, OSFP_PORT_ADDR)
            try:
                _vendor = FUNC_GET_VENDOR[_id](_bus, OSFP_PORT_ADDR)
                _part_num = FUNC_GET_PN[_id](_bus, OSFP_PORT_ADDR)
                trigger_func = LOOPBACK_POWER_20W[_id].get((_vendor, _part_num), None)
            except KeyError:
                print(f"Unsupported Identifier {_id:#04x}.")
                continue
            except OSError:
                print("I2C Communication Failed.")
                continue
            print(f" {_vendor}   {_part_num} ", end=" ")
            if trigger_func is not None:
                _pwr = trigger_func[0](_bus, OSFP_PORT_ADDR)
                print(f" {_pwr:>3} Watt")
            else:
                print(" Not Supported")
        else:
            print(" Skipped")
    return 0, "Set all supported ELB to 20 Watt."


def set_high_power_elb_22w() -> tuple[int, str]:
    """Set all supported ELB to 22 watt"""
    print(
        "-----------------------------------------------------------\n"
        " PORT | PRSN |      VENDOR      |   PART NUMBER    | POWER \n"
        "-----------------------------------------------------------"
    )
    for port in range(1, PORT_NUM + 1):
        port_name = "E" + str(port)
        print(f" {port_name:<4s} ", end=" ")
        print(f" {'YES' if _get_port_present(port) else 'NO':<4s} ", end=" ")
        if _get_port_present(port):
            _bus = _get_port_bus(port)
            _id = get_identifier(_bus, OSFP_PORT_ADDR)
            try:
                _vendor = FUNC_GET_VENDOR[_id](_bus, OSFP_PORT_ADDR)
                _part_num = FUNC_GET_PN[_id](_bus, OSFP_PORT_ADDR)
                trigger_func = LOOPBACK_POWER_22W[_id].get((_vendor, _part_num), None)
            except KeyError:
                print(f"Unsupported Identifier {_id:#04x}.")
                continue
            except OSError:
                print("I2C Communication Failed.")
                continue
            print(f" {_vendor}   {_part_num} ", end=" ")
            if trigger_func is not None:
                _pwr = trigger_func[0](_bus, OSFP_PORT_ADDR)
                print(f" {_pwr:>3} Watt")
            else:
                print(" Not Supported")
        else:
            print(" Skipped")
    return 0, "Set all supported ELB to 22 Watt."


def set_high_power_elb_0w() -> tuple[int, str]:
    """Set all supported ELB to 0 watt"""
    print(
        "-----------------------------------------------------------\n"
        " PORT | PRSN |      VENDOR      |   PART NUMBER    | POWER \n"
        "-----------------------------------------------------------"
    )
    for port in range(1, PORT_NUM + 1):
        port_name = "E" + str(port)
        print(f" {port_name:<4s} ", end=" ")
        print(f" {'YES' if _get_port_present(port) else 'NO':<4s} ", end=" ")
        if _get_port_present(port):
            _bus = _get_port_bus(port)
            _id = get_identifier(_bus, OSFP_PORT_ADDR)
            try:
                _vendor = FUNC_GET_VENDOR[_id](_bus, OSFP_PORT_ADDR)
                _part_num = FUNC_GET_PN[_id](_bus, OSFP_PORT_ADDR)
                trigger_func = LOOPBACK_POWER_16W[_id].get((_vendor, _part_num), None)
            except KeyError:
                print(f"Unsupported Identifier {_id:#04x}.")
                continue
            except OSError:
                print("I2C Communication Failed.")
                continue
            print(f" {_vendor}   {_part_num} ", end=" ")
            if trigger_func is not None:
                _pwr = trigger_func[1](_bus, OSFP_PORT_ADDR)
                print(f" {_pwr:>3} Watt")
            else:
                print(" Not Supported")
        else:
            print(" Skipped")
    return 0, "Set all supported ELB to 0 Watt."


def test_elb_int_osfp() -> tuple[int, str]:
    """Test INT signal with supported ELBs"""
    failed_ports = []
    print(
        "--------------------------------------------------------------\n"
        " PORT | PRSN |      VENDOR      |   PART NUMBER    | INT Test \n"
        "--------------------------------------------------------------"
    )
    for port in range(1, PORT_NUM + 1):
        port_name = f"E{port!s}"
        print(f" {port_name:<4s} ", end=" ")
        print(f" {'YES' if _get_port_present(port) else 'NO':<4s} ", end=" ")
        if _get_port_present(port):
            _bus = _get_port_bus(port)
            _id = get_identifier(_bus, OSFP_PORT_ADDR)
            try:
                _vendor = FUNC_GET_VENDOR[_id](_bus, OSFP_PORT_ADDR)
                _part_num = FUNC_GET_PN[_id](_bus, OSFP_PORT_ADDR)
                trigger_func = LOOPBACK_INT_TRIGGER[_id].get((_vendor, _part_num), None)
            except KeyError:
                print(f"Unsupported Identifier {_id:#04x}.")
                continue
            except OSError:
                print("I2C Communication Failed.")
                continue
            print(f" {_vendor}   {_part_num} ", end=" ")
            if trigger_func is not None:
                trigger_func[0](_bus, OSFP_PORT_ADDR)
                time.sleep(0.1)
                for _ in range(3):
                    if 0 == _check_port_int_status((port - 1) // 8, (port - 1) % 8):
                        print(" PASS")
                        break
                    time.sleep(0.1)
                else:
                    failed_ports.append(port_name)
                    print(" FAIL")
                trigger_func[1](_bus, OSFP_PORT_ADDR)
            else:
                print(" Not Supported")
                failed_ports.append(port_name)
        else:
            print(" Skipped")
            failed_ports.append(port_name)
    if failed_ports:
        return -len(failed_ports), f"Test failed on the following ports: {failed_ports}"
    return 0, "All ports INT test passed."


def _get_port_lpmode_stat(port_id: int) -> bool:
    """Get the LPmode signal status. Return True if in LPmode, otherwise False"""
    try:
        xcvr = XCVR_CTRL_MAPPING[port_id]
        return bool(
            int(
                pathlib.Path(
                    LPMODE_SYSFS_BASE.format(xcvr=xcvr, port=port_id)
                ).read_text(encoding="utf-8"),
                0,
            )
        )
    except FileNotFoundError:
        print(
            f"LPmode sysfs node not found for port {port_id}!",
            file=sys.stderr,
            flush=True,
        )
        return False


def show_OSFP_QSFP_temperature():
    """Show OSFP/QSFP temperature"""
    unsupported_ports = []
    absent_ports = []
    overheated_ports = []
    print(
        f"Temperature Upper Threshold is {OM_TEMP_UPPER_THRESHOLD} 'C.\n"
        "---------------------------------------\n"
        " PORT | PRESENT | TEMPERATURE | LPmode \n"
        "---------------------------------------"
    )
    for port in range(1, PORT_NUM + 1):
        port_name = f"E{port!s}"
        print(f" {port_name:4s} ", end=" ")
        if _get_port_present(port):
            print("   YES   ", end=" ")
            _bus = _get_port_bus(port)
            try:
                _temp_str = FUNC_GET_TEMP[get_identifier(_bus, OSFP_PORT_ADDR)](
                    _bus, OSFP_PORT_ADDR, OM_TEMP_UPPER_THRESHOLD
                )
                if _temp_str.endswith("OVERHEAT"):
                    overheated_ports.append(port_name)
                print(
                    # pylint: disable=line-too-long
                    f"{_temp_str:^11s}   {'YES' if _get_port_lpmode_stat(port) else 'NO'}"
                )
            except KeyError:
                print(
                    f"Unsupported identifider {get_identifier(_bus, OSFP_PORT_ADDR):#04x}"
                )
                unsupported_ports.append(port_name)
            except OSError:
                print("I2C Communication Failed.")
                unsupported_ports.append(port_name)
                continue
        else:
            print("    NO   ", end=" ")
            print(" SKIPPED")
            absent_ports.append(port_name)
    ret_str = ""
    if unsupported_ports:
        ret_str += f" Unsupported Ports: {unsupported_ports}."
    if absent_ports:
        ret_str += f" Absent Ports: {absent_ports}."
    if overheated_ports:
        ret_str += f" Overheated Ports: {overheated_ports}."
    if ret_str:
        return -1, "Get all port temperature failed!" + ret_str
    return 0, "Get all port temperature succeeded."


def show_OSFP_QSFP_voltage():
    """show OSFP/QSFP port voltage"""
    unsupported_ports = []
    absent_ports = []
    print(
        "------------------------------\n"
        " PORT | PRESENT |   VOLTAGE   \n"
        "------------------------------"
    )
    for port in range(1, PORT_NUM + 1):
        port_name = f"E{port!s}"
        print(f" {port_name:4s} ", end=" ")
        if _get_port_present(port):
            print("   YES   ", end=" ")
            _bus = _get_port_bus(port)
            try:
                print(
                    # pylint: disable=line-too-long
                    f"{FUNC_GET_VOLT[get_identifier(_bus, OSFP_PORT_ADDR)](_bus, OSFP_PORT_ADDR):^11s}"
                )
            except KeyError:
                print(
                    f"Unsupported identifider {get_identifier(_bus, OSFP_PORT_ADDR):#04x}"
                )
                unsupported_ports.append(port_name)
            except OSError:
                print("I2C Communication Failed.")
                unsupported_ports.append(port_name)
        else:
            print("    NO   ", end=" ")
            print(" SKIPPED")
            absent_ports.append(port_name)
    ret_str = ""
    if unsupported_ports:
        ret_str += f"Unsupported Ports: {unsupported_ports}. "
    if absent_ports:
        ret_str += f"Absent Ports: {absent_ports}."
    if ret_str:
        return -1, "Get all port voltage failed!" + ret_str
    return 0, "Get all port voltage succeeded."


def show_OSFP_QSFP_current():
    """show OSFP/QSFP port current"""
    unsupported_ports = []
    absent_ports = []
    print(
        "------------------------------\n"
        " PORT | PRESENT |   CURRENT   \n"
        "------------------------------"
    )  #     ETH1/22/1
    for port in range(1, PORT_NUM + 1):
        port_name = f"E{port!s}"
        print(f" {port_name:4s} ", end=" ")
        if _get_port_present(port):
            print("   YES   ", end=" ")
            _bus = _get_port_bus(port)
            _id = get_identifier(_bus, OSFP_PORT_ADDR)
            try:
                _vendor = FUNC_GET_VENDOR[_id](_bus, OSFP_PORT_ADDR)
                _pn = FUNC_GET_PN[_id](_bus, OSFP_PORT_ADDR)
                _get_curr_func = FUNC_GET_CURR[_id].get((_vendor, _pn), None)
                if _get_curr_func is None:
                    _ret = "Unsupported Module"
                    unsupported_ports.append(port_name)
                else:
                    _ret = _get_curr_func(_bus, OSFP_PORT_ADDR)
                print(f" {_ret:11s}")
            except KeyError:
                print(f" Unsupported identifider {_id:#04x}")
                unsupported_ports.append(port_name)
            except OSError:
                print("I2C Communication Failed.")
                unsupported_ports.append(port_name)
        else:
            print("    NO   ", end=" ")
            print(" SKIPPED")
            absent_ports.append(port_name)
    ret_str = ""
    if unsupported_ports:
        ret_str += f"Unsupported Ports: {unsupported_ports}. "
    if absent_ports:
        ret_str += f"Absent Ports: {absent_ports}."
    if ret_str:
        return -1, "Get all port current failed!" + ret_str
    return 0, "Get all port current succeeded."


def _get_port_reset_status(port_num: int) -> bool:
    """Get the reset status of ports from DOM FPGA"""
    xcvr = XCVR_CTRL_MAPPING[port_num]
    with open(
        RESET_SYSFS_BASE.format(xcvr=xcvr, port=port_num), "r", encoding="utf-8"
    ) as fp:
        value = fp.read().strip()
    if port_num == 65 and DOM2_FW_VER < DOM2_FW_VER_QSFP_POLARITY_REVERSED:
        reset_val = 1
    else:
        reset_val = 0
    status = bool(int(value, 16) == reset_val)
    return status


def get_port_cmis_info(item: str, port_num: int):
    """Get the vdm status of port"""
    if _get_port_present(port_num) and _get_port_reset_status(port_num):
        get_cmis_info(item, _get_port_bus(port_num))
    else:
        print(
            f"\nUser port {port_num} has either no module presence or not been reset released\n"
        )


def set_port_prbs_mode(port_num, params):
    """Set the prbs mode of port"""
    if _get_port_present(port_num) and _get_port_reset_status(port_num):
        set_single_port_prbs_mode(_get_port_bus(port_num), params)
    else:
        print(
            f"\nUser port {port_num} has either no module presence or not been reset released\n"
        )


def get_port_prbs_info(port_num):
    """Get the prbs info of port"""
    if _get_port_present(port_num) and _get_port_reset_status(port_num):
        get_single_port_prbs_info(_get_port_bus(port_num))
    else:
        print(
            f"\nUser port {port_num} has either no module presence or not been reset released\n"
        )


GET_PORT_FUNC_DICT = {
    "voltage": show_OSFP_QSFP_voltage,
    "current": show_OSFP_QSFP_current,
    "temp": show_OSFP_QSFP_temperature,
}

CHK_PORT_FUNC_DICT = {
    "present": get_all_port_present_status,
    "reset": get_all_port_reset_status,
    "lpmode": get_all_port_lpmod_status,
}

SET_PORT_FUNC_DICT = {
    "enable": enable_all_ports,
    "disable": disable_all_ports,
    "hpmode": set_all_port_high_lpmode_status,
    "lpmode": set_all_port_low_lpmode_status,
}

TST_PORT_FUNC_DICT = {
    "scan": detect_osfp_i2c_device,
    "reset": set_all_port_reset_status,
    "unreset": set_all_port_not_reset_status,
    "int": test_elb_int_osfp,
}


func_dict = {
    "check": CHK_PORT_FUNC_DICT,
    "test": TST_PORT_FUNC_DICT,
    "get": GET_PORT_FUNC_DICT,
    "set": SET_PORT_FUNC_DICT,
}

USAGE = f"""Usage:
./{__file__.rsplit('/', maxsplit=1)[-1]} <command> <items> [port_num]
Notes:
 - get <voltage|current|temp>
 - set <enable|disable|hpmode|lpmode>
 - check <present|reset|lpmode>
 - test <scan|reset|unreset|int>
 - cmis <vdm|alarm|thres|power|flag|all> <port_num>
 - prbs get <port_num>
 - prbs <parmas> <port_num>
    - prbs_type: 31 | 31Q | 15 | 15Q | 7Q
    - prbs_media: host | media
    - prbs_enable: enable | disable | clear
    - rx_disable: yes | no
    - tx_disable: yes | no
    - lp_mode: far_end | near_end
    - lb_media: host | media
    - lp_enable: enable | disable
    - port_num: 1..65

    NOTE: for params it should be in order
        prbs_type, prbs_media, prbs_enable, rx_disable, tx_disable, lp_mode, lb_media, lp_enable

    e.g.: prbs 31,host,enable,no,no,near-end,host,disable 13
"""

module_parser = argparse.ArgumentParser(usage=USAGE)
subparsers = module_parser.add_subparsers(dest="function", help="subcommand help")

# test
osfp_test_parser = subparsers.add_parser("test", help="Test OSFP/QSFP port")
osfp_test_parser.add_argument("item", type=str)

# get
osfp_get_parser = subparsers.add_parser("get", help="Get OSFP/QSFP port status")
osfp_get_parser.add_argument("item", type=str)

# set
osfp_set_parser = subparsers.add_parser("set", help="Set OSFP/QSFP port status")
osfp_set_parser.add_argument("item", type=str)

# check
osfp_check_parser = subparsers.add_parser("check", help="Check OSFP/QSFP port status")
osfp_check_parser.add_argument("item", type=str)

# cmis
osfp_cmis_parser = subparsers.add_parser("cmis", help="Get OSFP/QSFP port cmis status")
osfp_cmis_parser.add_argument("item", type=str)
osfp_cmis_parser.add_argument("port_num", type=int)

# prbs
osfp_prbs_parser = subparsers.add_parser("prbs", help="Set OSFP/QSFP port prbs status")
osfp_prbs_parser.add_argument("params", type=str)
osfp_prbs_parser.add_argument("port_num", type=int)


def module_argparser(
    argv: Optional[Sequence[Text]] = None,
) -> Callable[[], Tuple[int, str]]:
    """Module argparser for CLi"""
    if argv is None:
        args = module_parser.parse_args()
    else:
        args = module_parser.parse_args(argv)
    if args.function is None:
        return 0, module_parser.parse_args(["--help"])

    if args.function in func_dict:
        if args.item in func_dict[args.function]:
            return lambda: (0, func_dict[args.function][args.item]())
    elif args.function == "cmis":
        return lambda: (0, get_port_cmis_info(args.item, args.port_num))
    elif args.function == "prbs":
        if args.params == "get":
            return lambda: (0, get_port_prbs_info(args.port_num))
        return lambda: (0, set_port_prbs_mode(args.port_num, args.params))
    return lambda: (-1, f"No function mapped to {args}.")


if __name__ == "__main__":
    module_executor(module_argparser, argv=None, shell=True)
