import os
import random

from smokepy.values import Values

values_basedir = None
value_files_specified = None
values = None

def load_values(valueFiles = []):
    values = Values()
    for f in valueFiles:
        if not os.path.isabs(f):
            f = os.path.abspath(os.path.join(values_basedir, f))

        print( "Loading values from", f )
        values.load_yaml_file(f)

    return values

def init(caller_file: str, values_subdir: str, default_value_files = [], extra_value_files = []):
    global values, value_files_specified, values_basedir

    # determine the base dir relative to the location of the caller's file
    values_basedir = os.path.abspath(
        os.path.join(
            os.path.dirname(os.path.realpath(caller_file)),
            values_subdir
        )
    )

    value_files_specified = extra_value_files or []

    vfvar = os.getenv("SMOKEPY_VALUE_FILES")
    if vfvar is not None and vfvar != "":
        value_files_specified = vfvar.split(":") + extra_value_files

    if len(value_files_specified) == 0:
        print("NOTE: You may have to define $SMOKEPY_VALUE_FILES to load the appropriate value files.")

    files_to_load = default_value_files + value_files_specified
    values = load_values(files_to_load)

uniq = 0

def nextIp():
    global uniq
    uniq += 1
    a = random.randint(1,255)
    b = random.randint(1,255)
    c = ( uniq & 0xFF00 ) >> 8
    d = ( uniq & 0x00FF ) >> 0

    return f"{a}.{b}.{c}.{d}"

def nextName(name):
    global uniq
    uniq += 1
    r = random.randint(1,1000)
    return f"{name}-{uniq}-{r}"
