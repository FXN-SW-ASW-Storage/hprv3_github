"""OSFP VDM Database"""

import math
import subprocess as sp

media_parameters = [
    ("eSNR Media            ", 8, "U16", 1 / 256),
    ("LTP Media             ", 8, "U16", 1 / 256),
    ("Pre-FEC BER Media Max ", 8, "F16", 1),
    ("Pre-FEC BER Media Avg ", 8, "F16", 1),
    ("FERC Media Max        ", 8, "F16", 1),
    ("FERC Media Avg        ", 8, "F16", 1),
    ("FEC tail Media Max    ", 8, "U16", 1),
    ("FEC tail Media Current", 8, "U16", 1),
]

host_parameters = [
    ("eSNR Host             ", 8, "U16", 1 / 256),
    ("LTP Host              ", 8, "U16", 1 / 256),
    ("Pre-FEC BER Host Max  ", 8, "F16", 1),
    ("Pre-FEC BER Host Avg  ", 8, "F16", 1),
    ("FERC Host Max         ", 8, "F16", 1),
    ("FERC Host Avg         ", 8, "F16", 1),
    ("FEC tail Host Max     ", 8, "U16", 1),
    ("FEC tail Host Current ", 8, "U16", 1),
]

alarm_warning_parameters = [
    ("eSNR Media            ", 8),
    ("LTP Media             ", 8),
    ("Pre-FEC BER Media Max ", 8),
    ("Pre-FEC BER Media Avg ", 8),
    ("FERC Media Max        ", 8),
    ("FERC Media Avg        ", 8),
    ("FEC tail Media Max    ", 8),
    ("FEC tail Media Current", 8),
    ("eSNR Host             ", 8),
    ("LTP Host              ", 8),
    ("Pre-FEC BER Host Max  ", 8),
    ("Pre-FEC BER Host Avg  ", 8),
    ("FERC Host Max         ", 8),
    ("FERC Host Avg         ", 8),
    ("FEC tail Host Max     ", 8),
    ("FEC tail Host Current ", 8),
]

threshold_parameters = [
    ("eSNR Media         ", 1, "U16", 1 / 256),
    ("LTP Media          ", 2, "U16", 1 / 256),
    ("Pre-FEC BER Media  ", 3, "F16", 1),
    ("FERC Media         ", 4, "F16", 1),
    ("FEC tail Media     ", 5, "U16", 1),
    ("eSNR Host          ", 17, "U16", 1 / 256),
    ("LTP Host           ", 18, "U16", 1 / 256),
    ("Pre-FEC BER Host   ", 19, "F16", 1),
    ("FERC Host          ", 20, "F16", 1),
    ("FEC tail Host      ", 21, "U16", 1),
    ("PAM Level StDev    ", 33, "F16", 1),
    ("Custom MPI metric  ", 34, "F16", 1),
    ("Optional MPI metric", 35, "F16", 1),
]


def cli_run(cmd):
    """function to run shell commands"""
    with sp.Popen(cmd, shell=True, stdout=sp.PIPE, stderr=sp.PIPE) as sout:
        return sout.stdout.read().decode("utf-8")


def binary16ToFloat(binary_string, signed=False):
    """function to convert binary string to float"""
    if signed:
        exp = binary_string[1:6]
        mantissa = binary_string[6:]
        sign = 1 - 2 * int(binary_string[0])
    else:
        exp = binary_string[:5]
        mantissa = binary_string[5:]
        sign = 1
    value = sign * int(mantissa, 2) * (10 ** (int(exp, 2) - 24))
    return value


def get_vdm_values(module_bus):
    """function to get VDM values"""
    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x24;"
        f"i2ctransfer -y -f {module_bus} w1@0x50 128 r128;"
    )
    cmd_out = cli_run(cmd)
    media_vdm_page = [int(i, 16) for i in cmd_out.split()]

    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x25;"
        f"i2ctransfer -y -f {module_bus} w1@0x50 128 r128;"
    )
    cmd_out = cli_run(cmd)
    host_vdm_page = [int(i, 16) for i in cmd_out.split()]
    return media_vdm_page, host_vdm_page


def parse_vdm_values(vdm_page, is_media=True):
    """function to parse VDM values"""
    ob_id = 0
    print(
        """Lane Number           :        1        2        3"""
        """        4        5        6        7        8"""
    )
    if is_media:
        parameters = media_parameters
    else:
        parameters = host_parameters
    for observable in parameters:
        result_arr = []
        max_item_num = observable[1]
        for _ in range(max_item_num):
            raw_byte_vals = vdm_page[ob_id : ob_id + 2]
            ob_id += 2
            ob_value = 0
            if observable[2] == "U16":
                ob_value = (raw_byte_vals[0] * 256 + raw_byte_vals[1]) * observable[3]
            elif observable[2] == "F16":
                binary_string = bin(int(raw_byte_vals[0]))[2:].zfill(8) + bin(
                    int(raw_byte_vals[1])
                )[2:].zfill(8)
                ob_value = binary16ToFloat(binary_string)
            result_arr.append(ob_value)

        result_str_arr = [f"{elem:8.2f}" for elem in result_arr]
        print(f"{observable[0]}:", " ".join(map(str, result_str_arr)))


def get_vdm_aw(module_bus):
    """function to get VDM Alarm and Warning"""
    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x2c;"
        f" i2ctransfer -y -f {module_bus} w1@0x50 128 r128;"
    )
    cmd_out = cli_run(cmd)
    vdm_aw_page_compressed = [int(i, 16) for i in cmd_out.split()]
    vdm_aw_page = []
    for aw_pair in vdm_aw_page_compressed:
        vdm_aw_page.append(bin(aw_pair // 16)[2:].zfill(4))
        vdm_aw_page.append(bin(aw_pair % 16)[2:].zfill(4))
    return vdm_aw_page


def parse_vdm_aw(vdm_aw_page):
    """function to parse VDM Alarm and Warning"""
    aw_id = 0
    print("1: asserted; 0: non-asserted\n")
    item_num = 0
    for aw in alarm_warning_parameters:
        if item_num % 8 == 0:
            print(
                "                               : [  Low Alarm/Warnings  ] [ High Alarm/Warnings  ]"
            )
            print(
                "Lane Number                    : [1, 2, 3, 4, 5, 6, 7, 8] [1, 2, 3, 4, 5, 6, 7, 8]"
            )
        max_item_num = aw[1]
        result_low_warning_arr = [0, 0, 0, 0, 0, 0, 0, 0]
        result_high_warning_arr = [0, 0, 0, 0, 0, 0, 0, 0]
        result_low_alarm_arr = [0, 0, 0, 0, 0, 0, 0, 0]
        result_high_alarm_arr = [0, 0, 0, 0, 0, 0, 0, 0]
        for i in range(max_item_num):
            [low_warning, high_warning, low_alarm, high_alarm] = [
                int(v) for v in list(vdm_aw_page[aw_id])
            ]
            if low_warning != 0:
                result_low_warning_arr[i] = 1
            if high_warning != 0:
                result_high_warning_arr[i] = 1
            if low_alarm != 0:
                result_low_alarm_arr[i] = 1
            if high_alarm != 0:
                result_high_alarm_arr[i] = 1
            aw_id += 1
        print(f"{aw[0]} Alarms  : {result_low_alarm_arr} {result_high_alarm_arr}")
        print(f"{aw[0]} Warnings: {result_low_warning_arr} {result_high_warning_arr}")
        item_num += 1


def get_vdm_threshold(module_bus):
    """function to get VDM Threshold"""
    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x28;"
        f"i2ctransfer -y -f {module_bus} w1@0x50 128 r128;"
    )
    cmd_out = cli_run(cmd)
    thresh_vdm_page1 = [int(i, 16) for i in cmd_out.split()]

    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x29;"
        f"i2ctransfer -y -f {module_bus} w1@0x50 128 r128;"
    )
    cmd_out = cli_run(cmd)
    thresh_vdm_page2 = [int(i, 16) for i in cmd_out.split()]

    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x2a;"
        f" i2ctransfer -y -f {module_bus} w1@0x50 128 r128;"
    )
    cmd_out = cli_run(cmd)
    thresh_vdm_page3 = [int(i, 16) for i in cmd_out.split()]

    return thresh_vdm_page1 + thresh_vdm_page2 + thresh_vdm_page3


def parse_vdm_threshold(thresh_vdm_pages):
    """function to parse VDM Threshold"""
    thr_byte_id = 0
    # print(
    #    "                            HighAlarm         LowAlarm      HighWarning       LowWarning"
    # )
    item_num = 0
    for p in threshold_parameters:
        if item_num % 5 == 0:
            print(
                """\n                            HighAlarm         """
                """LowAlarm      HighWarning       LowWarning"""
            )
        result_arr = []
        if p[1] > 16 and p[1] <= 32:
            thr_byte_id = 128 if thr_byte_id < 128 else thr_byte_id
        elif p[1] > 32:
            thr_byte_id = 256 if thr_byte_id < 256 else thr_byte_id
        for _, _name in enumerate(
            ["HighAlarm", "LowAlarm", "HighWarning", "LowWarning"]
        ):
            raw_byte_vals = thresh_vdm_pages[thr_byte_id : thr_byte_id + 2]
            thr_value = 0
            if p[2] == "U16":
                thr_value = (raw_byte_vals[0] * 256 + raw_byte_vals[1]) * p[3]
            elif p[2] == "F16":
                binary_string = bin(int(raw_byte_vals[0]))[2:].zfill(8) + bin(
                    int(raw_byte_vals[1])
                )[2:].zfill(8)
                thr_value = binary16ToFloat(binary_string)
            thr_byte_id += 2
            result_arr.append(thr_value)

        result_str_arr = [f"{elem:16.2f}" for elem in result_arr]
        print(f"{p[0]}:", " ".join(map(str, result_str_arr)))
        item_num += 1


def get_power(module_bus):
    """function to get power"""
    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x11;"
        f"i2cget -y -f {module_bus} 0x50 154 i 16"
    )
    cmd_out = cli_run(cmd)
    it = iter(cmd_out.split())
    tx_power = [
        10 * math.log10(max(int(x, 16), 1) * 256 + int(next(it), 16)) - 40 for x in it
    ]

    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x01;"
        f" i2cget -y -f {module_bus} 0x50 160"
    )
    cmd_out = cli_run(cmd)
    cmd_out = int(cmd_out, 16)
    if cmd_out & 0x18 == 0:
        bias_factor = 1
    elif cmd_out & 0x18 == 0x08:
        bias_factor = 2
    elif cmd_out & 0x18 == 0x10:
        bias_factor = 4

    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x11;"
        f" i2cget -y -f {module_bus} 0x50 170 i 16"
    )
    cmd_out = cli_run(cmd)

    it = iter(cmd_out.split())
    tx_bias = [(int(x, 16) * 256 + int(next(it), 16)) * 2 * bias_factor for x in it]

    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x11;"
        f" i2cget -y -f {module_bus} 0x50 186 i 16"
    )
    cmd_out = cli_run(cmd)

    it = iter(cmd_out.split())
    rx_power = [10 * math.log10(int(x, 16) * 256 + int(next(it), 16)) - 40 for x in it]
    return tx_power, tx_bias, rx_power


def display_power(tx_power, tx_bias, rx_power):
    """function to display power"""
    print(
        "Lane Number    :        1        2        3        4        5        6        7        8"
    )
    result_str_arr = [f"{elem:8.2f}" for elem in tx_power]
    print("TX Power in dbm:", " ".join(map(str, result_str_arr)))

    result_str_arr = [f"{elem:8.2f}" for elem in tx_bias]
    print("TX Bias  in  uA:", " ".join(map(str, result_str_arr)))

    result_str_arr = [f"{elem:8.2f}" for elem in rx_power]
    print("RX Power in dbm:", " ".join(map(str, result_str_arr)))


def get_lane_flags(module_bus):
    """function to get lane flags"""
    cmd = (
        f"i2cset -y -f {module_bus} 0x50 0x7f 0x11;"
        f"i2cget -y -f {module_bus} 0x50 134 i 20"
    )
    cmd_out = cli_run(cmd)
    return cmd_out


def display_lane_flags(lane_flags):
    """function to display lane flags"""
    print(
        """            DPS  [ TX  LOS  LOL   EQ OPHA OPLA OPHW OPLW LBHA LBLA LBHW LBLW]"""
        """[ RX  LOL OPHA OPLA OPHW OPLW OSXF]"""
    )
    print("Lane Flags:", lane_flags)


def get_cmis_vdm_info(port_bus):
    """function to get cmis vdm info"""
    print("\n--- Getting Versatile Diagnostic Monitoring values ---")
    media_vdm_page, host_vdm_page = get_vdm_values(port_bus)
    parse_vdm_values(media_vdm_page, is_media=True)
    print("")
    parse_vdm_values(host_vdm_page, is_media=False)


def get_cmis_alarm_info(port_bus):
    """function to get cmis alarm info"""
    print("\n--- Getting Alarm and Warning values ---")
    aw_parameters = get_vdm_aw(port_bus)
    parse_vdm_aw(aw_parameters)


def get_cmis_thres_info(port_bus):
    """function to get cmis thres info"""
    print("\n--- Getting Threshold values ---")
    alarm_warning_threshold = get_vdm_threshold(port_bus)
    parse_vdm_threshold(alarm_warning_threshold)


def get_cmis_power_info(port_bus):
    """function to get cmis txrx info"""
    print("\n--- Getting TX and RX power values ---")
    tx_power, tx_bias, rx_power = get_power(port_bus)
    display_power(tx_power, tx_bias, rx_power)


def get_cmis_flag_info(port_bus):
    """function to get cmis flag info"""
    print("\n--- Getting lane-specific flags ---")
    laneflag_output = get_lane_flags(port_bus)
    display_lane_flags(laneflag_output)


def get_cmis_all_info(port_bus):
    """Get VDM information"""
    print("\n--- Getting Versatile Diagnostic Monitoring values ---")
    media_vdm_page, host_vdm_page = get_vdm_values(port_bus)
    parse_vdm_values(media_vdm_page, is_media=True)
    print("")
    parse_vdm_values(host_vdm_page, is_media=False)

    print("\n--- Getting Alarm and Warning values ---")
    aw_parameters = get_vdm_aw(port_bus)
    parse_vdm_aw(aw_parameters)

    print("\n--- Getting Threshold values ---")
    alarm_warning_threshold = get_vdm_threshold(port_bus)
    parse_vdm_threshold(alarm_warning_threshold)

    print("\n--- Getting TX and RX power values ---")
    tx_power, tx_bias, rx_power = get_power(port_bus)
    display_power(tx_power, tx_bias, rx_power)

    print("\n--- Getting lane-specific flags ---")
    laneflag_output = get_lane_flags(port_bus)
    display_lane_flags(laneflag_output)


CMS_PORT_FUNC_DICT = {
    "vdm": get_cmis_vdm_info,
    "alarm": get_cmis_alarm_info,
    "thres": get_cmis_thres_info,
    "power": get_cmis_power_info,
    "flag": get_cmis_flag_info,
    "all": get_cmis_all_info,
}


def get_cmis_info(item: str, port_bus):
    """function to get cmis info"""
    if item in CMS_PORT_FUNC_DICT:
        CMS_PORT_FUNC_DICT[item](port_bus)
