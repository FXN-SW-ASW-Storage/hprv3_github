"""Resource collection and mapping for Meta FBOSS based platforms"""

import pathlib
import sys
from functools import partial


IOB_PCI_DRIVER = "fboss_iob_pci"


def _get_iobfpga_address(domain=0, bus=0x17, device=0, function=0):
    sysfs_path = (
        f"/sys/bus/pci/devices/{domain:04x}:{bus:02x}:{device:02x}.{function:x}"
    )
    addr = (
        (pathlib.Path(sysfs_path) / "resource")
        .read_text("utf-8")
        .splitlines()[0]
        .split()[0]
    )
    return int(addr, 0)


FPGA_BASE_ADDR = _get_iobfpga_address()
IOB_I2C_BASE_ADDR = 0x4000
DOM1_I2C_BASE_ADDR = 0x42000
DOM2_I2C_BASE_ADDR = 0x4A000


def _create_fpga_i2c_mapping(fpga: str, start_addr: int, reg_size=0x100) -> list:
    i2c_dict = {}
    for i2c_cont in pathlib.Path("/sys/bus/auxiliary/devices/").glob(
        f"{IOB_PCI_DRIVER}.{fpga}_i2c_master.*"
    ):
        i2c_dev = next(i2c_cont.glob("i2c-*"))
        i2c_name = (i2c_dev / "name").read_text("utf-8")
        i2c_channel = (int(i2c_name.split()[-1], 0) - start_addr) // reg_size
        i2c_dict[i2c_channel] = int(i2c_dev.name.removeprefix("i2c-"), 0)
    return list(dict(sorted(i2c_dict.items())).values())


IOB_I2C_MAPPING = _create_fpga_i2c_mapping("iob", FPGA_BASE_ADDR + IOB_I2C_BASE_ADDR)
DOM1_I2C_MAPPING = _create_fpga_i2c_mapping("dom1", FPGA_BASE_ADDR + DOM1_I2C_BASE_ADDR)
DOM2_I2C_MAPPING = _create_fpga_i2c_mapping("dom2", FPGA_BASE_ADDR + DOM2_I2C_BASE_ADDR)

IOB_FPGA_INFO_PATH = next(
    pathlib.Path("/sys/bus/auxiliary/devices/").glob(
        f"{IOB_PCI_DRIVER}.fpga_info_iob.*"
    )
)


def get_fpga_entry(fpga_info_path: pathlib.Path, entry: str, _type=None):
    """
    Get the certain entry from the FPGA sysfs
    and convert to specific type if needed
    Available entries:
        board_id:
            IOB: hard strapped 2-byte value for identifying platform
            DOM: hard strapped 2-byte value for identifying DOM1/DOM2
        board_rev: hard strapped 2-byte value for platform (MCB) revision
        device_id: 2-byte value for telling IOB/DOM
        fpga_sub_ver: firmware minor version
        fpga_ver: firmware major version
        fw_ver: firmware version in X.Y format
    """
    try:
        ret = (fpga_info_path / entry).read_text("utf-8").strip()
        if _type:
            return _type(ret)
        return ret
    except:  # pylint:disable=bare-except
        return "N/A"


IOB_BOARD_MAP = {
    0b0001: "Minipack 3",
    0b0100: "Minerva Janga",
    0b1000: "Icecube - TH6",
    0b1010: "Icecube - R4",
    0b1001: "Icetray - TH6",
    0b1011: "Icetray - J4",
    0b0111: "Santa Barbara",
    # 0b0111: "Santa Cruze",
}

DOM_NUM = {
    0b0001: 2,
    0b0100: 1,
    0b1000: 2,
    0b1010: 2,
    0b1001: 1,
    0b1011: 1,
    0b0111: 1,
    # 0b0111: 2,
}


def _get_dom_info_path(dom_id: int):
    for dom_info_path in pathlib.Path("/sys/bus/auxiliary/devices/").glob(
        f"{IOB_PCI_DRIVER}.fpga_info_dom.*"
    ):
        _board_id = int((dom_info_path / "board_id").read_text("utf-8"), 0)
        if _board_id == (dom_id - 1) * 0x8:
            return dom_info_path
    print(f"Warning: Cannot find info path for DOM{dom_id} FPGA!", file=sys.stderr)
    return None


DOM_FPGA_INFO_PATH = [
    _get_dom_info_path(i + 1)
    for i in range(
        DOM_NUM.get(
            get_fpga_entry(IOB_FPGA_INFO_PATH, "board_id", partial(int, base=0)), 2
        )
    )
]

DOM1_FPGA_INFO_PATH = DOM_FPGA_INFO_PATH[0]
if len(DOM_FPGA_INFO_PATH) > 1:
    DOM2_FPGA_INFO_PATH = DOM_FPGA_INFO_PATH[1]
else:
    DOM2_FPGA_INFO_PATH = None


def _create_xcvr_ctrl_mapping() -> dict[int, str]:
    xcvr_dict = {}
    for xcvr_ctrl in pathlib.Path("/sys/bus/auxiliary/devices/").glob(
        f"{IOB_PCI_DRIVER}.xcvr_ctrl.*"
    ):
        xcvr_dev = int(
            next(xcvr_ctrl.glob("xcvr_reset_*")).name.removeprefix("xcvr_reset_"), 0
        )
        xcvr_dict[xcvr_dev] = xcvr_ctrl.name.removeprefix(
            f"{IOB_PCI_DRIVER}.xcvr_ctrl."
        )
    return xcvr_dict


XCVR_CTRL_MAPPING = _create_xcvr_ctrl_mapping()


def _find_gpio_name() -> str:
    return next(
        pathlib.Path("/sys/bus/auxiliary/devices/").glob("fboss_iob_pci.gpiochip.*")
    ).name


GPIO_NAME_FBOSS = _find_gpio_name()
