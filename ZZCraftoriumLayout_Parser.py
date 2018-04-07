#! /usr/bin/python3
#
# python3 parser <input.txt> <output.lua>
#
import sys
import re

# Write a message to log, or stdout, or whatever.
# Or don't.
#
#   LOG("one")
#   LOG("two {}", 2)
#   LOG("three {c}", c=3)
#
def LOG(msg, *args, **kwargs):
    print(msg.format(*args, **kwargs))

# Z1  86,000   comments-ignored
def parse_constant_assignment(line, parsed_line):
    r = r'([xzyXZY]\d+)\s+([\d,]+).*'
    m = re.match(r,line)
    if not m:
        return None
    var = m.group(1).lower()
    val = m.group(2)
    val = val.replace(',', '')
    val = int(val)
    parsed_line["assign"] = { var: var
                            , val: val
                            }
    LOG("assign: {} = {}", var, val)
    return parsed_line

# X3 Z14 Y19,000
def parse_axis(line, axis):
    r = axis.lower() + r'([\d,]+)'
    m = re.search(r, line.lower())
    if not m:
        return None
    val = m.group(1)
    val = val.replace(',','')
    return int(val)

def parse_xzy(line, parsed_line):
    axis_seen = False
    for axis in ['x','z','y']:
        r = parse_axis(line, axis)
        if r:
            parsed_line[axis] = r
            axis_seen = True
    return axis_seen

# station
# 3 stations
def parse_station_ct(line):
    rn = r'(\d+) stations'
    m = re.search(rn, line)
    if m:
        val = m.group(1)
        val = int(val)
        return val
    r1 = r'station'
    if re.search(r1, line):
        return 1
    return None

# direction
def parse_direction(line):
    for d in ['north','east','south','west']:
        if d in line.lower():
            return d
    return None

# lamp control
def parse_lamp(line):
    for cmd in ['hide lamp', 'omit lamp', 'sconce']:
        if cmd in line:
            return cmd
    return None

def parse_station(line, parsed_line):
    for station in ['jw','bs','cl','ww']:
        if station in line:
            parsed_line['station'] = station
            axis_seen = parse_xzy(line, parsed_line)
            return station
    return None


# Read a line and return its commands
#
#   .comment    = "# patio front"
#   .assign     = { var="z1", val=86000 }
#   .x          = 3
#   .z          = 14
#   .y          = 19999
#   .station_ct = 4
#   .direction  = 'east'
#   .lamp       = 'hide lamp'
#   .station    = 'jw'
#
def parse_one_line(line):
    parsed_line = {}

                        # Strip, but remember, comments
    l = line.strip()
    m = re.search(r'#.*', l)
    if m:
        parsed_line["comment"] = m.group(0)
        l = l[:m.start()].strip()
        LOG("retain: {}  comment: {}", l, parsed_line["comment"])

                        # Skip blank lines (or blank after comments removed)
    if not l:
        return parsed_line

                        # Constant assignments get their own line.
    if parse_constant_assignment(l, parsed_line):
        return parsed_line

                        # Station count.
    station_ct = parse_station_ct(line)
    if station_ct:
        parsed_line["station_ct"] = station_ct
        LOG("station_ct:{}",station_ct)
        return parsed_line

                        # NESW direction
    direction = parse_direction(line)
    if direction:
        parsed_line['direction'] = direction
        LOG("direction: {}", direction)
        return parsed_line

                        # lamp control
    lamp = parse_lamp(line)
    if lamp:
        parsed_line['lamp'] = lamp
        LOG("lamp: {}", lamp)
        return parsed_line

                        # individual stations with optional XZY coords
    station = parse_station(line, parsed_line)
    if station:
        x = parsed_line.get('x')
        z = parsed_line.get('z')
        y = parsed_line.get('y')
        LOG("station:{station}  X:{x} Z:{z} Y:{y}"
             , station=station, x=x, y=y, z=z)
        return parsed_line

                        # XZY commands
    axis_seen = parse_xzy(line, parsed_line)
    if axis_seen:
        x = parsed_line.get('x')
        z = parsed_line.get('z')
        y = parsed_line.get('y')
        LOG("X:{x} Z:{z} Y:{y}", x=x, y=y, z=z)
        return parsed_line


def parse_lines(input_lines):
    parser_state = {}
    output_lines = []

    for line in input_lines:
        parsed_line = parse_one_line(line)

    return output_lines


# -- main --------------------------------------------------------------------

def main():
    print("Cheers luv!")
    if len(sys.argv) < 3:
        sys.stderr.write("Usage: python3 Parser.py <inputfile> <outputfile>")
        sys.exit(1)

    input_filepath = sys.argv[1]
    output_filepath = sys.argv[2]

    print("in:{}  out:{}".format(input_filepath, output_filepath))

    with open(input_filepath) as f:
        input_lines = f.readlines()

    print("Read line ct: " + str(len(input_lines)))

    output_lines = parse_lines(input_lines)

    with open(output_filepath, "w") as f:
        f.write("\n".join(output_lines))

    print("Write line ct: " + str(len(output_lines)))

main()
