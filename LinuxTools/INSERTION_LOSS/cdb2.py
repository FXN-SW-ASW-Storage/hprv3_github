# (c) Meta Platforms, Inc. and affiliates. Confidential and proprietary.
# Leveraged from https://www.internalfb.com/intern/anp/view/?id=4926095
# pylint:disable=line-too-long, too-many-lines, too-many-function-args, bare-except
# /bin/env python3
"""OSFP CDB Database"""

import argparse
from typing import Literal, Callable, Optional, Sequence, Text, Tuple
import sys
import time
import pathlib
import subprocess as sp
import os

from shell_base import module_executor

# from unidiag.modules.osfp.osfp_util import QsfpRegisterAccess
from osfp_icecube import _get_port_present, _get_port_reset_status, _get_port_bus


fw_info_parameters = [
    # ("description", length, type, form)
    ("RPLength          ", 1, "U8", 10),
    ("RPLChkCode        ", 1, "U8", 10),
    ("FirmwareStatus    ", 1, "U8", 2),
    ("ImageInformation  ", 1, "U8", 2),
    ("ImageAMajor       ", 1, "U8", 16),
    ("ImageAMinor       ", 1, "U8", 16),
    ("ImageABuild       ", 2, "U8", 16),
    ("ImageAExtra       ", 32, "U8", 16),
    ("ImageBMajor       ", 1, "U8", 16),
    ("ImageBMinor       ", 1, "U8", 16),
    ("ImageBBuild       ", 2, "U8", 16),
    ("ImageBExtra       ", 32, "U8", 16),
    ("FactoryBootMajor  ", 1, "U8", 16),
    ("FactoryBootMinor  ", 1, "U8", 16),
    ("FactoryBootBuild  ", 2, "U8", 16),
    ("FactoryBootExtra  ", 32, "U8", 16),
]

fw_feature_paramters = [
    ("RPLength          ", 1, "U8", 10),  # 134
    ("RPLChkCode        ", 1, "U8", 10),  # 135
    ("resved            ", 1, "U8", 10),  # 136
    ("SupportedFeature  ", 1, "U8", 2),  # 137
    ("StartCmdPayloadSz ", 1, "U8", 10),  # 138
    ("EraseByte         ", 1, "U8", 10),  # 139
    ("ReadWriteLenExt   ", 1, "U8", 10),  # 140
    ("WriteMechanism    ", 1, "U8", 16),  # 141
    ("ReadMechanism     ", 1, "U8", 16),  # 142
    ("HitlessRestart    ", 1, "U8", 16),  # 143
    ("MaxDurationStart  ", 2, "U16", 10),  # 144~145
    ("MaxDurationAbort  ", 2, "U16", 10),  # 146~147
    ("MaxDurationWrite  ", 2, "U16", 10),  # 148~149
    ("MaxDurationCompl  ", 2, "U16", 10),  # 150~151
    ("MaxDurationCopy   ", 2, "U16", 10),  # 152~153
]

CDB_ERROR_CODE_DICT = {
    "0x81": "Busy proecessing command, CMD captured",
    "0x82": "Busy processing command, CMD checking",
    "0x83": "BUsy processing command, CMD execution",
    "0x40": "Failed, no specific failure",
    "0x42": "Parameter range error or not supported",
    "0x45": "CdbChkCode error",
    "0x01": "Success",
}


memory_map_fw_rev_4_0 = [
    # 9.7.1 CMD 0100h: Get Firmware Info
    {
        "name": "CDB_FW_STATUS",
        "page": 0x9F,
        "byte": 136,
        "len": 1,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_INFO",
        "page": 0x9F,
        "byte": 137,
        "len": 1,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_A_MAJOR",
        "page": 0x9F,
        "byte": 138,
        "len": 1,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_A_MINOR",
        "page": 0x9F,
        "byte": 139,
        "len": 1,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_A_BUILD",
        "page": 0x9F,
        "byte": 140,
        "len": 2,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_A_EXTRA",
        "page": 0x9F,
        "byte": 142,
        "len": 32,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_B_MAJOR",
        "page": 0x9F,
        "byte": 174,
        "len": 1,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_B_MINOR",
        "page": 0x9F,
        "byte": 175,
        "len": 1,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_B_BUILD",
        "page": 0x9F,
        "byte": 176,
        "len": 2,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_B_EXTRA",
        "page": 0x9F,
        "byte": 178,
        "len": 32,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_F_MAJOR",
        "page": 0x9F,
        "byte": 210,
        "len": 1,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_F_MINOR",
        "page": 0x9F,
        "byte": 211,
        "len": 1,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_F_BUILD",
        "page": 0x9F,
        "byte": 212,
        "len": 2,
        "type": "uint8",
        "mult": None,
    },
    {
        "name": "CDB_FW_IMAGE_F_EXTRA",
        "page": 0x9F,
        "byte": 214,
        "len": 32,
        "type": "uint8",
        "mult": None,
    },
    # 9.7.2 CMD 0101h: Start Firmware Download
    # 9.7.3 CMD 0102h: Abort
]

USAGE = "HELP"


def cli_run(cmd):
    """function to run shell commands"""
    with sp.Popen(cmd, shell=True, stdout=sp.PIPE, stderr=sp.PIPE) as sout:
        return sout.stdout.read().decode("utf-8")


def parse_fw_info_data(param, data: list):
    # print(data)
    ob_id = 0
    for observable in param:
        result_arr = []
        max_item_num = observable[1]
        for _ in range(max_item_num):
            if observable[3] == 16:
                raw_byte_vals = f"0x{data[ob_id]:02x}"
            elif observable[3] == 2:
                raw_byte_vals = f"0b{data[ob_id]:08b}"
            else:
                raw_byte_vals = data[ob_id]
            ob_id += 1
            result_arr.append(raw_byte_vals)
        """
        if observable[2] == "U16":
            val = result_arr[0] * 256 + result_arr[1]
            print(f"{observable[0]}: {val}")
        else:
            print(f"{observable[0]}:", " ".join(map(str, result_arr)))
        """
    return


def cmd_fw_info_data(module_bus):
    """function to get fw info"""
    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x9f;"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {module_bus} w7@0x50 130 0x00 0x00 0x00 0xfe 0x00 0x00;"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {module_bus} w3@0x50 128 0x01 0x00;"
    )
    print(cmd)
    cli_run(cmd)


def cmd_fw_feature_data(module_bus):
    """function to get fw management feature"""
    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x9f;"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {module_bus} w7@0x50 130 0x00 0x00 0x00 0xbe 0x00 0x00;"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {module_bus} w3@0x50 128 0x00 0x41;"
    )
    print(cmd)
    cli_run(cmd)


def cmd_fw_info_status(module_bus) -> bool:
    """function to get VDM values"""
    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x00;"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {module_bus} w1@0x50 37 r2;"
    )
    print(cmd)
    cmd_out = cli_run(cmd)
    status = [i for i in cmd_out.split()]
    # print(status)
    return status[0]


def get_fw_info_data(module_bus):
    """function to get osfp fw info"""
    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x9f;"
        f"i2ctransfer -y -f {module_bus} w1@0x50 134 r128;"
    )
    cmd_out = cli_run(cmd)
    data = [int(i, 16) for i in cmd_out.split()]
    return data


def get_file_size(path: str):
    path_lib = pathlib.Path(path)
    if path_lib.is_file():
        print(f"File size: {path_lib.stat().st_size}")
        return path_lib.stat().st_size


LPLLEN_PAYLOAD_POS = 4
EPLLEN_PAYLOAD_POS = 2
CHKCODE_PAYLOAD_POS = 5

FW_HEADER_SIZE = 64
FW_BLOCK_SIZE = 128
FW_DATA_SIZE = 16 * FW_BLOCK_SIZE

RESERVED_4_BTYES = ["0x00", "0x00", "0x00", "0x00"]

START_FW_DOWNLOAD_CMDID = [
    "0x01",
    "0x01",
    "0x00",
    "0x00",
    "0x00",
    "0x00",
    "0x00",
    "0x00",
]
ABORT_FW_DOWNLOAD_CMDID = [
    "0x01",
    "0x02",
    "0x00",
    "0x00",
    "0x00",
    "0xfc",
    "0x00",
    "0x00",
]
WRITE_FW_LPLBLOCK_CMDID = [
    "0x01",
    "0x03",
    "0x00",
    "0x00",
    "0x00",
    "0x00",
    "0x00",
    "0x00",
]
WRITE_FW_EPLBLOCK_CMDID = [
    "0x01",
    "0x04",
    "0x00",
    "0x00",
    "0x04",
    "0x00",
    "0x00",
    "0x00",
]
COMPL_FW_DOWNLOAD_CMDID = [
    "0x01",
    "0x07",
    "0x00",
    "0x00",
    "0x00",
    "0xf7",
    "0x00",
    "0x00",
]

RUN_RESET_INACTIVE_CMDID = [
    "0x01",
    "0x09",
    "0x00",
    "0x00",
    "0x04",
    "0xf2",
    "0x00",
    "0x00",
    "0x00",
    "0x00",
    "0x00",
    "0xff", # 255 ms
]

# should be variable and config by CMD 0041h
MAX_START_DURATION = 0.1  # unit in seconds, 100ms
MAX_ABORT_DURATION = 0.1
MAX_WRITE_DURATION = 3
MAX_COMPL_DURATION = 0.2


def gen_fw_upgrade_abort_cmd(port_bus):
    payload = []
    payload.extend(ABORT_FW_DOWNLOAD_CMDID)
    return payload


def gen_fw_upgrade_complete_cmd(port_bus):
    payload = []
    payload.extend(COMPL_FW_DOWNLOAD_CMDID)
    return payload


# gen sys command to write fw via EPL
def gen_fw_upgrad_payload_epl_cmd(data, file_size):
    payload_lpl = []
    payload_epl = []
    payload_epl_arr = []
    header = []

    header.extend(WRITE_FW_EPLBLOCK_CMDID)
    lpl_length = 4
    epl_length = len(data)  # FW_DATA_SIZE

    header[LPLLEN_PAYLOAD_POS] = f"0x{lpl_length:02x}"
    epl_length_hex = f"{epl_length:04x}"
    header[EPLLEN_PAYLOAD_POS] = f"0x{epl_length_hex[0:2]}"
    header[EPLLEN_PAYLOAD_POS + 1] = f"0x{epl_length_hex[2:4]}"
    payload_lpl.extend(header)

    if not 0 <= file_size <= 0xFFFFFFFF:
        raise ValueError("File size must be between 0 and 4294967295")
    hex_file_size = f"{file_size:08x}"
    hex_file_size_arr = [
        f"0x{hex_file_size[0:2]}",
        f"0x{hex_file_size[2:4]}",
        f"0x{hex_file_size[4:6]}",
        f"0x{hex_file_size[6:8]}",
    ]
    payload_lpl.extend(hex_file_size_arr)
    crc = gen_ones_complement(payload_lpl)
    payload_lpl[CHKCODE_PAYLOAD_POS] = f"0x{crc:02x}"

    #print(
    #    f"Writing size: {epl_length}, block size: {FW_BLOCK_SIZE}, addr dec: {file_size} Hex: {hex_file_size}"
    #)

    # prepare payload data to write page A0~AF
    arr_size = len(data) // FW_BLOCK_SIZE
    last_arr_size = len(data) % FW_BLOCK_SIZE
    #print(f"arr_size: {arr_size}, last_arr_size: {last_arr_size}")

    if last_arr_size == 0:
        for i in range(arr_size):
            payload_epl = []
            payload_epl.extend(data[i * FW_BLOCK_SIZE : ((i + 1) * FW_BLOCK_SIZE)])
            payload_epl_arr.append(payload_epl)
            # print(f"payload_epl: {len(payload_epl)}")
    else:
        for i in range(arr_size):
            payload_epl = []
            payload_epl.extend(data[i * FW_BLOCK_SIZE : ((i + 1) * FW_BLOCK_SIZE)])
            payload_epl_arr.append(payload_epl)
            # print(f"payload_epl: {len(payload_epl)}")
        payload_epl_arr.append(data[arr_size * FW_BLOCK_SIZE : len(data)])

    return payload_lpl, payload_epl_arr


# gen sys command to write fw via LPL
def gen_fw_upgrad_payload_cmd(data, file_size, is_header):
    payload = []
    header = []

    if is_header:
        # start fw download
        header.extend(START_FW_DOWNLOAD_CMDID)
        lpl_length = len(data) + 8
    else:
        header.extend(WRITE_FW_LPLBLOCK_CMDID)
        lpl_length = len(data) + 4

    # lpl_length = len(data) + 8
    header[LPLLEN_PAYLOAD_POS] = f"0x{lpl_length:02x}"

    payload.extend(header)

    if not 0 <= file_size <= 0xFFFFFFFF:
        raise ValueError("File size must be between 0 and 4294967295")
    hex_file_size = f"{file_size:08x}"
    hex_file_size_arr = [
        f"0x{hex_file_size[0:2]}",
        f"0x{hex_file_size[2:4]}",
        f"0x{hex_file_size[4:6]}",
        f"0x{hex_file_size[6:8]}",
    ]
    payload.extend(hex_file_size_arr)

    print(
        f"Writing size: {len(data)}, block size: {FW_BLOCK_SIZE}, addr dec: {file_size} Hex: {hex_file_size}"
    )
    if is_header:
        payload.extend(RESERVED_4_BTYES)

    payload.extend(data)
    # print(payload)
    crc = gen_ones_complement(payload)
    payload[CHKCODE_PAYLOAD_POS] = f"0x{crc:02x}"

    return payload


def GetFWImage(path):
    #filepath = os.path.dirname(os.path.abspath(__file__))  + fileName
    path_lib = pathlib.Path(path)
    if path_lib.is_file():
        with open(path, "rb") as file:
            file_size = path_lib.stat().st_size
            fw_image = file.read()
    return fw_image, file_size

    """
    byte_str = ''
    image_data = []
    for i, val in enumerate(fw_image):
        byte_str = byte_str + str(val)
        #image_data.append(ord(byte_str))
        image_data.append(byte_str)
        byte_str=''
    return image_data, total_bytes
    """


def upgrade_image(file: str, port_bus: int):
    """ upgrade image file data """
    image_data, total_bytes = GetFWImage(file)
    print(f"total_bytes: {total_bytes}")
    print(f"image_data: {image_data[:256]}")
    
    """ start command """
    chunk = image_data[0:FW_HEADER_SIZE]
    hex_chunk = [f"0x{byte:02x}" for byte in chunk]
    payload = gen_fw_upgrad_payload_cmd(hex_chunk, total_bytes, is_header = True)
    cmd_str = " ".join(payload[0:2])
    payload_str = " ".join(payload[2:])
    # only for start command
    cmd = (
        f"i2cset -y -f {port_bus} 0x50 0x7f 0x9f;"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {port_bus} w{len(payload)-1}@0x50 130 {payload_str};"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {port_bus} w3@0x50 128 {cmd_str};"
        f"sleep 1.5;"
        # f"sleep {MAX_WRITE_DURATION};"
    )
    # 0101h
    print("Start command: sending 64 bytes head...")
    print(cmd)
    cli_run(cmd)
    Check_CDBStatus(port_bus)
    get_port_fw_info(port_bus)
    
    
    """ normal epl data block command """
    return "0x01"


def read_file(path: str, port_bus: int, is_header: bool = True):
    """
    payload = gen_fw_upgrade_abort_cmd(port_bus)
    payload_str = " ".join(payload)
    cmd = (
        f"i2cset -y -f {port_bus} 0x50 0x7f 0x9f;"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {port_bus} w{len(payload)+1}@0x50 128 {payload_str};"
    )
    # print(cmd)
    cli_run(cmd)
    cmd_fw_info_status(port_bus)
    """
    is_header = True
    is_error = False
    path_lib = pathlib.Path(path)
    if path_lib.is_file():
        with open(path, "rb") as file:
            file_size = path_lib.stat().st_size
            block_address = 0
            while True:
                chunk = None
                if is_header:
                    chunk = file.read(FW_HEADER_SIZE)
                    if not chunk:
                        break
                    hex_chunk = [f"0x{byte:02x}" for byte in chunk]
                    payload = gen_fw_upgrad_payload_cmd(hex_chunk, file_size, is_header)
                    is_header = False
                    
                    cmd_str = " ".join(payload[0:2])
                    payload_str = " ".join(payload[2:])
                    # only for start command
                    cmd = (
                        f"i2cset -y -f {port_bus} 0x50 0x7f 0x9f;"
                        f"sleep 0.05;"
                        f"i2ctransfer -y -f {port_bus} w{len(payload)-1}@0x50 130 {payload_str};"
                        f"sleep 0.05;"
                        f"i2ctransfer -y -f {port_bus} w3@0x50 128 {cmd_str};"
                        f"sleep 1.5;"
                        # f"sleep {MAX_WRITE_DURATION};"
                    )
                    # 0101h
                    print("Start command: sending 64 bytes head...")
                    print(cmd)
                    cli_run(cmd)
                    status = cmd_fw_info_status(port_bus)
                    print(CDB_ERROR_CODE_DICT[status])
                    Check_CDBStatus(port_bus)

                else:
                    chunk = file.read(FW_DATA_SIZE)
                    if not chunk:
                        break
                    hex_chunk = [f"0x{byte:02x}" for byte in chunk]
                    
                    """ epl mode """
                    payload_lpl, payload_epl_arr = gen_fw_upgrad_payload_epl_cmd(
                        hex_chunk, block_address
                    )
                    block_address += len(chunk)

                    if len(chunk) % FW_BLOCK_SIZE == 0:
                        arr_size = len(hex_chunk) // FW_BLOCK_SIZE
                    else:
                        arr_size = len(hex_chunk) // FW_BLOCK_SIZE + 1
                    err_count = 0
                    count = 0
                    for i in range(arr_size):
                        payload_str = " ".join(payload_epl_arr[i])
                        epl_address = 160 + i
                        # print(f"epl_address: {epl_address}, length: {payload_epl_arr[i].__len__()}")
                        cmd = (
                            f"i2cset -y -f {port_bus} 0x50 0x7f {epl_address};"
                            f"sleep 0.05;"
                            f"i2ctransfer -y -f {port_bus} w{payload_epl_arr[i].__len__()+1}@0x50 128 {payload_str};"
                            f"sleep 0.05;"
                            # f"sleep {MAX_WRITE_DURATION};"
                        )
                        #print(f"\n\nsending block to EPL...Page: [{epl_address}]\n")
                        print(cmd)
                        cli_run(cmd)

                        payload_str = payload_str + "\n"
                        #print(f"sent payload [{FW_BLOCK_SIZE}]: \n{payload_str}")

                        #time.sleep(1)
                        #print("-")
                        payload_str_rb = cli_run(f"i2ctransfer -y -f {port_bus} w1@0x50 128 r{payload_epl_arr[i].__len__()}")
                        #print(f"readback payload [{FW_BLOCK_SIZE}]: \n{payload_str_rb}")
                        count += 1
                        if payload_str != payload_str_rb:
                            err_count += 1
                            #print("string compare result: False")
                        #else:
                            #print("string compare result: True")

                        
                    time.sleep(3)
                    
                    print(f"\rport: {port_bus}, error number {err_count}/{count}, percentage: {(err_count/count)*100:4.2f}%")
                    
                    # 0104h
                    cmd_str = " ".join(payload_lpl[0:2])
                    #print(cmd_str)
                    payload_str = " ".join(payload_lpl[2:])
                    #print(payload_str)
                    cmd = (
                        f"i2cset -y -f {port_bus} 0x50 0x7f 0x9f;"
                        f"sleep 0.05;"
                        f"i2ctransfer -y -f {port_bus} w11@0x50 130 {payload_str};"
                        f"sleep 0.05;"
                        f"i2ctransfer -y -f {port_bus} w3@0x50 128 {cmd_str};"
                        f"sleep {MAX_WRITE_DURATION};"
                    )
                    print("\n\nWrite command 0104: sending 13 bytes...")
                    print(cmd)
                    cli_run(cmd)
                    # <<< epl mode
                    
                    """ lpl mode """
                    """
                    payload = gen_fw_upgrad_payload_cmd(hex_chunk, block_address, is_header)
                    block_address += len(chunk)
                    
                    cmd_str = " ".join(payload[0:2])
                    payload_str = " ".join(payload[2:])
                    
                    cmd = (
                        f"i2cset -y -f {port_bus} 0x50 0x7f 0x9f;"
                        f"sleep 0.05;"
                        f"i2ctransfer -y -f {port_bus} w{len(payload)-1}@0x50 130 {payload_str};"
                        f"sleep 0.05;"
                        f"i2ctransfer -y -f {port_bus} w3@0x50 128 {cmd_str};"
                        f"sleep 3;"
                    )
                    
                    print(cmd)
                    cli_run(cmd)
                    # <<< lpl mode
                    """ 
                    # status = cmd_fw_info_status(port_bus)
                    # print(CDB_ERROR_CODE_DICT[status])
                    while True:
                        status = cmd_fw_info_status(port_bus)
                        print(
                            f"status: {status} - {CDB_ERROR_CODE_DICT[status]}, percentage: {(block_address/(file_size-FW_HEADER_SIZE))*100:4.2f}%"
                        )
                        #print(
                        #    f"err_count: {err_count}, status: {status} - {CDB_ERROR_CODE_DICT[status]}, percentage: {(block_address/(file_size-FW_HEADER_SIZE))*100:4.2f}%"
                        #)
                        if status in {"0x01"}:
                            is_error = False
                            break
                        if status in {"0x81", "0x82", "0x83"}:
                            time.sleep(1)
                            continue
                        if status in {"0x40", "0x42", "0x45"}:
                            is_error = True
                            break

                        # time.sleep(1)
                if not chunk:
                    break

                # hex_chunk = [f"0x{byte:02x}" for byte in chunk]
                # print(f"Read {len(payload)}\nbytes: {payload}")
                # print(cmd)

                # cli_run(cmd)

                # cmd_fw_info_status(port_bus)

                print("\n")
                get_port_fw_info(port_bus)
                if is_error:
                    raise Exception("CDB command failed...")
                else:
                    continue
                # yield chunk

            # abort fw download
        """
        if is_error:
            payload = gen_fw_upgrade_abort_cmd(port_bus)
            payload_str = " ".join(payload)

        else:
        """
        
        #time.sleep(3)
        # 0107h
        #DDwritepw(port_bus, "MSA")
        #payload = gen_fw_upgrade_complete_cmd(port_bus) # 0107h complete
        
        #cmd_str = " ".join(payload[0:2])
        #payload_str = " ".join(payload[2:])

        cmd = (
            f"i2cset -y -f {port_bus} 0x50 0x7f 0x9f;"
            f"sleep 0.05;"
            f"i2ctransfer -y -f {port_bus} w7@0x50 130 0x00 0x00 0x00 0xf7 0x00 0x00;"
            f"sleep 0.05;"
            f"i2ctransfer -y -f {port_bus} w3@0x50 128 0x01 0x07;"
            f"sleep {MAX_COMPL_DURATION};"
        )
        
        """
        #payload_str = " ".join(payload)

        cmd = (
            f"i2cset -y -f {port_bus} 0x50 0x7f 0x9f;"
            f"sleep 0.05;"
            f"i2ctransfer -y -f {port_bus} w9@0x50 128 0x01 0x07 0x00 0x00 0x00 0xf7 0x00 0x00;"
            f"sleep {MAX_COMPL_DURATION};"
        )
        """
        print(cmd)
        cli_run(cmd)
        status = cmd_fw_info_status(port_bus)
        print(CDB_ERROR_CODE_DICT[status])
    return status


def get_port_fw_feature(port_num: int):
    """Get the fw status of port"""
    if _get_port_present(port_num) and _get_port_reset_status(port_num):
        cmd_fw_feature_data(_get_port_bus(port_num))
    else:
        print(
            f"\nUser port {port_num} has either no module presence or not been reset released\n"
        )
    # i2cset and i2ctransfer
    if cmd_fw_info_status(_get_port_bus(port_num)):
        data = get_fw_info_data(_get_port_bus(port_num))
        parse_fw_info_data(fw_feature_paramters, data)
        # parse CMD 0100h response
    else:
        print("failed: cmd_fw_feature_data")
    return

def ReadCDBFWInfo(rtn):
        #DDwritepw(dut, 'MSA')
        #rtn = GenerateCDB_Command(dut, device_addr, 'FW_INFO')

        info = ""
        if (len(rtn) >= 1): #136
            if (rtn[0] == 0):
                info += "\nFactory Boot Image is running."
            else:
                if ((rtn[0] & 0x1) == 0x1): info += "\nImange A is running."
                if ((rtn[0] & 0x2) == 0x2): info += "\nImange A is committed, module boots from Image A."
                if ((rtn[0] & 0x4) == 0x4): 
                    info += "\nImage A is InValid."
                else:
                    info += "\nImage A is Valid."
                if ((rtn[0] & 0x10) == 0x10): info += "\nImange B is running."
                if ((rtn[0] & 0x20) == 0x20): info += "\nImange B is committed, module boots from Image B."
                if ((rtn[0] & 0x40) == 0x40): 
                    info += "\nImage B is InValid."
                else:
                    info += "\nImage B is Valid."
                
        if (len(rtn) >= 2): #137
            if ((rtn[1] & 0x1) == 0x1): info += "\nFimrware image A is present in the fields below."
            if ((rtn[1] & 0x2) == 0x2): info += "\nFimrware image B is present in the fields below."
            if ((rtn[1] & 0x4) == 0x4): info += "\nFactory or Boot image is present in the fields below."
        
        imAValid= ((rtn[0] & 0x4) != 0x4)
        imBValid= ((rtn[0] & 0x40) != 0x40)
        imAver = ""
        imBver = ""
        fctver = ""
        if (len(rtn) >= 6): #138-141
            imAver = str(int(rtn[2])) + "-" + str(int(rtn[3])) + "-" + str(int(rtn[4]) << 8 + int(rtn[5]))
            info += "\nImage A firmware version: " + imAver
        
        if (len(rtn) >= 42): #174-177
            imBver = str(int(rtn[38])) + "-" + str(int(rtn[39])) + "-" + str(int(rtn[40]) << 8 + int(rtn[41]))
            info += "\nImage B firmware version: " + imBver
        
        if (len(rtn) >= 78): #210 - 213
            fctver = str(int(rtn[74])) + "-" + str(int(rtn[75])) + "-" + str(int(rtn[76]) << 8 + int(rtn[77]))
            info += "\nFactory or Boot firmware version: " + fctver
        
        print(info)
        
        runA = ((rtn[0] & 0x1) == 0x1) #True if Image A running
        runB = ((rtn[0] & 0x10) == 0x10) #True if Image B running
        return runA, runB, imAver, imBver, imAValid, imBValid



def get_port_fw_info(port_bus):
    """Get the fw status of port"""
    cmd_fw_info_data(port_bus)
    if cmd_fw_info_status(port_bus):
        data = get_fw_info_data(port_bus)
        parse_fw_info_data(fw_info_parameters, data)
        # parse CMD 0100h response
        ReadCDBFWInfo(data[2:])
    else:
        print("failed: cmd_fw_info_data")
    return

def get_port_fw_info_by_port_num(port_num: int):
    """Get the fw status of port"""
    if _get_port_present(port_num) and _get_port_reset_status(port_num):
        cmd_fw_info_data(_get_port_bus(port_num))
    else:
        print(
            f"\nUser port {port_num} has either no module presence or not been reset released\n"
        )
    # i2cset and i2ctransfer
    if cmd_fw_info_status(_get_port_bus(port_num)):
        data = get_fw_info_data(_get_port_bus(port_num))
        parse_fw_info_data(fw_info_parameters, data)
        # parse CMD 0100h response
        ReadCDBFWInfo(data[2:])
    else:
        print("failed: cmd_fw_info_data")
    return


def gen_ones_complement(data: list):
    crc = 0x00
    for i in data:
        crc = (crc + int(i, 16)) & 0xFF
        # print(crc)
    return (~crc) & 0xFF


def Check_CDBStatus(port_bus: int, timeout_ms = 30000, time_count = 0, delay = 0):
    print("--- Check_CDBStatus ---")
    time.sleep(delay)
    STS_BUSY=1
    time_count=0
    status_reg=37
    print('timeout_ms : ', timeout_ms)
    
    while (str(STS_BUSY)=='1'):
        if time_count >= timeout_ms:
            print('Last CDB Command cannot excecute. CDB in busy status for %d milliseconds.' %(time_count))
            raise Exception('Last CDB Command cannot excecute. CDB in busy status for %d milliseconds.' %(time_count))
        try:    
            #status = Array.CreateInstance(int, 1)
            #status = dut.I2CRead(device_addr, status_reg, status, 1)
            cmd_str = f"i2ctransfer -y -f {port_bus} w1@0x50 {status_reg} r2;"
            cmd_out = cli_run(cmd_str)
            status = [int(i, 16) for i in cmd_out.split()]
            print(status)
            # print('***Byte 37, CDB status reg: ' + str(status[0]) + '***')
            regData=[]
            regData.append(status[0])
            STS_BUSY = ((128 & int(regData[0])) >> 7)
            STS_FAIL = ((64 & int(regData[0])) >> 6)
            Result = ((63 & int(regData[0])) >> 0)
            print('STS_BUSY : ' + str(STS_BUSY), 'STS_FAIL : ' + str(STS_FAIL), 'RESULT : ' + str(Result))
            info = ""
            if (str(STS_BUSY) == '1'):
                if (Result == 0x00): info += "No result."
                if (Result == 0x01): info += "Command is captured but not processed."
                if (Result == 0x02): info += "Command checking is in progress."
                if (Result == 0x03): info += "Command execution is in progress."

            elif (str(STS_BUSY) == '0' and str(STS_FAIL) == '0'):
                if (Result == 0x00): info += "No result."
                if (Result == 0x01): info += "Command completed successfully without specific message."
                if (Result == 0x03): info += "Previous CMD was ABORTED by CMD Abort."

            elif (str(STS_BUSY) == '0' and str(STS_FAIL) == '1'):
                if (Result == 0x00): info += "Failed, no specific failure code."
                if (Result == 0x01): info += "CMD Code unknown."
                if (Result == 0x02): info += "Parameter range error or not supported."
                if (Result == 0x05): info += "CdbChkCode Error."
                if (Result == 0x06): info += "Insufficient password privileges."
                print('Last CDB Command Failed. Command result: ' + info)
                raise Exception('Last CDB Command Failed. Command result: ' + info)
            time.sleep(0.005) #time sleep 5ms
            time_count += 5
        except Exception as e:
            print("Check CDB Status exception: ", e)
            time.sleep(0.005) #time sleep 5ms
            time_count += 5
    print('NACK detected CDB STS_BUSY for %d milliseconds.' %(time_count))

    return STS_BUSY, STS_FAIL, Result

def DDwritepw(port_bus, level = 'ENG'):
    try:
        data_pw = ["0x00", "0x00", "0x00", "0x00"]
        if level == 'ENG':
            print ('Setting engineering password...')
        elif level == 'MSA':
            print('Setting MSA password')
            data_pw[0]= "0x00"
            data_pw[1]= "0x00"
            data_pw[2]= "0x10"
            data_pw[3]= "0x11"
        else:
            print('setting BAD password')
            data_pw[0]= "0x11"
            data_pw[1]= "0x11"
            data_pw[2]= "0x01"
            data_pw[3]= "0x00"

        payload_str = " ".join(data_pw)
        cmd = (
            f"i2cset -y -f {port_bus} 0x50 0x7f 0x0;"
            f"sleep 0.05;"
            f"i2ctransfer -y -f {port_bus} w5@0x50 122 {payload_str};"
            f"sleep 0.05;"
        )
        print(cmd)
        cli_run(cmd)
        print ('password set...\n')
    except Exception as e:
        print(' Setting password got error.')
        raise Exception(' Setting password got error. ' + str(e))


def run_inactive_image(port_num: int):
    """ """
    payload = RUN_RESET_INACTIVE_CMDID
    cmd_str = " ".join(payload[0:2])
    payload_str = " ".join(payload[2:])
    
    cmd = (
        f"i2cset -y -f {port_num} 0x50 0x7f 0x9f;"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {port_num} w{len(payload)-1}@0x50 130 {payload_str};"
        f"sleep 0.05;"
        f"i2ctransfer -y -f {port_num} w3@0x50 128 {cmd_str};"
    )
    print(cmd)
    cli_run(cmd)
    status = cmd_fw_info_status(port_num)
    print(CDB_ERROR_CODE_DICT[status])
    return


def upgrade_port_fw(file: str, port_num: int):
    """Upgrade the fw of port"""
    """
    image_data,total_bytes=GetFWImage(file)
    print(f"{total_bytes} bytes, File Data: ")
    print(image_data[:256])
    """
    
    
    # get file info, FINISAR demo
    port_bus = _get_port_bus(port_num)
    CDBFirmwareUpgrade(port_bus, file)
    
    """ maye """
    """
    get_file_size(file)
    print(port_bus)
    # print(read_file(file))
    #DDwritepw(port_bus, "MSA")
    #str = os.popen(f"i2ctransfer -y -f {port_bus} w1@0x50 128 r8").read()
    #print(str)
    #return
    rt = read_file(file, port_bus)
    #rt = upgrade_image(file, port_bus)
    if rt == "0x01": # 0107h complete OK
        time.sleep(20)
        print("upgrade complete, get fw info...wait 20 sec...")
        get_port_fw_info(port_bus)
        #DDwritepw(port_bus, "ENG")
        time.sleep(20)
        print("run inactive image...wait 20 sec...")
        run_inactive_image(port_bus)
        time.sleep(20)
        get_port_fw_info(port_bus)
        print("ready to commit...")
    # start fw upgrade state machine
    """
    return


def complete_port_fw_download():
    # send 01 07 00 00 00 f7
    # read from 00h:37 of status
    return



"""
"""""""""""""""""""""""""""""""
"""

def GenerateCDB_Command(port_bus ,device_addr = 0xA0, CDB_command = '', payload = '',  customcommand = 0, timeout_ms = 30000, delay = 0, badChkCode=False, badPassword=False,badLpl=False, lpl=0, exceptOnChkCode = True):
       
        print('Command %s will be generated.' %CDB_command)

        """
        if isinstance (payload, Array[int]):         
            payload_len = len(payload)
        else:
            payload_len = 0
        """
        payload_len = len(payload)
        print(payload_len)
        print(payload)
        #payload = [0]*payload_len
        

        # if payload_len > 120:
        #     print("MSA CDB LPL length is larger than 120 bytes.")
        #     print('Size of LPL is %s bytes.' %str(payload_len))
        #     raise Exception("MSA CDB LPL length is larger than 120 bytes.")
            
        # data = Array.CreateInstance(int, 8)
        # Page 9Fh Bytes 128-129 (cmd codes), 130 - 135 (cmd fields)
        cdb_cmd_code = [0]*2 #Array.CreateInstance(int, 2)
        cdb_cmd_fields = [0]*6 #Array.CreateInstance(int, 6)

        if CDB_command == 'FW_INFO':
            cmd = 0x0100
        elif CDB_command == 'START_FW_DOWNLOAD':
            cmd = 0x0101
        elif CDB_command == 'ABORT_FW_DOWNLOAD':
            cmd = 0x0102
        elif CDB_command == 'WRITE_FW_DOWNLOAD_LPL':
            cmd = 0x0103
        elif CDB_command == 'WRITE_FW_DOWNLOAD_EPL':
            cmd = 0x0104
        elif CDB_command == 'READ_FW_DOWNLOAD_LPL':
            cmd = 0x0105
        elif CDB_command == 'READ_FW_DOWNLOAD_EPL':
            cmd = 0x0106
        elif CDB_command == 'COMPLETE_FW_DOWNLOAD':
            cmd = 0x0107
        elif CDB_command == 'COPY_FW_IMAGE':
            cmd = 0x0108
        elif CDB_command == 'RUN_FW_IMAGE':
            cmd = 0x0109
        elif CDB_command == 'COMMIT_FW_IMAGE':
            cmd = 0x010A
        elif CDB_command == 'DSP_READ':
            cmd= 0x8000
        elif CDB_command == 'DSP_WRITE':
            cmd= 0x8001
        elif CDB_command == 'CDB_FEATURE':
            cmd=0x0041
        elif CDB_command == 'CUSTOM':
            cmd = customcommand
        else:
            print("CDB Command not Valid.")
            raise Exception("CDB Command not Valid.")

        # data[0] = (cmd & 0xFF00) >> 8
        # data[1] = cmd & 0xFF

        cdb_cmd_code[0] = (cmd & 0xFF00) >> 8
        cdb_cmd_code[1] = cmd & 0xFF

        checksum = 0

        for i in range(payload_len):
            checksum += payload[i]
            checksum &= 0xFF

        checksum += ((cmd & 0xFF00) >> 8)
        checksum &= 0xFF
        checksum += (cmd & 0xFF)
        checksum &= 0xFF
        checksum += (payload_len)
        checksum &= 0xFF

        correctChkCode=(~checksum & 0xFF) # not needed
        if not badChkCode:
            checksum = (~checksum & 0xFF)

        print(checksum)
        # if badLpl:
        #     data[4] = lpl
        # else:
        #     data[4] = payload_len
        # data[5] = checksum


        # data_len = len(data)
        # print('Size of payload to be written is %s bytes.' %str(data_len))
        table = [0]*1 #Array.CreateInstance(int, 1)
        table[0] =  0x9F #change page address
        
        cmd = (f"i2cset -y -f {port_bus} 0x50 0x7f 0x9f;"
            f"sleep 0.05;"
        )
        print(cmd)
        os.system(cmd)
        #dut.I2CWrite(device_addr, 127, table, 1) #Page 9Fh
        #if badPassword:
        #    DDwritepw(dut,'BAD')
        
        # address = Array.CreateInstance(int, 6)
        #bytes 130 - 135 (CDB command Fields)
        cdb_cmd_fields[0] = 0 # byte 130, EPL Len MSB
        cdb_cmd_fields[1] = 0 # byte 131, EPL Len LSB
        cdb_cmd_fields[2] = payload_len # byte 132, LPL len
        cdb_cmd_fields[3] = checksum # byte 133, cdbCheckCode
        cdb_cmd_fields[4] = 0 # byte 134, Reply payload length (ignored by the module, default set to 0)
        cdb_cmd_fields[5] = 0 # byte 135, Reply payload checkcode (ignored by the module, default set to 0)

#       dut.I2CWrite(device_addr, 130, address, 6)
        cmd = (
            f"i2ctransfer -y -f {port_bus} w3@0x50 130 {cdb_cmd_fields[0]} {cdb_cmd_fields[1]};"
            f"sleep 0.05;"
            f"i2ctransfer -y -f {port_bus} w2@0x50 132 {cdb_cmd_fields[2]};"
            f"sleep 0.05;"
            f"i2ctransfer -y -f {port_bus} w2@0x50 133 {cdb_cmd_fields[3]};"
            f"sleep 0.05;"
            f"i2ctransfer -y -f {port_bus} w3@0x50 134 {cdb_cmd_fields[4]} {cdb_cmd_fields[5]};"
            f"sleep 0.05;"
        )
        print(cmd)
        os.system(cmd)
        
        """
        dut.I2CWrite(device_addr, 130, cdb_cmd_fields[0:2], 2)
        dut.I2CWrite(device_addr, 132, cdb_cmd_fields[2:3], 1)
        dut.I2CWrite(device_addr, 133, cdb_cmd_fields[3:4], 1)
        dut.I2CWrite(device_addr, 134, cdb_cmd_fields[4:], 2)
        """

        if payload_len>0:
            if CDB_command=='RUN_FW_IMAGE':
                cmd = (
                    f"i2ctransfer -y -f {port_bus} w3@0x50 136 {payload[0]};"
                    f"sleep 0.05;"
                    f"i2ctransfer -y -f {port_bus} w3@0x50 137 {payload[1]};"
                    f"sleep 0.05;"
                    f"i2ctransfer -y -f {port_bus} w3@0x50 138 {payload[2]} {payload[3]};"
                    f"sleep 0.05;"
                )
                print(cmd)
                os.system(cmd)
                """
                dut.I2CWrite(device_addr, 136, payload[0:1], 1)
                dut.I2CWrite(device_addr, 137, payload[1:2], 1)
                dut.I2CWrite(device_addr, 138, payload[2:], 2)
                """
            elif CDB_command=='START_FW_DOWNLOAD':
                print(CDB_command)
                payload_str = " ".join(str(i) for i in payload[0:4])
                print(payload_str)
                cmd = (
                    f"i2ctransfer -y -f {port_bus} w5@0x50 136 {payload_str};"
                    f"sleep 0.05;"
                )
                print(cmd)
                os.system(cmd)
                
                payload_str = " ".join(str(i) for i in payload[4:8])
                cmd = (
                    f"i2ctransfer -y -f {port_bus} w5@0x50 140 {payload_str};"
                    f"sleep 0.05;"
                )
                print(cmd)
                os.system(cmd)
                
                payload_str = " ".join(str(i) for i in payload[8:])
                cmd = (
                    f"i2ctransfer -y -f {port_bus} w{payload_len-7}@0x50 144 {payload_str};"
                    f"sleep 0.05;"
                )
                print(cmd)
                os.system(cmd)
                """
                dut.I2CWrite(device_addr, 136, payload[0:4], 4) # Image Size
                dut.I2CWrite(device_addr, 140, payload[4:8], 4) # Reserved
                dut.I2CWrite(device_addr, 144, payload[8:], payload_len-8) # Vendor Data
                """
            elif CDB_command=='WRITE_FW_DOWNLOAD_LPL':
                payload_str = " ".join(payload[0:4])
                cmd = (
                    f"i2ctransfer -y -f {port_bus} w5@0x50 136 {payload_str};"
                    f"sleep 0.05;"
                )
                print(cmd)
                os.system(cmd)
                
                payload_str = " ".join(payload[4:])
                cmd = (
                    f"i2ctransfer -y -f {port_bus} w{payload_len-3}@0x50 140 {payload_str};"
                )
                print(cmd)
                os.system(cmd)
                
                """
                dut.I2CWrite(device_addr, 136, payload[0:4], 4)
                dut.I2CWrite(device_addr, 140, payload[4:], payload_len-4)
                """

        cmd = (
            f"i2ctransfer -y -f {port_bus} w3@0x50 128 {cdb_cmd_code[0]} {cdb_cmd_code[1]};"
            f"sleep 0.05;"
        )
        print(cmd)
        os.system(cmd)
        #dut.I2CWrite(device_addr, 128, cdb_cmd_code, 2) # cdb command trigger

        # no error code return, just print error mesg when occurs
        # 
        Check_CDBStatus(port_bus, timeout_ms, 0)

        #my_data = [0]*1 #Array.CreateInstance(int,1)
        cmd = (
            f"i2cget -y -f {port_bus} 0x50 134;" # read length
            f"sleep 0.05;"
        )
        print(cmd)
        status = cli_run(cmd)
        print(status)
        #status = dut.I2CRead(device_addr, 134, my_data, 1)

        rtn = ''
        lpl_len = int(status, 16)
        print(lpl_len)
        if (lpl_len != 0):
            # TODO: data = [int(i, 16) for i in cmd_out.split()]
            cmd = (
                f"i2ctransfer -y -f {port_bus} w1@0x50 135 r{lpl_len+1};"
                f"sleep 0.05;"
            )
            cmd_out = cli_run(cmd)
            rtn = [int(i, 16) for i in cmd_out.split()]
            
            
            """
            rtn = Array.CreateInstance(int, status[0])
            my_data = Array.CreateInstance(int, len(rtn)+1)
            read_data = dut.I2CRead(device_addr, 135, my_data, len(rtn) + 1)
            checksum = 0

            for i in range(len(rtn)):
                rtn[i] = read_data[i + 1]
                checksum += read_data[i + 1]
                checksum &= 0xFF

            if ((~checksum & 0xFF) != read_data[0]):
                print("RLPLChkCode mismatch.")

                if (exceptOnChkCode):
                    raise Exception("RLPLChkCode mismatch.")
            """
 
        return rtn[1:]

def CommitImage(port_bus, device_addr = 0xA0):
    try:
        Step_pass=False
        message=''
        #DDwritepw(dut, 'MSA')
        GenerateCDB_Command(port_bus ,device_addr, CDB_command = 'COMMIT_FW_IMAGE')
        
        data = get_fw_info_data(port_bus)
        ReadCDBFWInfo(data[2:])
        Step_pass=True
        
    except Exception as e:
        print(str(e) + '.. when CommitImage is issued.')
        raise Exception(str(e) + '.. when CommitImage is issued.')
    return Step_pass, message


def RunImage(port_bus, device_addr = 0xA0):
    message = ''
    Step_pass = False
    send_data = [0]*4 #Array.CreateInstance(int, 4)
    send_data[0] = 0 # resv
    send_data[1] = 0 #Dont try hitless, 00h = reset to inactive image
    send_data[2] = 0
    send_data[3] = 100 #100ms delay
    try:
        data = get_fw_info_data(port_bus)
        runAStart, runBStart, imAverStart, imBverStart,imAValid,imBValid = ReadCDBFWInfo(data[2:])

        #DDwritepw(dut, 'ENG')
        GenerateCDB_Command(port_bus ,device_addr, CDB_command = 'RUN_FW_IMAGE', payload = send_data, exceptOnChkCode = False, delay = 1)
        time.sleep(2)
        data = get_fw_info_data(port_bus)
        runAEnd, runBEnd, imAverEnd, imBverEnd,imAValid,imBValid = ReadCDBFWInfo(data[2:])
        
        if  (runAEnd == 1) and (runBEnd==0) and (runAStart ==0) and (runBStart==1):
            Step_pass = True
            message += 'Run Image command successful! Start with Image B and End with Image A.'
            print(message)
        elif (runAEnd == 0) and (runBEnd==1) and (runAStart ==1) and (runBStart==0):
            Step_pass = True
            message += 'Run Image command successful! Start with Image A and End with Image B.'
            print(message)
        else:
            Step_pass = False
            message += 'Run Image command NOT successful!'
            print(message)
#                raise Exception(message)

        if (runAEnd):
            message += ' Image A is Running. Image A Version: ' + imAverEnd
            print('Image A is Running')
            print('Image A Version: ' + imAverEnd)
        if (runBEnd):
            message += ' Image B is Running. Image B Version: ' + imBverEnd
            print('Image B is Running')
            print('Image B Version: ' + imBverEnd)

        if imAValid:
            message += ' Image A is Valid'
            print('Image A is Valid')
        else:
            message += ' Image A is InValid'
            print('Image A is InValid')

        if imBValid:
            message += ' Image B is Valid'
            print('Image B is Valid')
        else:       
            message += ' Image B is InValid'
            print('Image B is InValid')
    except Exception as e:
        print(str(e) + '.. when RunImage is issued.')
        raise Exception(str(e) + '.. when RunImage is issued.')
        
    return Step_pass, message

def CDBFirmwareUpgrade(port_bus, fileName, device_addr = 0xA0, interrupt=False, inttype=''):
        Step_pass = False
        message = ''
        rtn = ''
        AbortSupported = True
        start_cmd_payload_size = 0
        epl_cdb_block_size = 0
        lpl_cdb_block_size = 0
        block_size = 0
        timeout_101 = 0
        timeout_102 = 0
        timeout_103 = 0
        timeout_107 = 0

        try:
            
            #maye, read page 01h, get cdb supported status, result: 0x47 
            """ 
            table = Array.CreateInstance(int, 1)
            table[0] = 0x1 #change page address
            dut.I2CWrite(device_addr, 127, table, 1) #Page 1h
            my_data = Array.CreateInstance(int, 1)
            data = dut.I2CRead(device_addr, 163, my_data, 1)
            if (data[0]>>6)==0 or (data[0]>>6)==3:
                raise Exception('CDB download not supported. page 01h, byte 163, value is ' +str(data[0]))
            """
            
            #ReadCDBFWInfo(dut, device_addr)
            #get_port_fw_info(port_bus)
            rtn = GenerateCDB_Command(port_bus ,device_addr, CDB_command = 'CDB_FEATURE')
            print(rtn)
            
            if (rtn == ''):
                print('Module return wrong info for command 0041h, upgrade aborted!')
                message += 'Module return wrong info for command 0041h, upgrade aborted!'
                return False, message
            # Command 0x41 info parcing
            #if (rtn[0] == 0x80): DDwritepw(dut, 'MSA') #byte 136
            
            if ((rtn[1] & 0x1) == 0): AbortSupported = False #byte 137
            start_cmd_payload_size = int(rtn[2]) #byte 138, payload len, sent with 0x0101h-Start Fw download command
            # Start_cmd_payload_size ( Page 9F byte: 138), this defines the number of bytes that the host must extract from the beginning
            # of the vendor-delivered binary firmware image file and send to the module in CMD 101h (start)
            block_size = FW_DATA_SIZE #(int(rtn[4])+1) * 8 #byte 140, maye
            timeout_101 = int((rtn[8] << 8) + rtn[9]) #bytes 144, 145
            timeout_102 = int((rtn[10] << 8) + rtn[11]) #bytes 146, 147
            timeout_103 = int((rtn[12] << 8) + rtn[13]) #bytes 148, 149
            timeout_107 = int((rtn[14] << 8) + rtn[15]) #bytes 150, 151
            print('start_cmd_payload_size: ' +str(start_cmd_payload_size))
            print('block_size: ' +str(block_size))
            print('Timeout_101: ' +str(timeout_101))
            print('Timeout_102: ' +str(timeout_102))
            print('Timeout_103: ' +str(timeout_103))
            print('Timeout_107: ' +str(timeout_107))
            
            
            # Open file
            image_data, total_bytes=GetFWImage(fileName)
            print(f"filename: {fileName}, size: {total_bytes}, File Data[:256]: ")
            print(image_data[:256])

            addr = 0
            # START_FW_DOWNLOAD command
            cdb_cmd_len = 8 # Page 9F bytes 128 to 135
            
            #start_fw_payload = Array.CreateInstance(int, (cdb_cmd_len + start_cmd_payload_size))
            start_fw_payload = [0]*(cdb_cmd_len + start_cmd_payload_size)
            # send_data = [0] * (8 + start_cmd_payload_size)

            # Image Size, bytes 136-139
            start_fw_payload[0] = int((total_bytes & 0xFF000000) >> 24)
            start_fw_payload[1] = int((total_bytes & 0xFF0000) >> 16)
            start_fw_payload[2] = int((total_bytes & 0xFF00) >> 8)
            start_fw_payload[3] = int(total_bytes & 0xFF)
            # Reserved bytes 140-143
            start_fw_payload[4] = 0
            start_fw_payload[5] = 0
            start_fw_payload[6] = 0
            start_fw_payload[7] = 0
            # Bytes 144-255(Vendor Data)
            for i in range(start_cmd_payload_size):
                start_fw_payload[cdb_cmd_len + i] = image_data[i] 

            #DDwritepw(dut, 'MSA')
            GenerateCDB_Command(port_bus ,device_addr, CDB_command = 'START_FW_DOWNLOAD', payload = start_fw_payload,  timeout_ms = timeout_101)
           
            byte_left = total_bytes - start_cmd_payload_size
            # block_data = [0] * (block_size + 4)
            addr_bytes_len = 4 # CMD 0x103h bytes (136-139) starting byte address of current block of data - start command payload size.
            
            #block_data = Array.CreateInstance(int, (block_size + addr_bytes_len))
            block_data = [0]*(block_size + addr_bytes_len)
            while (byte_left > 0):
                # Display Upgrade Progress
                progress = 100-((float(byte_left)/total_bytes)*100)
                percent = ("{0:.2f}").format(progress)
                filledLength = int(50 * float(byte_left) // float(total_bytes))
                bar = '|' * (50 - filledLength) + '-' * filledLength
                print('\nUpgrading Firmware.\n')
                print('\r%s |%s| %s%% %s' % ("Progress:", bar, percent, "complete."))
                
                # Write data blocks
                if (byte_left > block_size):
                    if byte_left<(total_bytes/2):
                        if interrupt:
                            if inttype=='ABORT':
                                raise Exception('Manual Abort issued to interrupt the download!')
                            elif inttype=='POWER':
                                # PowerCycle()
                                print("Power cyclced : not supported !")
                                raise Exception('Power Cycle Not supported yet!')
                                # return Step_pass, message
                    # byte 136-139, starting byte block adress minus start cmd payload size
                    block_data[0] = (addr & 0xFF000000) >> 24 
                    block_data[1] = (addr & 0xFF0000) >> 16 
                    block_data[2] = (addr & 0xFF00) >> 8
                    block_data[3] = (addr & 0xFF)
                    for i in range(block_size): # 2048 bytes for EPL , 120 bytes for LPL
                        block_data[addr_bytes_len + i] = image_data[start_cmd_payload_size + addr + i]
                    # GenerateCDB_Command(dut ,device_addr, CDB_command = 'WRITE_FW_DOWNLOAD_LPL', payload = block_data, timeout_ms = timeout_103)
                    # Add EPL write Command
                    writeFwBlock_EPL(port_bus, device_addr, payload = block_data, timeout_ms = timeout_103)
                    addr += block_size
                    byte_left -= block_size
                    #ReadCDBFWInfo(dut, device_addr)
                    get_port_fw_info(port_bus)
                else:
                    # left_byte = [0] * (byte_left + 4)
                    #left_byte = Array.CreateInstance(int, (byte_left + addr_bytes_len))
                    left_byte = [0]*(byte_left + addr_bytes_len)
                    left_byte[0] = (addr & 0xFF000000) >> 24
                    left_byte[1] = (addr & 0xFF0000) >> 16
                    left_byte[2] = (addr & 0xFF00) >> 8
                    left_byte[3] = (addr & 0xFF)
                    for i in range(byte_left):
                        left_byte[addr_bytes_len + i] = image_data[start_cmd_payload_size + addr + i]

                    # GenerateCDB_Command(dut ,device_addr, CDB_command = 'WRITE_FW_DOWNLOAD_LPL', payload = left_byte, timeout_ms = timeout_103)
                    # Add EPL Write Command
                    writeFwBlock_EPL(port_bus, device_addr, payload = left_byte, timeout_ms = timeout_103*100)
                    byte_left -= byte_left
                    #ReadCDBFWInfo(dut, device_addr)
                    get_port_fw_info(port_bus)

            #DDwritepw(dut, 'MSA')
            GenerateCDB_Command(port_bus ,device_addr, CDB_command = 'COMPLETE_FW_DOWNLOAD', timeout_ms = timeout_107+10000)
            #ReadCDBFWInfo(dut, device_addr)
            get_port_fw_info(port_bus)
            message += 'CDB Firmware Upgrade Succesful!'           
            Step_pass = True

        except Exception as e:
            if (AbortSupported): 
                print('CDB Firmware Upgrade Failed. CDB Firmware Upgrade will be aborted!')
                #GenerateCDB_Command(dut ,device_addr, CDB_command = 'ABORT_FW_DOWNLOAD', timeout_ms = timeout_102)
                message += 'CDB Firmware Upgrade Failed. ' + str(e) + ' Operation was aborted.'
                Step_pass = False
                return Step_pass, message
            else:
                print('CDB Firmware Upgrade Failed. CDB Firmware Upgrade Abort Not supported!')
                message += 'CDB Firmware Upgrade Failed. ' + str(e) + ' CDB Firmware Upgrade Abort Not supported!'
                Step_pass = False
                return Step_pass, message
        #ReadCDBFWInfo(dut, device_addr)
        get_port_fw_info(port_bus)
        
        # run image
        RunImage(port_bus)
        return Step_pass, message


#def writeFwBlock_EPL(dut, device_addr = 0xA0, payload = '', timeout_ms = 30000 ):
def writeFwBlock_EPL(port_bus, device_addr = 0xA0, payload = '', timeout_ms = 30000 ):
    print("*******Start of WRITE FW IMAGE EPL CDB COMMAND*******")
   
    addr_bytes_len = 4 # CMD 0x103h bytes (136-139) starting byte address of current block of data - start command payload size.
   
    """
    payload_len = 0
    if isinstance (payload, Array[int]):         
        payload_len = len(payload) - addr_bytes_len
    """
    payload_len = len(payload) - addr_bytes_len

    cdb_command = 0x0104 # byte 128-129, CDB CMD Code
    # payload_len = 128 # byte 130-131, epl payload len


    lpl_len = 0x04 # byte 132
    epl_len = payload_len
    epl_msb = (epl_len & 0xFF00) >> 8
    epl_lsb = epl_len & 0xFF
    addr = payload[0:4]

    # write payload data to page (0xA0h to 0xAFh)
    # select page A0h to write Firmware Image

    #write_page_select(dut, device_addr, 0xA0) # page A0h = 160
    #write_page_select(device_addr, 0xA0)
    #os.system(f"i2cset -y -f {port_bus} 0x50 0x7f 0xA0; sleep 0.05;")

    # Assuming Auto paging is enabled, if not we have to manually change (A0-AFh) pages
    # if payload_len > 0:
    # #dut.I2CWrite(device_addr, 128, payload[addr_bytes_len:], payload_len-4) #orig
    #     dut.I2CWrite(device_addr, 128, payload[0:128], payload_len-addr_bytes_len) # test

    # Manual paging 
    remaining_payload_size = payload_len
    total_epl_pages = 16
    count = addr_bytes_len
    while remaining_payload_size > 0:
        
        epl_page_index = 0xA0
        while epl_page_index < epl_page_index + total_epl_pages:
            size = FW_BLOCK_SIZE #128 # maye, max payload bytes per page
            if size > remaining_payload_size:
                size = remaining_payload_size
            page_payload = payload[count:count+size]
            #write data to EPL pages A0h - AFh
            #write_page_select(dut, device_addr, epl_page_index)
            #write_page_select(device_addr, epl_page_index)
            
            print('Writing EPL Data to page: ' + str(epl_page_index))
            cmd = f"i2cset -y -f {port_bus} 0x50 0x7f {epl_page_index}; sleep 0.05;"
            print(cmd)
            os.system(cmd)
            
            payload_str = " ".join(str(i) for i in page_payload)
            cmd = (
                f"i2ctransfer -y -f {port_bus} w{len(page_payload)+1}@0x50 128 {payload_str};"
                f"sleep 0.05;"
            )
            print(cmd)
            os.system(cmd)
            print("\n")
            #dut.I2CWrite(device_addr, 128, page_payload, size)

            #move to next page
            epl_page_index +=1
            count += size
            remaining_payload_size -= size
            if remaining_payload_size == 0: # No need to use all pages when there is no sufficient data
                break


    print('changing page to 0x9Fh')
    #write_page_select(dut, device_addr, 0x9F)
    #write_page_select(device_addr, 0x9F)
    os.system(f"i2cset -y -f {port_bus} 0x50 0x7f 0x9f; sleep 0.05;")

    print('***Page chage Successfull***')
   
    # Page 9Fh Bytes 128-129 (cmd codes), 130 - 135 (cmd fields)
    cdb_cmd_code = [0]*2 #Array.CreateInstance(int, 2)
    cdb_cmd_fields = [0]*6 #Array.CreateInstance(int, 6)
    
    checksum = 0
  
    checksum += ((cdb_command & 0xFF00) >> 8) # byte 128
    checksum &= 0xFF
    checksum += (cdb_command & 0xFF) # byte 129
    checksum &= 0xFF
    checksum += (epl_msb) # byte 130
    checksum &= 0xFF
    checksum += (epl_lsb) #byte 131
    checksum &= 0xFF
    checksum += (lpl_len & 0xFF) #byte 132
    checksum &= 0xFF
    #byte 133 to 135 = 0
    # Add bytes 136 to 139 (addr - blockaddress)
    checksum += (addr[0] & 0xFF) # byte 136
    checksum &= 0xFF
    checksum += (addr[1] & 0xFF) # byte 137
    checksum &= 0xFF
    checksum += (addr[2] & 0xFF) # byte 138
    checksum &= 0xFF
    checksum += (addr[3] & 0xFF) # byte 139
    checksum &= 0xFF

    checksum = (~checksum & 0xFF) # one's complement
 
    #bytes 128 - 133 (CDB command Fields)
    cdb_cmd_code[0] = (cdb_command & 0xFF00) >> 8 # byte 128, CMD code
    cdb_cmd_code[1] = cdb_command & 0xFF # byte 129, CMD Code
    cdb_cmd_fields[0] = epl_msb # byte 130, EPL Len MSB
    cdb_cmd_fields[1] = epl_lsb # byte 131, EPL Len LSB
    cdb_cmd_fields[2] = lpl_len # byte 132, LPL len
    cdb_cmd_fields[3] = checksum # byte 133, cdbCheckCode
    cdb_cmd_fields[4] = 0 # byte 134, Reply payload length (ignored by the module, default set to 0)
    cdb_cmd_fields[5] = 0 # byte 135, Reply payload checkcode (ignored by the module, default set to 0)

    cmd_str = f"i2ctransfer -y -f {port_bus} w3@0x50 130 {cdb_cmd_fields[0]} {cdb_cmd_fields[1]}"
    print(cmd_str)
    os.system(cmd_str)
    #dut.I2CWrite(device_addr, 130, cdb_cmd_fields[0:2], 2)
    
    cmd_str = f"i2ctransfer -y -f {port_bus} w2@0x50 132 {cdb_cmd_fields[2]}"
    print(cmd_str)
    os.system(cmd_str)
    #dut.I2CWrite(device_addr, 132, cdb_cmd_fields[2:3], 1)
    
    cmd_str = f"i2ctransfer -y -f {port_bus} w2@0x50 133 {cdb_cmd_fields[3]}"
    print(cmd_str)
    os.system(cmd_str)
    #dut.I2CWrite(device_addr, 133, cdb_cmd_fields[3:4], 1)
    
    cmd_str = f"i2ctransfer -y -f {port_bus} w3@0x50 134 {cdb_cmd_fields[4]} {cdb_cmd_fields[4]}"
    print(cmd_str)
    os.system(cmd_str)
    #dut.I2CWrite(device_addr, 134, cdb_cmd_fields[4:], 2)

    # addr_bytes_len = 4 # CMD 0x104h bytes (136-139) starting byte address of current block of data - start command payload size.
    
    if payload_len > 0:
        payload_str = " ".join(str(i) for i in payload[0:4])
        cmd_str = f"i2ctransfer -y -f {port_bus} w{addr_bytes_len+1}@0x50 136 {payload_str}"
        print(cmd_str)
        os.system(cmd_str)
        #dut.I2CWrite(device_addr, 136, payload[0:4], addr_bytes_len)

    cmd_str = f"i2ctransfer -y -f {port_bus} w3@0x50 128 {cdb_cmd_code[0]} {cdb_cmd_code[1]};sleep 5;"
    print(cmd_str)
    os.system(cmd_str)

    #dut.I2CWrite(device_addr, 128, cdb_cmd_code, 2) # cdb command trigger

    busy, fail, rt = Check_CDBStatus(port_bus, timeout_ms*100, 0)
    


    rtn = ''

    cmd = (
        f"i2cget -y -f {port_bus} 0x50 134;" # read length
        f"sleep 0.05;"
    )
    print(cmd)
    status = cli_run(cmd)
    print(status)
    #status = dut.I2CRead(device_addr, 134, my_data, 1)
    lpl_len = int(status, 16)
    print(lpl_len)
    
    if (lpl_len != 0):
        # TODO: data = [int(i, 16) for i in cmd_out.split()]
        cmd = (
            f"i2ctransfer -y -f {port_bus} w1@0x50 135 r{lpl_len+1};"
            f"sleep 0.05;"
        )
        cmd_out = cli_run(cmd)
        rtn = [int(i, 16) for i in cmd_out.split()]
        checksum = 0

        lplchkcode = rtn[0]

        for i in range(lpl_len):
            #rtn[i] = read_data[i + 1]
            checksum += rtn[i + 1]
            checksum &= 0xFF

        print(f"lplchkcode: {lplchkcode}, checksum: {~checksum & 0xFF}")
        if ((~checksum & 0xFF) != lplchkcode):
            print("RLPLChkCode mismatch.")
    
    if (fail):
        raise Exception("0104h EPL transfer failed...")
    
    return rtn[1:]
    
    """
    my_data = Array.CreateInstance(int,1)
    status = dut.I2CRead(device_addr, 134, my_data, 1)

    if (status[0] != 0):
        rtn = Array.CreateInstance(int, status[0])
        my_data = Array.CreateInstance(int, len(rtn)+1)
        read_data = dut.I2CRead(device_addr, 135, my_data, len(rtn) + 1)
        checksum = 0

        for i in range(len(rtn)):
            rtn[i] = read_data[i + 1]
            checksum += read_data[i + 1]
            checksum &= 0xFF

        if ((~checksum & 0xFF) != read_data[0]):
            print("RLPLChkCode mismatch.")
    """

    return rtn



module_parser = argparse.ArgumentParser(usage=USAGE)
subparsers = module_parser.add_subparsers(dest="function", help="subcommand help")

# info
osfp_fw_info_parser = subparsers.add_parser(
    "info", help="get OSFP/QSFP port firmware information"
)
osfp_fw_info_parser.add_argument("port_num", type=int)

osfp_fw_info_parser = subparsers.add_parser(
    "feat", help="get OSFP/QSFP port firmware mamangement feature"
)
osfp_fw_info_parser.add_argument("port_num", type=int)


# upgrade
osfp_fw_upgrade_parser = subparsers.add_parser("upgrade", help="Test OSFP/QSFP port")
osfp_fw_upgrade_parser.add_argument("file", type=str)
osfp_fw_upgrade_parser.add_argument("port_num", type=int)


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

    if args.function == "info":
        return lambda: (0, get_port_fw_info_by_port_num(args.port_num))
    if args.function == "feat":
        return lambda: (0, get_port_fw_feature(args.port_num))
    if args.function == "upgrade":
        return lambda: (0, upgrade_port_fw(args.file, args.port_num))
    return lambda: (-1, f"No function mapped to {args}.")


if __name__ == "__main__":
    module_executor(module_argparser, argv=None, shell=True)
