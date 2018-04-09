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
    for cmd in ['lamp', 'hide lamp', 'omit lamp', 'sconce']:
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
#   .line_number = 123
#   .line        = ""
#   .comment     = "# patio front"
#   .assign      = { var="z1", val=86000 }
#   .x           = 3
#   .z           = 14
#   .y           = 19999
#   .station_ct  = 4
#   .direction   = 'east'
#   .lamp        = 'hide lamp'
#   .station     = 'jw'
#
def parse_one_line(line, line_number):
    parsed_line = { 'line_number' : line_number
                  , 'line'        : line
                  }

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


def ParserState():
    parser_state = {
          'x' = 0
        , 'y' = 0
        , 'z' = 0
        , 'prev_station' = 'jw'
        , 'direction'    = 'north'
        , 'item_queue'   = []
        , 'constant'     = {}
        , 'output_lines' = []
    }
    return parser_state

def apply_line(parsed_line, parser_state):
                        # variable assignment
    assign = parsed_line.get('assign')
    if assign:
        parser_state['constant'][assign.var] = assign.val
        return

                        # single-station manual location
    has_coord = parsed_line.get('x') or
             or parsed_line.get('z')
             or parsed_line.get('y')
    station   = parsed_line.get('station')
    if station and has_coord:
        error_if_queue_not_empty(parsed_line, parser_state)
        emit_station(parsed_line, parser_state)
        parser_state['prev_station'] = station
        return

                        # Specifying what the first
                        # station of the next emit run
                        # should be.
    if station:
        parser_state['item_queue'].append(station)
        parser_state['prev_station'] = station
        return

                        # XZY coords end any current
                        # run, and start a new run.
    if has_coord:
                        # If we have any stations in our item_queue, we just
                        # got the ending coordinate for the queue's run.
                        # Time to spit them out.
        if 0 < len(parser_state['item_queue']):
            append_end_lamp(parser_state)
            emit_queue(parsed_line, parser_state)
            parser_state['item_queue'] = []
                        # Copy these coordinates as the starting point
                        # of any next run of lamps or stations.
        for axis in ['x','z','y']:
            parser_state[axis] = parsed_line.get(axis) or parser_state[axis]
        return

                        # Enqueue 1 or more sets of 4 stations,
    station_ct = parsed_line.get('station_ct')
    if station_ct:
        station_order = { 'jw' : ['jw', 'bs', 'cl', 'ww']
                        , 'ww' : ['ww', 'cl', 'bs', 'jw']
                        }
        for i in range(station_ct):
            append_end_lamp(parser_state)
            so = station_order[ parser_state['prev_station'] ]
            parser_state['item_queue'].extend(so)
            parser_state['prev_station'] = so[-1]
        return

                        # Turn a corner.
    direction = parsed_line.get('direction')
    if direction:
        error_if_queue_not_empty(parsed_line, parser_state)
        parser_state['direction'] = direction
        return

                        # Append lamp.
    lamp = parsed_line.get('lamp')
    if lamp:
        parser_state['item_queue'].append(lamp)


def error_if_queue_not_empty(parsed_line, parser_state):
    if len(parser_state['item_queue']) <= 0:
        sys.stderr.write("### Error line {}: item queue not empty"
                         .format(parsed_line['line_number']))
        sys.exit(1)

def emit_station(parsed_line, parser_state):
    # write the single station specified by parsed_line, with
    # any missing info (usually rotation, maybey Y coord) from parser state
    WRITE_ME()

def emit_queue(parsed_line, parser_state):
    # Evenly distribute the distance between parsed_line's coordinates (the end)
    # and parser_state's coordinates (the beginning) across all of the
    # lamps and stations in the item_queue.
    WRITE_ME()

def append_end_lamp(parser_state):
    # If the item queue does not already end in a lamp.
    # append one now.
    q = parser_state['item_queue']      # for less typing
    if 0 == len(q) or is_lamp(q[-1]):
        return
    q.append('lamp')

def is_lamp(item):
    return item in ['lamp', 'hide lamp', 'omit lamp', 'sconce']

def parse_lines(input_lines):
    parser_state = ParserState()
    output_lines = []
    line_number  = 1
    for line in input_lines:
        parsed_line = parse_one_line(line, line_number)
        apply_line(parsed_line, parser_state)
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
