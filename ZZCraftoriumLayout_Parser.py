#! /usr/bin/python3
#
# python3 parser <input.txt> <output.lua>
#
import collections
import math
import numpy
import re
import sys

# Write a message to log, or stdout, or whatever.
# Or don't.
#
#   LOG("one")
#   LOG("two {}", 2)
#   LOG("three {c}", c=3)
#
def LOG(msg, *args, **kwargs):
    print(msg.format(*args, **kwargs))

def LOGPARSE(msg, *args, **kwargs):
    # LOG(msg, args, kwargs)
    pass

def parse_end(line, parsed_line):
    if "__END__" in line:
        parsed_line["end"] = True
        return True
    return False

# furn bs 4620697946441423477 Blacksmithing Station (Alessia's Bulwark)
def parse_furn_assignment(line, parsed_line):
    r = r'^furn\s+([\S+]+)\s+(\d+)'
    m = re.match(r, line)
    if not m:
        return None
    station = m.group(1).lower()
    furn_id = int(m.group(2))
    parsed_line['furn'] = { 'station' : station
                          , 'id'      : furn_id
                          }
    return parsed_line

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
    parsed_line["assign"] = { "var": var
                            , "val": val
                            }
    LOGPARSE("parse assign: {} = {}", var, val)
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
    for axis in ['x','z','y','rotation']:
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
    for cmd in ['hide lamp', 'omit lamp', 'lamp', 'sconce']:
        if cmd in line:
            return cmd
    return None

def parse_station(line, parsed_line):
    for station in ['jw','bs','cl','ww']:
        if station in line:
            parsed_line['station'] = station
            LOGPARSE("parsed station: {}",station)
            axis_seen = parse_xzy(line, parsed_line)
            return station
    return None


# Read a line and return its commands
#
#   .line_number = 123
#   .line        = ""
#   .file        = "input.txt"
#   .comment     = "# patio front"
#   .furn        = { station = 'bs', id = 4620697946441423477 }
#   .assign      = { var="z1", val=86000 }
#   .x           = 3
#   .z           = 14
#   .y           = 19999
#   .station_ct  = 4
#   .direction   = 'east'
#   .lamp        = 'hide lamp'
#   .station     = 'jw'
#
def parse_one_line(line, line_number, input_filepath):
    parsed_line = { 'line_number' : line_number
                  , 'line'        : line
                  , 'file'        : input_filepath
                  }
    # LOG("parse  {}:{}  {}".format(input_filepath, line_number, line.strip()))
                        # Strip, but remember, comments
    l = line.strip()
    m = re.search(r'#.*', l)
    if m:
        parsed_line["comment"] = m.group(0)
        l = l[:m.start()].strip()
        # LOG("retain: {}  comment: {}", l, parsed_line["comment"])

                        # Skip blank lines (or blank after comments removed)
    if not l:
        return parsed_line

                        # __END__ file terminator borrowed from perl
    if parse_end(l, parsed_line):
        return parsed_line

                        # Furnishing assignments
    if parse_furn_assignment(l, parsed_line):
        return parsed_line
                        # Constant assignments get their own line.
    if parse_constant_assignment(l, parsed_line):
        return parsed_line

                        # Station count.
    station_ct = parse_station_ct(l)
    if station_ct:
        parsed_line["station_ct"] = station_ct
        LOGPARSE("parse station_ct:{}",station_ct)
        return parsed_line

                        # NESW direction
    direction = parse_direction(l)
    if direction:
        parsed_line['direction'] = direction
        LOGPARSE("parse direction: {}", direction)
        return parsed_line

                        # lamp control
    lamp = parse_lamp(l)
    if lamp:
        parsed_line['lamp'] = lamp
        LOGPARSE("parse lamp: {}", lamp)
        return parsed_line

                        # individual stations with optional XZY coords
    station = parse_station(l, parsed_line)
    if station:
        x = parsed_line.get('x')
        z = parsed_line.get('z')
        y = parsed_line.get('y')
        LOGPARSE("parse station xzy:{station}  X:{x} Z:{z} Y:{y}"
             , station=station, x=x, y=y, z=z)
        return parsed_line

                        # XZY commands
    axis_seen = parse_xzy(l, parsed_line)
    if axis_seen:
        x = parsed_line.get('x')
        z = parsed_line.get('z')
        y = parsed_line.get('y')
        LOGPARSE("parse xzy X:{x} Z:{z} Y:{y}", x=x, y=y, z=z)
        return parsed_line


def ParserState():
    parser_state = {
          'x'               : 0
        , 'y'               : 0
        , 'z'               : 0
        , 'prev_station'    : 'jw'
        , 'direction'       : 'north'
        , 'item_queue'      : []
        , 'furn'            : collections.defaultdict(list)
        , 'furn_index_prev' : {}
        , 'constant'        : {}
        , 'output_lines'    : []
    }
    return parser_state

def expand_constant(axis, value, parser_state):
    if 100 < value:
        return value
    key = "{}{}".format(axis.lower(), value)
    if key in parser_state['constant']:
        return parser_state['constant'][key]
    error("constant {} not found".format(key))

def get_furn(station, station_index, parser_state):
    furn_list = parser_state['furn'].get(station)
    if not furn_list:
        error("furn {} {} not defined: no {} at all"
              .format(station, station_index, station))
    if len(furn_list) < station_index:
        error("furn {} {} not defined: no index {}"
              .format(station, station_index, station_index))
    return furn_list[station_index - 1]

def apply_line(parsed_line, parser_state):
    LOG("apply {}:{:<3} {}".format( parsed_line["file"]
                                   , parsed_line["line_number"]
                                   , parsed_line["line"].strip()
                                   ))
    if parsed_line.get("end"):
        LOG("__END__")
        parser_state['end'] = True
        return

                        # furnishing assignment
    furn = parsed_line.get('furn')
    if furn:
        parser_state['furn'][furn.get('station')].append(furn.get('id'))
        # LOG( "apply furn:{} ct:{} id:{}"
        #    , furn.get('station')
        #    , len(parser_state['furn'][furn.get('station')])
        #    , furn.get('id')
        #    )
        return
                        # variable assignment
    assign = parsed_line.get('assign')
    if assign:
        var = assign["var"]
        val = assign["val"]
        LOG("apply assign: {} = {}".format(var, val))
        parser_state['constant'][var] = val
        return

                        # Before using xzy coords in any way, expand constants.
    has_coord = parsed_line.get('x') or parsed_line.get('z') or parsed_line.get('y')
    if has_coord:
        for axis in ['x','z','y']:
            if axis in parsed_line:
                parsed_line[axis] = expand_constant( axis
                                                   , parsed_line[axis]
                                                   , parser_state )

                        # single-station manual location
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
            LOG("item_queue cleared")
                        # Copy these coordinates as the starting point
                        # of any next run of lamps or stations.
        for axis in ['x','z','y']:
            val = parsed_line.get(axis) or parser_state[axis]
            if val < 100:
                key = "{}{}".format(axis, val)
                constant = parser_state["constant"].get(key)
                LOG("expand {} -> {}".format(key, constant))
                if not constant:
                    error("no value for constant {}".format(key))
                val = constant
            if val == 0:
                error("coord {}".format(axis,val))
            parser_state[axis] = val
        return
        LOG("apply xzy x:{:<5} z:{:<5} y:{:<5}".format(x,z,y))

                        # Enqueue 1 or more sets of 4 stations,
    station_ct = parsed_line.get('station_ct')
    if station_ct:
        LOG("station_ct:{}",station_ct)
                        # precede with implied lamp if nothing explicitly queued.
        if len(parser_state['item_queue']) <= 0:
            LOG("item_queue += lamp")
            parser_state['item_queue'].append('lamp')

        station_order = { 'jw' : ['jw', 'bs', 'cl', 'ww']
                        , 'ww' : ['ww', 'cl', 'bs', 'jw']
                        }
        for i in range(station_ct):
            append_end_lamp(parser_state)
            so = station_order[ parser_state['prev_station'] ]
            parser_state['item_queue'].extend(so)
            parser_state['prev_station'] = so[-1]
            LOG("item_queue += station set: {}",so)
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
        LOG("item_queue += lamp: {}",lamp)


def error_if_queue_not_empty(parsed_line, parser_state):
    if 0 < len(parser_state['item_queue']):
        s = ("### Error {} line {}: item queue not empty"
             .format( parsed_line['file']
                    , parsed_line['line_number']
                    ))
        error(s)

def error(msg):
        LOG(msg)
        sys.stderr.write(msg+"\n")
        sys.exit(1)

# Rotation, in degrees, for a station when running along
# the given direction.
ROTATION = {
      'north' :  90
    , 'east'  : 180
    , 'south' : 270
    , 'west'  :   0
}

# width in pixels along the wall
WIDTH = {
      'omit lamp' :   0   # no lamp, no space for lamp
    , 'hide lamp' : 160   # suppress lamp, but count space as if one were there.
    , 'lamp'      : 160
    , 'sconce'    : 160
    , 'jw'        : 200
    , 'bs'        : 160
    , 'cl'        : 200
    , 'ww'        : 200
}

def emit_station(parsed_line, parser_state):
    LOG("Emit station {}".format(parsed_line.get('station')))
    # write the single station specified by parsed_line, with
    # any missing info (usually rotation, maybey Y coord) from parser state
    station  = parsed_line['station']
    index    = next_station_index(station, parser_state)
    rotation = ROTATION[parser_state['direction']]
    args = { "station"       : station
           , "station_index" : index
           , "x"             : parsed_line.get('x') or parser_state.get('x')
           , "z"             : parsed_line.get('z') or parser_state.get('z')
           , "y"             : parsed_line.get('y') or parser_state.get('y')
           , "rotation"      : parsed_line.get('rotation') or rotation
           }
    emit_line(args, parser_state)


def emit_queue(parsed_line, parser_state):
    LOG("Emit queue: {}".format(" ".join(parser_state.get('item_queue'))))

    # Evenly distribute the distance between parsed_line's coordinates (the end)
    # and parser_state's coordinates (the beginning) across all of the
    # lamps and stations in the item_queue.
    start_coord = { "x" : parser_state.get("x")
                  , "z" : parser_state.get("z")
                  , "y" : parser_state.get("y")
                  }
    end_coord   = { "x" : parsed_line.get("x") or parser_state.get("x")
                  , "z" : parsed_line.get("z") or parser_state.get("z")
                  , "y" : parsed_line.get("y") or parser_state.get("y")
                  }
    delta_total = { "x" : end_coord.get("x") - start_coord.get("x")
                  , "z" : end_coord.get("z") - start_coord.get("z")
                  , "y" : end_coord.get("y") - start_coord.get("y")
                  }
                        # How long in pixels is our queued list of items?
                        # Don't include the width of the terminal lamp or
                        # station, since we want it at the end coord
                        # on the current parser_line.
    total_item_width = 0
    for item in parser_state['item_queue'][0:-1]:
        total_item_width += WIDTH[item]
        LOG("emit_queue item width {:<10} = {:5d}", item, WIDTH[item])
    total_item_width = max(1,total_item_width) # to avoid divide-by-zero
    LOG("emit_queue item width {:<10}   {:5d}", "total", total_item_width)
    LOG("emit_queue start_coord: x:{x:6d} z:{z:6d} y:{y:6d}",**start_coord)
    LOG("emit_queue end_coord:   x:{x:6d} z:{z:6d} y:{y:6d}",**end_coord)
    LOG("emit_queue delta_total: x:{x:6d} z:{z:6d} y:{y:6d}",**delta_total)

    curr_coord = { "x" : start_coord.get("x")
                 , "z" : start_coord.get("z")
                 , "y" : start_coord.get("y")
                 }
    cume_width = 0
    for item in parser_state['item_queue']:

        if item in ["omit lamp", "hide lamp"]:
            pass        # count the space, but emit nothing in the space
        else:
            args = calc_emit_args(item, curr_coord, parser_state)
            emit_line(args, parser_state)
        if item == "lamp":
                        # emit a second line for the hanging lantern
            args = calc_emit_args("lantern", curr_coord, parser_state)
            emit_line(args, parser_state)

                        # Move to next position.
                        # (Calculated, then discarded, for the last item
                        #  in the queue. Easier to calc-and-discard than to
                        #  rearrange code to skip the wasted calculation time.)
        cume_width += WIDTH[item]
        ratio      = cume_width / total_item_width
        for axis in ["x","z","y"]:
            curr_coord[axis] = int(ratio * delta_total[axis]
                                   + start_coord[axis])

            # LOG("emit_queue {}: w:{:4d}/{:<4d}  {:4.2f} * {:<5d} + {:<5d} = {:<5d}"
            #    , axis
            #    , cume_width
            #    , total_item_width
            #    , ratio
            #    , delta_total[axis]
            #    , start_coord[axis]
            #    , curr_coord[axis]
            #    )

def rotate_matrix(degrees):
    theta = degrees * numpy.pi / 180
    cos = numpy.cos
    sin = numpy.sin
    r = numpy.array( [ [cos(theta), -sin(theta)]
                     , [sin(theta),  cos(theta)] ])
    return r

def rotate(x, z, degrees):
    v = numpy.array([ [x]
                    , [z] ])
    r = rotate_matrix(degrees)
    v_rotated = r @ v
    return int(v_rotated[0,0]), int(v_rotated[1,0])

ROTATION_FROM_NORTH = {
      'north' : 0
    , 'east'  : 90
    , 'south' : 180
    , 'west'  : 270
}
OFFSETS_NORTH = {
    'lamp'    : { 'x': -200, 'z':   0, 'y':   0, 'rotation': 270 }
  , 'lantern' : { 'x':  -38, 'z':   0, 'y': 491, 'rotation':   0 }
  , 'bs'      : { 'x':    0, 'z':  40, 'y':   0, 'rotation':  60 }
  , 'cl'      : { 'x':    0, 'z': -20, 'y':   0, 'rotation':   0 }

}
def get_offsets(item, direction):
    offn = OFFSETS_NORTH.get(item)
    if not offn:
        return { 'x'        : 0
               , 'z'        : 0
               , 'y'        : 0
               , 'rotation' : 0
               }
    rotate_by = ROTATION_FROM_NORTH[direction]
    xr, zr = rotate(offn['x'], offn['z'], rotate_by)
    return { 'x'        : xr
           , 'z'        : zr
           , 'y'        : offn['y']
           , 'rotation' : (offn['rotation'] + rotate_by) % 360
           }

def calc_emit_args(item, curr_coord, parser_state):
    direction = parser_state['direction']
    offsets = get_offsets(item, direction)
    args = { "station"       : item
           , "station_index" : next_station_index(item, parser_state)
           , "x"             : curr_coord.get("x") + offsets.get("x")
           , "z"             : curr_coord.get("z") + offsets.get("z")
           , "y"             : curr_coord.get("y") + offsets.get("y")
           , "rotation"      : (ROTATION[direction]
                                + offsets.get("rotation")) % 360
           }
    return args

def emit_line(args, parser_state):
    station_key = '{station} {station_index}'.format(**args)
    args["station_key"] = station_key
    args["furn_id"] = get_furn(args['station'], args['station_index'], parser_state)
    template = ( '"{furn_id}\t{x:>5.0f}'
                +'\t{z:>5.0f}\t{y:>5.0f}\t{rotation:3} {station_key:<10}"')
    line     = template.format(**args)
    LOG("EMIT {}".format(line))
    parser_state["output_lines"].append(line)

def next_station_index(station, parser_state):
    index   = 1 + (parser_state['furn_index_prev'].get(station) or 0)
    parser_state['furn_index_prev'][station] = index
    return index

def append_end_lamp(parser_state):
    # If the item queue does not already end in a lamp.
    # append one now.
    q = parser_state['item_queue']      # for less typing
    if 0 == len(q) or is_lamp(q[-1]):
        return
    q.append('lamp')

def is_lamp(item):
    return item in ['hide lamp', 'omit lamp', 'lamp', 'sconce']

def parse_lines(input_lines, input_filepath, parser_state):
    line_number  = 0
    for line in input_lines:
        line_number += 1
        parsed_line = parse_one_line(line, line_number, input_filepath)
        apply_line(parsed_line, parser_state)
        if parser_state.get('end'):
            return

# -- main --------------------------------------------------------------------

def main():
    LOG("Cheers luv!")
    if len(sys.argv) < 3:
        sys.stderr.write("Usage: python3 Parser.py <inputfile> <outputfile>")
        sys.exit(1)

    output_filepath = sys.argv[-1]
    parser_state    = ParserState()
    for input_filepath in sys.argv[1:-1]:
        LOG("file: {}".format(input_filepath))
        with open(input_filepath) as f:
            input_lines = f.readlines()

        parse_lines(input_lines, input_filepath, parser_state)

    output_lines = parser_state.get('output_lines')
    LOG("writing file:{}  data line_ct:{}", output_filepath, len(output_lines))
    with open(output_filepath, "w") as f:
        f.write("ZZCraftoriumLayout = ZZCraftoriumLayout or { }\n\n")
        f.write("-- furniture_unique_id  x       z       y       rot station index\n")
        f.write("ZZCraftoriumLayout.POSITION = {\n  ")
        f.write("\n, ".join(output_lines))
        f.write("\n}\n")

main()
