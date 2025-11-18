"""This module provides functions for interacting with I2C devices"""

import pathlib
import sys
from typing import Literal, Callable
import smbus2  # pylint: disable=import-error
from unidiag.modules.runner.runner_meta import run_default, run_bmc

# pylint:disable=line-too-long, broad-exception-caught, consider-using-generator


def _i2c_scan_come_smbus2(
    bus: int, addr: int, force: bool = True, mode: Literal["q", "r", "a"] = "a"
) -> bool:
    """
    Scan for an I2C device using the smbus2 library.

    Args:
        bus (int): The I2C bus number.
        addr (int): The I2C device address.
        force (bool, optional): Force the device to opened even if already in use. Defaults to True.
        mode (Literal["q", "r", "a"], optional): The scan mode. "q" for quick write,
        "r" for read, "a" for auto-detect. Defaults to "a".

    Returns:
        bool: True if the device is found, False otherwise.
    """
    try:
        with smbus2.SMBus(bus, force=force) as scanned_dev:
            if mode == "a":
                if 0x30 <= addr <= 0x37 or 0x50 <= addr <= 0x5F:
                    mode = "r"
                else:
                    mode = "q"
            if mode == "q":
                # known to corrupt the Atmel AT24RF08 EEPROM
                scanned_dev.write_quick(addr)
            elif mode == "r":
                # Use with CAUTION: known to cause SMBus shutdown on write-only devices.
                try:
                    ret = scanned_dev.read_byte(addr)
                except TimeoutError:
                    ret = scanned_dev.read_byte_data(addr, 0)
                if ret < 0:
                    return False
            else:
                raise ValueError(f'Unrecognized mode "{mode}".')
    except OSError:
        return False
    return True


def _i2c_scan_come_i2ctools(
    bus: int, addr: int, force: bool = True, mode: Literal["q", "r", "a"] = "a"
) -> bool:
    """
    Scan for an I2C device using the i2ctools command line tool.

    Args:
        bus (int): The I2C bus number.
        addr (int): The I2C device address.
        force (bool, optional): Force the device to opened even if already in use. Defaults to True.
        mode (Literal["q", "r", "a"], optional): The scan mode. "q" for quick write,
        "r" for read, "a" for auto-detect. Defaults to "a".

    Returns:
        bool: True if the device is found, False otherwise.
    """
    if mode == "a":
        if 0x30 <= addr <= 0x37 or 0x50 <= addr <= 0x5F:
            mode = "r"
        else:
            mode = "q"
    if mode == "r":
        cmd = f'i2cget -y {"-f " if force else ""}-a {bus} {addr:#04x}'
    elif mode == "q":
        cmd = f'i2cset -y {"-f " if force else ""}-a {bus} {addr:#04x} 0 c'
    else:
        raise ValueError(f'Unrecognized mode "{mode}".')
    try:
        fp = run_default(cmd)
        if fp.returncode:
            return False
        return True
    except OSError as e:
        print(e)
        return False


_i2c_scan_come = _i2c_scan_come_smbus2


def _i2c_scan_bmc(
    bus: int, addr: int, force: bool = True, mode: Literal["q", "r", "a"] = "a"
) -> bool:
    """
    Scan for an I2C device using the i2ctools command line tool on a BMC.

    Args:
        bus (int): The I2C bus number.
        addr (int): The I2C device address.
        force (bool, optional): Force the device to opened even if already in use. Defaults to True.
        mode (Literal["q", "r", "a"], optional): The scan mode. "q" for quick write,
        "r" for read, "a" for auto-detect. Defaults to "a".

    Returns:
        bool: True if the device is found, False otherwise.
    """
    if mode == "a":
        if 0x30 <= addr <= 0x37 or 0x50 <= addr <= 0x5F:
            mode = "r"
        else:
            mode = "q"
    if mode == "r":
        cmd = f'i2cget -y {"-f " if force else ""}-a {bus} {addr:#04x} 0 '
    elif mode == "q":
        cmd = f'i2cset -y {"-f " if force else ""}-a {bus} {addr:#04x} 0 c'
    else:
        raise ValueError(f'Unrecognized mode "{mode}".')
    try:
        fp = run_bmc(cmd)
        if fp.returncode:
            return False
        return True
    except OSError:
        return False


def i2c_scan(
    bus: int,
    addr: int,
    force: bool = True,
    mode: Literal["q", "r", "a"] = "a",
    bmc=False,
) -> bool:
    """
    Scan for an I2C device on the specified bus and address.

    Args:
        bus (int): The I2C bus number.
        addr (int): The I2C device address.
        force (bool, optional): Force the device to opened even if already in use. Defaults to True.
        mode (Literal["q", "r", "a"], optional): The scan mode. "q" for quick write,
        "r" for read, "a" for auto-detect. Defaults to "a".
        bmc (bool, optional): Whether the scan is performed on a BMC. Defaults to False.

    Returns:
        bool: True if the device is found, False otherwise.
    """
    return (
        _i2c_scan_bmc(bus, addr, force=force, mode=mode)
        if bmc
        else _i2c_scan_come(bus, addr, force=force, mode=mode)
    )


def scan_i2c_devices_test(
    devs, get_bus_from_ctrl: Callable[[str, int], int]
) -> tuple[int, str]:
    """
    Scan the I2C devices and return the number of failed devices and a summary message.

    Args:
        devs (tuple[I2CDEVTUPLE, ...]): A tuple of I2C device, each containing the device name,
        controller, channel, and address.
        get_bus_from_ctrl (Callable[[str, int], int]): A function that returns the bus number
        given the controller and channel.

    Returns:
        tuple[int, str]: A tuple containing the number of failed devices and a summary message.
    """
    dev_name_len_max = max(max(len(dev[0]) for dev in devs), len("Device Name"))
    print(
        f"-{'-'*dev_name_len_max}-------------------------------------------\n"
        f" {'Device Name':^{dev_name_len_max}s} |   Controller   | Bus | Address | Status \n"
        f"-{'-'*dev_name_len_max}-------------------------------------------"
    )
    err_cnt: int = 0
    for dev_tuple in devs:
        dev_name, controller, channel, addr = dev_tuple
        if channel < 0:
            ctrl = controller
        else:
            ctrl = controller + " CH" + str(channel)
        bus = get_bus_from_ctrl(controller, channel)
        if addr < 0:
            status = "TBD"
        else:
            if i2c_scan(bus, addr, bmc=controller == "BMC"):
                status = "PASS"
            else:
                status = "FAIL"
                err_cnt += 1
        print(
            f" {dev_name:<{dev_name_len_max}s}   "
            f"{ctrl:>14s}   {bus:>3d}   "
            f'{f"{addr:#04x}":>7s}   {status:^6s} '
        )
    return err_cnt, f"Scanned {len(devs)} i2c devices, {err_cnt} failed."


# pylint:disable=too-many-arguments, too-many-positional-arguments
def i2cget(
    bus: int, addr: int, reg: int = 0, mode="b", length: int = -1, force: bool = True
) -> bytes:
    """
    Read data from the specified I2C device and register.
    Args:
        bus (int): The I2C bus number.
        addr (int): The I2C device address.
        reg (int, optional): The register address. Defaults to 0.
        mode (str, optional): The read mode. "b" for byte, "w" for word, "c" for command,
          "s" for sequential, "i" for block. Defaults to "b".
        length (int, optional): The length of data to read in block mode. Defaults to -1.

    Returns:
        bytes: The read data.
    """
    with smbus2.SMBus(bus, force=force) as i2c_cont:
        if mode == "b":
            return i2c_cont.read_byte_data(addr, reg).to_bytes(1, "big")
        if mode == "w":
            return i2c_cont.read_word_data(addr, reg).to_bytes(2, "big")
        if mode == "c":
            return i2c_cont.read_byte(addr).to_bytes(1, "big")
        if mode == "s":
            return bytes(i2c_cont.read_block_data(addr, reg))
        if mode == "i":
            return bytes(i2c_cont.read_i2c_block_data(addr, reg, length))
        raise ValueError(f'Unrecognized mode "{mode}"!')


def i2cset(
    bus: int,
    addr: int,
    reg: int = 0,
    value: int = None,
    mode="b",
    force: bool = True,
):
    """
    Set the value of a register on an I2C device.

    Args:
        bus (int): The I2C bus number.
        addr (int): The I2C device address.
        reg (int, optional): The register address. Defaults to 0.
        value (int, optional): The value to set. Defaults to None.
        mode (str, optional): The write mode. "b" for byte, "c" for command, "w" for word,
        "i" for block, "s" for sequential. Defaults to "b".
    """
    with smbus2.SMBus(bus, force=force) as i2c_cont:
        if mode == "b":
            return i2c_cont.write_byte_data(addr, reg, value)
        if mode == "c":
            return i2c_cont.write_byte(addr, value)
        if mode == "w":
            return i2c_cont.write_word_data(addr, reg, value)
        if mode == "i":
            return i2c_cont.write_i2c_block_data(addr, reg, value)
        if mode == "s":
            raise NotImplementedError
        raise ValueError(f'Cannot recognize mode "{mode}"!')


def i2cdump(bus: int, addr: int, reg: int = 0, length: int = 0xFF) -> bytes:
    """
    Read data from the specified I2C device and register.

    Args:
        bus (int): The I2C bus number.
        addr (int): The I2C device address.
        reg (int, optional): The register address. Defaults to 0.
        length (int, optional): The length of data to read. Defaults to 0xFF.

    Returns:
        bytes: The read data.
    """
    with smbus2.SMBus(bus, force=True) as i2c_cont:
        return bytes(
            (i2c_cont.read_byte_data(addr, reg + pos) for pos in range(length))
        )


def add_i2c_device(bus: int, addr: int, device: str):
    """
    Add an I2C device to the specified bus.

    Args:
        bus (int): The I2C bus number.
        addr (int): The I2C device address.
        device (str): The name of the device.
    """
    sysfs_path = f"/sys/bus/i2c/devices/i2c-{bus}/{bus}-{addr:04x}/"
    if pathlib.Path(sysfs_path).exists():
        with open(f"{sysfs_path}/name", "r", encoding="utf-8") as fd:
            dev_name = fd.read().strip()
        if dev_name == device:
            return
        raise OSError(f"I2C client busy with different device {dev_name}.")
    with open(
        f"/sys/bus/i2c/devices/i2c-{bus}/new_device", "w", encoding="utf-8"
    ) as fd:
        fd.write(f"{device} {addr:#x}")
        fd.flush()
    if pathlib.Path(sysfs_path).exists():
        return
    raise OSError(
        "I2C device (bus:{bus}, addr:{addr:#04x}, name:{device}) initialization failed!"
    )


def delete_i2c_device(bus: int, addr: int, device: str = None):
    """
    Remove an I2C device from the specified bus.

    Args:
        bus (int): The I2C bus number.
        addr (int): The I2C device address.
        device (str, optional): The name of the device. Defaults to None.
    """
    sysfs_path = f"/sys/bus/i2c/devices/i2c-{bus}/{bus}-{addr:04x}/"
    if not pathlib.Path(sysfs_path).exists():
        return
    if device:
        with open(f"{sysfs_path}/name", "r", encoding="utf-8") as fd:
            dev_name = fd.read()
        if dev_name != device:
            raise OSError(f"Attempting to remove an unexpected device: {dev_name}")
    with open(
        f"/sys/bus/i2c/devices/i2c-{bus}/delete_device", "w", encoding="utf-8"
    ) as fd:
        fd.write(hex(addr))
        fd.flush()
    return


def check_i2c_device_x86(bus: int, addr: int, device: str) -> bool:
    """
    Check whether an i2c device is equipped with correct device driver
    from x86 side.
    """
    sysfs_path = f"/sys/bus/i2c/devices/i2c-{bus}/{bus}-{addr:04x}/name"
    if not pathlib.Path(sysfs_path).exists():
        return False
    dev_name = pathlib.Path(sysfs_path).read_text(encoding="utf-8").strip()
    return dev_name == device


def check_i2c_device_bmc(bus: int, addr: int, device: str) -> bool:
    """
    Check whether an i2c device is equipped with correct device driver
    from BMC side.
    """
    sysfs_path = f"/sys/bus/i2c/devices/i2c-{bus}/{bus}-{addr:04x}/name"
    ret = run_bmc(f"cat {sysfs_path}")
    if ret.returncode:
        return False
    return ret.stdout.strip() == device


def check_i2c_device(bus: int, addr: int, device: str, bmc: bool = False) -> bool:
    """
    Check whether an i2c device is equipped with correct device driver.
    """
    if bmc:
        return check_i2c_device_bmc(bus, addr, device)
    return check_i2c_device_x86(bus, addr, device)


def i2cset_bit(bus: int, addr: int, reg: int, bit: int, value: int):
    """
    Set a bit in an i2c register.
    """
    if bit > 7:
        raise ValueError(f"Can only set bit 0-7, not {bit}.")
    if value not in (0, 1):
        raise ValueError(f"Can only set value 0 or 1, not {value}.")
    val = i2cget(bus, addr, reg)[0]
    if (val >> bit) & 1 == value:
        return
    if value:
        val |= 1 << bit
    else:
        val &= ~(1 << bit)
    i2cset(bus, addr, reg, val)


# New I2C dev manage framework
# pylint:disable=invalid-name


class I2C_DEVICES:
    """
    I2C devices operation document
    """

    # pylint:disable=too-few-public-methods
    class _DevInfo:
        """I2C device information"""

        # pylint:disable=too-many-instance-attributes
        def __init__(self, bmc, pcba, phase, subver, cont, addr, drv, test):
            self.bmc = bmc
            self.pcba = pcba
            self.phase = phase
            self.subver = subver
            self.cont = cont
            self.addr = addr
            self.drv = drv
            self.test = test

    def __init__(
        self, i2c_dev: dict, bus_finder: dict, pcba_phase: dict, pcba_source: dict
    ):
        self.i2c_dev = i2c_dev
        self.bus_finder = bus_finder
        self.pcba_phase = pcba_phase
        self.pcba_source = pcba_source

    def get_i2c_bus(self, device_name: str) -> int:
        """Get the system bus by the device name."""
        dev_info = self._DevInfo(*self.i2c_dev[device_name])
        return self.bus_finder[dev_info.cont[0]](*dev_info.cont[1:])

    def get_i2c_addr(self, device_name: str) -> int:
        """Get the addr by the device name."""
        return self._DevInfo(*self.i2c_dev[device_name]).addr

    def get_i2c_bus_addr(self, device_name: str) -> tuple[int, int]:
        """Get the system bus and addr by the device name."""
        dev_info = self._DevInfo(*self.i2c_dev[device_name])
        return self.bus_finder[dev_info.cont[0]](*dev_info.cont[1:]), dev_info.addr

    def add_i2c_driver(self, device_name: str, verbose=True):
        """register a driver for an i2c device"""
        dev_info = self._DevInfo(*self.i2c_dev[device_name])
        bus = self.get_i2c_bus(device_name)
        addr = dev_info.addr
        driver = dev_info.drv
        if driver is None:
            return
        sysfs_path = f"/sys/bus/i2c/devices/i2c-{bus}/{bus}-{addr:04x}/"
        sysfs_path_obj = pathlib.Path(sysfs_path)
        if sysfs_path_obj.exists():
            dev_name = (sysfs_path_obj / "name").read_text(encoding="utf-8").strip()
            assert (
                dev_name == driver
            ), f"I2C client busy with different device {dev_name}."
            if verbose:
                print(f"device {driver}@{addr:04x} on bus {bus} already initialised.")
            return
        pathlib.Path(f"/sys/bus/i2c/devices/i2c-{bus}/new_device").write_text(
            f"{driver} {addr:#x}", encoding="utf-8"
        )
        assert (
            sysfs_path_obj.exists()
        ), f"I2C device (bus:{bus}, addr:{addr:#04x}, name:{driver}) initialization failed!"
        if verbose:
            print(f"Initialising device {driver}@{addr:04x} on bus {bus}.")

    def remove_i2c_driver(self, device_name: str, verbose=True):
        """Remove the driver on an i2c device"""
        dev_info = self._DevInfo(*self.i2c_dev[device_name])
        bus = self.get_i2c_bus(device_name)
        addr = dev_info.addr
        sysfs_path = f"/sys/bus/i2c/devices/i2c-{bus}/{bus}-{addr:04x}/"
        sysfs_path_obj = pathlib.Path(sysfs_path)
        if sysfs_path_obj.exists():
            pathlib.Path(f"/sys/bus/i2c/devices/i2c-{bus}/delete_device").write_text(
                hex(addr), encoding="utf-8"
            )
            if verbose:
                print(f"Removing device driver at {addr:04x} on bus {bus}.")
        else:
            if verbose:
                print(f"device driver at {addr:04x} on bus {bus} not initialised.")

    def i2cset(self, device_name: str, reg: int, value: int = None, mode="b"):
        """unidiag implementation of i2cset function"""
        bus = self.get_i2c_bus(device_name)
        addr = self.get_i2c_addr(device_name)
        try:
            i2cset(bus, addr, reg, value, mode)
        except Exception as exc:
            print(
                f"[Warning] Caught exeception when trying to set {bus} {addr:#04x} {reg:#x} to {value:#x}: {exc!r}.",
                file=sys.stderr,
            )

    def i2cget(self, device_name: str, reg: int, mode="b", length: int = -1) -> bytes:
        """unidiag implementation of i2cget function"""
        bus = self.get_i2c_bus(device_name)
        addr = self.get_i2c_addr(device_name)
        try:
            return i2cget(bus, addr, reg, mode, length)
        except Exception as exc:
            print(
                f"[Warning] Caught exeception when trying to get {bus} {addr:#04x} {reg:#x} value: {exc!r}.",
                file=sys.stderr,
            )
            return (-1,)

    def i2cdump(self, device_name: str, reg: int = 0, length: int = 0xFF) -> bytes:
        """unidiag implementation of i2cdump function"""
        bus = self.get_i2c_bus(device_name)
        addr = self.get_i2c_addr(device_name)
        try:
            return i2cdump(bus, addr, reg, length)
        except Exception as exc:
            print(
                f"[Warning] Caught exeception when trying to get {bus} {addr:#04x} {reg:#x} value: {exc!r}.",
                file=sys.stderr,
            )
            return (-1,)

    def i2cset_bit(self, device_name: str, reg: int, bit: int, value: int):
        """setting a specific bit of a register"""
        bus = self.get_i2c_bus(device_name)
        addr = self.get_i2c_addr(device_name)
        i2cset_bit(bus, addr, reg, bit, value)

    # pylint:disable=too-many-branches, too-many-statements, too-many-locals
    def scan_i2c_devices_test(
        self, dev_dict, check_device: bool = True, check_func: bool = True
    ):
        """A wrapper of scan test based on the dictionary"""
        ret = 0
        dev_name_len_max = max([len(dev) for dev in dev_dict.keys()])
        dev_device_len_max = max(
            [
                (
                    len(self._DevInfo(*_info).drv)
                    if self._DevInfo(*_info).drv is not None
                    else 0
                )
                for _info in dev_dict.values()
            ]
        )
        header = f" {'Device Name':^{dev_name_len_max}s} |   Controller   | Bus | Addr | Access "
        if check_device:
            header += f"| {'Driver':^{dev_device_len_max}s} "
        if check_func:
            header += "| Func "
        banner = "-" * len(header)
        print(banner)
        print(header)
        print(banner)
        for dev, info in dev_dict.items():
            dev_info = self._DevInfo(*info)
            print(f" {dev:<{dev_name_len_max}s} ", end="", flush=True)
            is_bmc = dev_info.bmc
            chnl = dev_info.cont
            if len(chnl) == 1:
                chnl_name = chnl[0]
            else:
                chnl_name = f"{chnl[0]} CH{chnl[1]}"
            print(f"  {chnl_name:<14s} ", end="", flush=True)
            bus = self.get_i2c_bus(dev)
            print(f"  {bus:>3d} ", end="", flush=True)
            addr = dev_info.addr
            print(f"  {addr:#04x} ", end="", flush=True)

            if not i2c_scan(bus, addr, bmc=is_bmc):
                print("   FAIL  ", flush=True)
                ret += 1
                continue
            print("   PASS  ", end="", flush=True)
            if is_bmc:
                print(f"  {'N/A':<{dev_device_len_max}s}   N/A ", flush=True)
                continue
            dev_fail = False
            if check_device:
                if dev_info.drv is None:
                    print(f"  {'N/A':<{dev_device_len_max}s} ", end="", flush=True)
                else:
                    if check_i2c_device(bus, addr, dev_info.drv, is_bmc):
                        print(
                            f"  {dev_info.drv:<{dev_device_len_max}s} ",
                            end="",
                            flush=True,
                        )
                    else:
                        dev_fail = True
                        print(f"  {'FAIL':<{dev_device_len_max}s} ", end="", flush=True)
            if check_func:
                if dev_info.test is None:
                    print("  N/A ", end="", flush=True)
                else:
                    if dev_info.test(bus, addr):
                        print("  PASS ", end="", flush=True)
                    else:
                        dev_fail = True
                        print("  FAIL ", end="", flush=True)
            if dev_fail:
                ret += 1
            print()
        return ret, f"Scanned {len(dev_dict)} devices, {ret} failed."

    def get_i2c_dev_by_pcba(self, pcba, exclude_bmc: bool = True):
        """Generate a dict by pcba"""
        ret = {}
        phase = self.pcba_phase[pcba]
        source = self.pcba_source[pcba]
        for dev, info in self.i2c_dev.items():
            dev_info = self._DevInfo(*info)
            if exclude_bmc and dev_info.bmc:
                continue
            if dev_info.pcba != pcba:
                continue
            if phase not in dev_info.phase:
                continue
            if dev_info.subver and dev_info.subver != source:
                continue
            ret[dev] = info
        return ret

    def collect_all_iob_device(self) -> dict:
        """Collect all IOB devices"""
        ret = {}
        for dev, info in self.i2c_dev.items():
            dev_info = self._DevInfo(*info)
            if dev_info.bmc:
                continue
            pcba = dev_info.pcba
            phase = self.pcba_phase[pcba]
            source = self.pcba_source[pcba]
            if phase not in dev_info.phase:
                continue
            if dev_info.subver and dev_info.subver != source:
                continue
            ret[dev] = info
        return ret

    def get_i2c_dev_bmc_host(self) -> dict:
        """Collect all devices host by BMC"""
        ret = {}
        for dev, info in self.i2c_dev.items():
            dev_info = self._DevInfo(*info)
            if not dev_info.bmc:
                continue
            pcba = dev_info.pcba
            phase = self.pcba_phase[pcba]
            source = self.pcba_source[pcba]
            if phase not in dev_info.phase:
                continue
            if dev_info.subver and dev_info.subver != source:
                continue
            ret[dev] = info
        return ret

    def scan_i2c_devices_func(self, pcba):
        """PCBA Test case wrapper"""

        def _scan_i2c_devices_test_nested() -> tuple[int, str]:
            return self.scan_i2c_devices_test(self.get_i2c_dev_by_pcba(pcba))

        return _scan_i2c_devices_test_nested

    def scan_all_iob_devices_func(self):
        """IOB Test case wrapper"""

        def _scan_i2c_devices_test_nested() -> tuple[int, str]:
            return self.scan_i2c_devices_test(self.collect_all_iob_device())

        return _scan_i2c_devices_test_nested

    def scan_i2c_devices_bmc_func(self):
        """BMC Test case wrapper"""

        def _scan_i2c_devices_test_nested() -> tuple[int, str]:
            return self.scan_i2c_devices_test(self.get_i2c_dev_bmc_host())

        return _scan_i2c_devices_test_nested
