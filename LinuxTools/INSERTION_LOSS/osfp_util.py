# (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
# Leveraged from https://www.internalfb.com/intern/anp/view/?id=4926095
# pylint:disable=bare-except, too-many-arguments, too-many-positional-arguments
"""OSFP PRBS Database"""

import subprocess as sp
import sys
import time

from osfp_cmis4 import memory_map_rev_4_0, CMIS_VER


def usage():
    """output help message"""
    print("Usage: cmis_util.py [-p <port>] [-h] [-i] -s <mode=parameter>")
    print("-h : show this message")
    print("-p:  specify a specific port or ports with port id range <1-64>")
    print("-i:  list OSFP module information")
    print("-s:  set operation mode")
    print("  PRBS=type,media,enable")
    print("     PRBS_type: 31, 31Q")
    print("     PRBS_media: host, media")
    print("     PRBS_enable: enable, disable, clear")
    print("  rx_disable=yes/no, page10h.byte138 RX output for the host lane.")
    print("  tx_disable=yes/no, page10h.byte130 TX output for the media lane")
    print("  lb=host_near/host_far/media_near/media_far/none")
    print("-q   query specific parameters:")
    print("     host_prbs_counters")
    print("     media_prbs_counters")
    print("At the BER output, the first array is BER for eight lanes of the port.")
    print("If the BER value is 99, it means the total bit count is 0, likely")
    print("PRBS checker hasn't been enabled. If BER value is -99, it means PRBS")
    print("is not locked. If it is 1e-15, it means 0 error was received.")
    print("The second array at BER output is the error count.")
    print("The third array at BER output is the total PRBS bit count.")


media_parameters = [
    ("eSNR Media", 8, "U16", 1 / 256),
    ("LTP Media", 8, "U16", 1 / 256),
    ("Pre-FEC BER Media Max", 8, "F16", 1),
    ("Pre-FEC BER Media Avg", 8, "F16", 1),
    ("FERC Media Max", 8, "F16", 1),
    ("FERC Media Avg", 8, "F16", 1),
    ("FEC tail Media Max", 8, "U16", 1),
    ("FEC tail Media Current", 8, "U16", 1),
]

host_parameters = [
    ("eSNR Host", 8, "U16", 1 / 256),
    ("LTP Host", 8, "U16", 1 / 256),
    ("Pre-FEC BER Host Max", 8, "F16", 1),
    ("Pre-FEC BER Host Avg", 8, "F16", 1),
    ("FERC Host Max", 8, "F16", 1),
    ("FERC Host Avg", 8, "F16", 1),
    ("FEC tail Host Max", 8, "U16", 1),
    ("FEC tail Host Current", 8, "U16", 1),
]

alarm_warning_parameters = [
    ("eSNR Media", 8),
    ("LTP Media", 8),
    ("Pre-FEC BER Media Max", 8),
    ("Pre-FEC BER Media Avg", 8),
    ("FERC Media Max", 8),
    ("FERC Media Avg", 8),
    ("FEC tail Media Max", 8),
    ("FEC tail Media Current", 8),
    ("eSNR Host", 8),
    ("LTP Host", 8),
    ("Pre-FEC BER Host Max", 8),
    ("Pre-FEC BER Host Avg", 8),
    ("FERC Host Max", 8),
    ("FERC Host Avg", 8),
    ("FEC tail Host Max", 8),
    ("FEC tail Host Current", 8),
]

threshold_parameters = [
    ("eSNR Media", 1, "U16", 1 / 256),
    ("LTP Media", 2, "U16", 1 / 256),
    ("Pre-FEC BER Media", 3, "F16", 1),
    ("FERC Media", 4, "F16", 1),
    ("FEC tail Media", 5, "U16", 1),
    ("eSNR Host", 17, "U16", 1 / 256),
    ("LTP Host", 18, "U16", 1 / 256),
    ("Pre-FEC BER Host", 19, "F16", 1),
    ("FERC Host", 20, "F16", 1),
    ("FEC tail Host", 21, "U16", 1),
    ("PAM Level StDev", 33, "F16", 1),
    ("Custom MPI metric", 34, "F16", 1),
    ("Optional MPI metric", 35, "F16", 1),
]


class InvalidLoopbackModeError(ValueError):
    """Custom exception for invalid loopback mode."""


class InvalidLoopbackTypeError(ValueError):
    """Custom exception for invalid loopback type."""


class InvalidPrbsModeError(ValueError):
    """Custom exception for invalid prbs mode."""


class InvalidPrbsTypeError(ValueError):
    """Custom exception for invalid prbs type."""


class UnrecongnizedTypeError(ValueError):
    """Custom exception for unrecongnized type."""


class InvalideRegNameError(ValueError):
    """Custom exception for invalid register name."""


class QsfpRegisterAccess:
    """Class for low-level register access."""

    def __init__(self, port, memory_map):
        self.port = port
        self._mmap = memory_map

    def cli_run(self, cmd):
        """function to run shell commands"""
        with sp.Popen(cmd, shell=True, stdout=sp.PIPE, stderr=sp.PIPE) as sout:
            return sout.stdout.read().decode("utf-8")

    def rreg(self, page, addr):
        """function to read register"""
        self.set_page(page)
        s = self.cli_run(f"i2cget -f -y {self.port} 0x50 {addr}")
        v = int(s, 16)
        return v

    def set_page(self, page):
        """function to set page"""
        if page == "lower":
            page = 0
        s = f"i2cset -f -y {self.port} 0x50 127 {page}"
        self.cli_run(s)

    def wreg(self, page, addr, data):
        """function to write register"""
        self.set_page(page)
        s = f"i2cset -f -y {self.port} 0x50 {addr} {data}"
        self.cli_run(s)

    def read_reg(self, page, addr, num_bytes):
        """function to read register"""
        val = []
        for i in range(0, num_bytes):
            tmp = self.rreg(page, addr + i)
            val.insert(len(val), tmp)
        return val

    def write_reg(self, page, addr, data):
        """function to write register"""
        try:
            iter(data)
        except TypeError:
            data = [data]
        for i, d in enumerate(data):
            self.wreg(page, addr + i, d)

    def read_modify_write(self, page, addr, bitmask, operator):
        """function to read modify write register"""
        s = self.read_reg(page=page, addr=addr, num_bytes=1)
        crnt_val = s[0]
        if operator == "and":
            new_val = crnt_val & bitmask
        elif operator == "or":
            new_val = crnt_val | bitmask
        else:
            new_val = crnt_val
            print(f"Invalid operator: {operator}")
            sys.exit(1)
        return self.write_reg(page=page, addr=addr, data=new_val)

    def get_reg_info(self, name):
        """function to get register info"""
        reg = [x for x in self._mmap if x["name"] == name]
        if len(reg) == 1:
            return reg[0]
        raise InvalideRegNameError(f'Reg "{name}" not found')

    def get_data(self, reg_info):
        """function to get data from register"""
        if isinstance(reg_info, str):
            reg = self.get_reg_info(reg_info)
        else:
            reg = reg_info
        raw_data = self.read_reg(
            page=reg["page"], addr=reg["byte"], num_bytes=reg["len"]
        )
        if reg["type"] == "ascii":
            ret_data = "".join([chr(x) for x in raw_data])
        elif reg["type"] == "uint8":
            ret_data = [int(x) for x in raw_data]
        elif reg["type"] == "uint16":
            ret_data = [
                int((raw_data[ii] << 8) + raw_data[ii + 1])
                for ii in range(0, len(raw_data), 2)
            ]
        elif reg["type"] == "uint32":
            ret_data = [
                int((raw_data[ii] << 8) + raw_data[ii + 1])
                for ii in range(0, len(raw_data), 2)
            ]
        elif reg["type"] == "uint16-LE":
            ret_data = [
                int((raw_data[ii]) + (raw_data[ii + 1] << 8))
                for ii in range(0, len(raw_data), 2)
            ]
        elif reg["type"] == "uint64-LE":
            ret_data = [
                int(
                    (raw_data[ii] << 0)
                    + (raw_data[ii + 1] << 8)
                    + (raw_data[ii + 2] << 16)
                    + (raw_data[ii + 3] << 24)
                    + (raw_data[ii + 4] << 32)
                    + (raw_data[ii + 5] << 40)
                    + (raw_data[ii + 6] << 48)
                    + (raw_data[ii + 7] << 56)
                )
                for ii in range(0, len(raw_data), 8)
            ]
        elif reg["type"] == "F16":
            ret_data = [self.get_f16(raw_data)]
        else:
            raise UnrecongnizedTypeError(f'Unrecongnized register type: {reg["type"]}')

        if reg["mult"] is not None:
            ret_data = [x * reg["mult"] for x in ret_data]
        return ret_data

    def get_f16(self, raw_data):
        """function to get F16 value from raw data"""
        exp = raw_data[0] >> 3
        mantissa = ((raw_data[0] & 7) << 8) + raw_data[1]
        return mantissa * 10 ** (exp - 24)


class QsfpStatus:
    """Class for status-related methods."""

    def __init__(self, register_access):
        self.reg_access = register_access

    def get_module_info(self):
        """function to get module info"""
        info = {}
        params = [
            "vendor_name",
            "vendor_oui",
            "part_number",
            "revision_number",
            "vendor_serial_number",
            "mfg_date",
            "FW_version",
            "DSP_FW_version",
        ]
        for p in params:
            info[p] = self.reg_access.get_data(p)
        info["FW_version"] = self.get_fw_ver()
        info["DSP_FW_version"] = self.get_dsp_fw_ver()
        info["mfg_date"] = self.get_mfg_date_code()
        return info

    def get_fw_ver(self):
        """function to get fw version"""
        fw_ver = self.reg_access.get_data("FW_version")
        fw_major = fw_ver[0] >> 8
        fw_minor = fw_ver[0] & 0xFF
        return f"{fw_major:X}.{fw_minor:X}"

    def get_dsp_fw_ver(self):
        """function to get dsp fw version"""
        fw_ver = self.reg_access.get_data("DSP_FW_version")
        fw_major = fw_ver[0] >> 8
        fw_minor = fw_ver[0] & 0xFF
        fw_rev = fw_ver[1] & 0xFFFF
        return f"{fw_major:X}.{fw_minor:X}.{fw_rev:X}"

    def get_mfg_date_code(self):
        """function to get manufacturing date code"""
        # The raw manufacturing date code in 8 bytes
        p = self.reg_access.get_data("mfg_date")
        year = f"20{chr(p[0])}{chr(p[1])}"
        month = f"{chr(p[2])}{chr(p[3])}"
        day = f"{chr(p[4])}{chr(p[5])}"
        return f"{year}-{month}-{day}"

    def get_tx_los(self):
        """function to get tx los info"""
        return self.reg_access.get_data("tx_los_flag")

    def get_rx_los(self):
        """function to get rx los info"""
        return self.reg_access.get_data("rx_los_flag")

    def get_tx_lol(self):
        """function to get tx lol info"""
        return self.reg_access.get_data("tx_lol_flag")

    def get_rx_lol(self):
        """function to get rx lol info"""
        return self.reg_access.get_data("rx_lol_flag")

    def get_los_lol(self):
        """function to get los/lol info"""
        info = {}
        params = ["tx_los_flag", "tx_lol_flag", "rx_los_flag", "rx_lol_flag"]
        for p in params:
            info[p] = self.reg_access.get_data(p)
        return info

    def get_module_state_raw(self):
        """function to get module state raw"""
        return self.reg_access.get_data("module_state")

    def get_module_state(self):
        """function to get module state"""
        module_state_raw = self.get_module_state_raw()[0] >> 1 & 0x7  # Get bits 3-1
        module_state_map = {
            1: "ModuleLowPwr",
            2: "ModulePwrUp",
            3: "ModuleReady",
            4: "ModulePwrDn",
            5: "ModuleFault",
        }
        for i in range(15):
            if i not in module_state_map:
                module_state_map[i] = "Reserved"
        return module_state_map[module_state_raw]

    def get_datapath_state(self):
        """function to get datapath state"""
        # list of datapath state.
        dp_state_raw = self.reg_access.get_data("data_path_state")
        dp_state_code = [((s >> (i * 4)) & 0xF) for s in dp_state_raw for i in range(2)]
        dp_state_map = {
            0: "Reserved",
            1: "DPDeactivated",
            2: "DPInit",
            3: "DPDeinit",
            4: "DPActivated",
            5: "DPTxTurnOn",
            6: "DPTxTurnOff",
            7: "DPInitialized",
        }
        for i in range(8, 16):
            dp_state_map[i] = "Reserved"
        dp_state = [dp_state_map[i] for i in dp_state_code]
        # return dp_state_code
        return dp_state

    def normal_state_check(self):
        """function to check normal state"""
        module_state = self.get_module_state()
        data_path_state = self.get_datapath_state()
        tx_los = self.get_tx_los()
        rx_los = self.get_rx_los()
        tx_lol = self.get_tx_lol()
        rx_lol = self.get_rx_lol()
        print(f"module state    : {module_state}")
        print(f"datapath state  : {data_path_state[0]}")
        print(f"tx_los          : {tx_los}")
        print(f"rx_los          : {rx_los}")
        print(f"tx_lol          : {tx_lol}")
        print(f"rx_lol          : {rx_lol}")


class Qsfp:
    """class qsfp methods"""

    def __init__(self, port):
        self.reg_access = QsfpRegisterAccess(port, memory_map_rev_4_0)
        self.status = QsfpStatus(self.reg_access)
        self._mmap = memory_map_rev_4_0
        self.port = port

    ### removed reg acceses methods

    def disable_rx_all(self):
        """function to disable rx channel"""
        reg = self.reg_access.get_reg_info("rx_disable")
        self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=0xFF)

    def enable_rx_all(self):
        """function to enable rx channel"""
        reg = self.reg_access.get_reg_info("rx_disable")
        self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=0x00)

    def disable_tx(self, chan_bitmask):
        """function to disable tx channel"""
        reg = self.reg_access.get_reg_info("tx_disable")
        self.reg_access.read_modify_write(
            page=reg["page"], addr=reg["byte"], bitmask=chan_bitmask, operator="or"
        )

    def enable_tx(self, chan_bitmask):
        """function to enable tx channel"""
        reg = self.reg_access.get_reg_info("tx_disable")
        self.reg_access.read_modify_write(
            page=reg["page"], addr=reg["byte"], bitmask=~chan_bitmask, operator="and"
        )

    def disable_tx_all(self):
        """function to disable tx channel"""
        self.disable_tx(chan_bitmask=0xFF)

    def enable_tx_all(self):
        """function to enable tx channel"""
        self.enable_tx(chan_bitmask=0xFF)

    def set_prbs_mode(self, prbs_type, mode, enable_type):
        """function to set PRBS mode"""
        prbs_clear = None
        enable = None
        if enable_type == "enable":
            enable = True
            prbs_clear = False
        elif enable_type == "disable":
            enable = False
            prbs_clear = False
        elif enable_type == "clear":
            enable = True
            prbs_clear = False
        if prbs_clear is False:
            self.set_prbs_gen(prbs_type, mode, "none", enable)
            self.set_prbs_check(prbs_type, mode, "none", False, enable)
        else:
            self.clear_prbs_err_counter()

    def set_prbs_check(
        self, prbs_type="15Q", mode="media", fec="none", gated=False, enable=True
    ):
        """function to set PRBS check"""
        # pass
        patterns = {"15Q": 0x44, "15": 0x55, "31Q": 0x00, "7Q": 0xAA, "31": 0x11}
        reg = self.reg_access.get_reg_info("ber_ctrl")
        if gated:
            ctrl_data = 0x12
        else:
            if CMIS_VER == 4.0:
                ctrl_data = 0x00
            else:
                ctrl_data = 0x00
        self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=ctrl_data)
        if mode == "media":
            fec_reg = self.reg_access.get_reg_info("media_checker_post_fec")
            pattern_regs = [
                self.reg_access.get_reg_info("media_checker_pattern_select_lane_2_1"),
                self.reg_access.get_reg_info("media_checker_pattern_select_lane_4_3"),
                self.reg_access.get_reg_info("media_checker_pattern_select_lane_6_5"),
                self.reg_access.get_reg_info("media_checker_pattern_select_lane_8_7"),
            ]
            enable_reg = self.reg_access.get_reg_info("media_checker_enable")
        elif mode == "host":
            fec_reg = self.reg_access.get_reg_info("host_checker_post_fec")
            pattern_regs = [
                self.reg_access.get_reg_info("host_checker_pattern_select_lane_2_1"),
                self.reg_access.get_reg_info("host_checker_pattern_select_lane_4_3"),
                self.reg_access.get_reg_info("host_checker_pattern_select_lane_6_5"),
                self.reg_access.get_reg_info("host_checker_pattern_select_lane_8_7"),
            ]
            enable_reg = self.reg_access.get_reg_info("host_checker_enable")
        else:
            raise InvalidPrbsModeError("Error - unidentified mode")
        if prbs_type not in patterns:
            raise InvalidPrbsTypeError("Error - not supported PRBS type")
        if fec == "none":
            fec_data = 0x00
        else:
            fec_data = 0xFF
        self.reg_access.write_reg(
            page=fec_reg["page"], addr=fec_reg["byte"], data=fec_data
        )
        for reg in pattern_regs:
            self.reg_access.write_reg(
                page=reg["page"], addr=reg["byte"], data=patterns[prbs_type]
            )
        reg = self.reg_access.get_reg_info("ref_clk_ctrl")
        if enable:
            self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=0x00)
            self.reg_access.write_reg(
                page=enable_reg["page"], addr=enable_reg["byte"], data=0xFF
            )
        else:
            self.reg_access.write_reg(
                page=enable_reg["page"], addr=enable_reg["byte"], data=0x00
            )

    def set_prbs_gen(self, prbs_type="15Q", mode="media", fec="none", enable=True):
        """function to set PRBS mode"""
        patterns = {"15Q": 0x44, "15": 0x55, "31Q": 0x00, "7Q": 0xAA, "31": 0x11}
        reg = self.reg_access.get_reg_info("ber_ctrl")
        ctrl_data = 0x00
        self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=ctrl_data)
        if mode == "media":
            fec_reg = self.reg_access.get_reg_info("media_gen_pre_fec")
            pattern_regs = [
                self.reg_access.get_reg_info("media_pattern_select_lane_2_1"),
                self.reg_access.get_reg_info("media_pattern_select_lane_4_3"),
                self.reg_access.get_reg_info("media_pattern_select_lane_6_5"),
                self.reg_access.get_reg_info("media_pattern_select_lane_8_7"),
            ]
            enable_reg = self.reg_access.get_reg_info("media_gen_enable")
        elif mode == "host":
            fec_reg = self.reg_access.get_reg_info("host_gen_pre_fec")
            pattern_regs = [
                self.reg_access.get_reg_info("host_pattern_select_lane_2_1"),
                self.reg_access.get_reg_info("host_pattern_select_lane_4_3"),
                self.reg_access.get_reg_info("host_pattern_select_lane_6_5"),
                self.reg_access.get_reg_info("host_pattern_select_lane_8_7"),
            ]
            enable_reg = self.reg_access.get_reg_info("host_gen_enable")
        else:
            raise InvalidPrbsModeError("Error - unidentified mode")
        if prbs_type not in patterns:
            raise InvalidPrbsTypeError("Error - not supported PRBS type")
        if fec == "none":
            fec_data = 0x00
        else:
            fec_data = 0xFF
        self.reg_access.write_reg(
            page=fec_reg["page"], addr=fec_reg["byte"], data=fec_data
        )
        for reg in pattern_regs:
            self.reg_access.write_reg(
                page=reg["page"], addr=reg["byte"], data=patterns[prbs_type]
            )
        if enable:
            self.reg_access.write_reg(
                page=enable_reg["page"], addr=enable_reg["byte"], data=0xFF
            )
        else:
            self.reg_access.write_reg(
                page=enable_reg["page"], addr=enable_reg["byte"], data=0x00
            )

    def clear_prbs_err_counter(self):
        """function to clear PRBS error counter"""
        reg = self.reg_access.get_reg_info("pattern_capability")
        ctrl_data = 0xB4
        self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=ctrl_data)
        reg = self.reg_access.get_reg_info("ber_ctrl")
        ctrl_data = 0x20
        self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=ctrl_data)
        ctrl_data = 0x00
        self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=ctrl_data)
        reg = self.reg_access.get_reg_info("pattern_capability")
        ctrl_data = 0xA4
        self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=ctrl_data)

    def check_snr(self, mode="media"):
        """function to get SNR"""
        reg = self.reg_access.get_reg_info("diag_SEL")
        self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=0x06)
        # after setting diag_SEL, needs delay
        # before we can get reliable SNR reading
        time.sleep(2)
        snr = []
        for ch in range(1, 9):
            if mode in {"media", "host"}:
                snr_lane = self.reg_access.get_data(f"{mode}_SNR_lane_{ch}")
                snr.append(round(snr_lane[0] / 256, 2))
            else:
                snr.append(-99)
        return snr

    def get_ber(self, mode="media"):
        """function to get BER"""
        reg = self.reg_access.get_reg_info("diag_SEL")
        bers = []
        if mode in {"media", "host"}:
            self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=0x1)
            time.sleep(3)
            for ch in range(1, 9):
                bers.append(self.reg_access.get_data(f"{mode}_BER_lane_{ch}"))
        return bers

    def check_ber(self, mode="media"):
        """function to check BER"""
        err_cnt = [0]
        total_cnt = [1]
        reg = self.reg_access.get_reg_info("diag_SEL")
        if mode == "host":
            diag_data = [0x02, 0x03]
            lol_reg = self.reg_access.get_data("host_lane_checker_lol")
        else:
            diag_data = [0x04, 0x05]
            lol_reg = self.reg_access.get_data("media_lane_checker_lol")
        err_cnts, total_cnts, bers = [], [], []
        for ber_lane_sel in diag_data:
            self.reg_access.write_reg(
                page=reg["page"], addr=reg["byte"], data=ber_lane_sel
            )
            # need delay to get reliable BER reading after writing diag_SEL
            time.sleep(3)
            for ch in range(1, 5):
                if ber_lane_sel % 2 == 0:
                    bit_shift = ch - 1
                else:
                    bit_shift = ch + 4 - 1
                if lol_reg[0] & (1 << bit_shift) == 0:
                    err_cnt = self.reg_access.get_data(f"err_cnt_lane_{ch}")
                    total_cnt = self.reg_access.get_data(f"bit_cnt_lane_{ch}")
                    err_cnts.append(err_cnt[0])
                    total_cnts.append(total_cnt[0])
                    if total_cnt[0] == 0:
                        bers.append(99)
                    else:
                        if err_cnt[0] == 0:
                            bers.append(1e-15)
                        else:
                            cur_ber = err_cnt[0] / total_cnt[0]
                            bers.append(cur_ber)
                else:
                    bers.append(-99)

        return [bers, err_cnts, total_cnts]

    def set_loopback(self, loop_type="near-end", mode="media", enable=True):
        """function to set loopback"""
        self.reg_access.get_data("loopback_capability")
        if loop_type == "near-end":
            if mode == "media":
                reg = self.reg_access.get_reg_info("media_near_LB_en")
            elif mode == "host":
                reg = self.reg_access.get_reg_info("host_near_LB_en")
            else:
                raise InvalidLoopbackModeError("invalid mode")
        elif loop_type == "far-end":
            if mode == "media":
                reg = self.reg_access.get_reg_info("media_far_LB_en")
            elif mode == "host":
                reg = self.reg_access.get_reg_info("host_far_LB_en")
            else:
                raise InvalidLoopbackModeError("invalid mode")
        else:
            raise InvalidLoopbackTypeError("invalid loopback type")
        if enable:
            self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=0x0F)
        else:
            self.reg_access.write_reg(page=reg["page"], addr=reg["byte"], data=0x00)

    def set_cmis_module_prbs_mode(self, params):
        """function to set port prbs mode"""
        parameter = params.split(",")
        prbs_type = parameter[0].upper()
        prbs_media = parameter[1].lower()
        prbs_enable = parameter[2].lower()
        self.set_prbs_mode(prbs_type, prbs_media, prbs_enable)

        rx_disable = parameter[3].lower()
        if rx_disable == "yes":
            self.disable_rx_all()
        else:
            self.enable_rx_all()

        tx_disable = parameter[4].lower()
        if tx_disable == "yes":
            self.disable_tx_all()
        else:
            self.enable_tx_all()

        lb_type = parameter[5].lower()
        lb_media = parameter[6].lower()
        lb_enable = parameter[7].lower()
        enable = bool(lb_enable == "enable")
        self.set_loopback(lb_type, lb_media, enable)
        print("\nPRBS Mode")
        print(f"    type      : {prbs_type}")
        print(f"    media     : {prbs_media}")
        print(f"    enable    : {prbs_enable}")
        print("\nLoopback Mode")
        print(f"    type      : {lb_type}")
        print(f"    media     : {lb_media}")
        print(f"    enable    : {lb_enable}")
        print("\nTx and Rx channels disabled")
        print(f"    tx_disable: {tx_disable}")
        print(f"    rx_disable: {rx_disable}")
        print("\n")


def get_single_port_prbs_info(port):
    """function to get port prbs info"""
    o = Qsfp(port)
    info = o.status.get_module_info()
    print("\n--- Basic Information ---\n")
    print(f"Vendor name     : {info['vendor_name']}")
    print(f"Part number     : {info['part_number']}")
    print(f"Serial number   : {info['vendor_serial_number']}")
    print(f"HW rev          : {info['revision_number']}")
    print(f"FW ver          : {o.status.get_fw_ver()}")
    print(f"DSP FW ver      : {o.status.get_dsp_fw_ver()}")
    print("\n--- Normal State Check ---\n")
    o.status.normal_state_check()
    print("\n--- SNR and BER Check ---\n")
    print(f'Media SNR       :\n {o.check_snr("media")}')
    print(f'Host SNR        :\n {o.check_snr("host")}')
    print(f'Media BER       :\n {o.get_ber("media")}')
    print(f'HOST BER        :\n {o.get_ber("host")}')
    print("\n--- PRBS Media and Host Counters Check ---\n")
    print("Media PRBS counters")
    bers_arr, err_cnts_arr, total_cnts_arr = o.check_ber("media")
    print("BER counters    :", bers_arr)
    print("Error counters  :", err_cnts_arr)
    print("Total counters  :", total_cnts_arr)
    print("\nHost PRBS counters")
    bers_arr, err_cnts_arr, total_cnts_arr = o.check_ber("host")
    print("BER counters    :", bers_arr)
    print("Error counters  :", err_cnts_arr)
    print("Total counters  :", total_cnts_arr)


def set_single_port_prbs_mode(port, parameter):
    """function to set port prbs mode"""
    print(f"Setting CMIS mode for port bus {port} ...")
    o = Qsfp(port)
    o.set_cmis_module_prbs_mode(params=parameter)
