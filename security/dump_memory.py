#!/usr/bin/env python3

# Kudos: https://stackoverflow.com/questions/12977179/reading-living-process-memory-without-interrupting-it

import re
import sys

def print_memory_of_pid(pid, only_writable=True):
    """ 
    Run as root, take an integer PID and return the contents of memory to STDOUT
    """
    memory_permissions = b'rw' if only_writable else b'r-'
    sys.stderr.write("PID = %d" % pid)
    with open("/proc/%d/maps" % pid, 'rb') as maps_file:
        with open("/proc/%d/mem" % pid, 'rb', 0) as mem_file:
            for line in maps_file.readlines():  # for each mapped region
                m = re.match(rb'([0-9A-Fa-f]+)-([0-9A-Fa-f]+) ([-r][-w])', line)
                if m.group(3) == memory_permissions:
                    sys.stderr.buffer.write(b"\nOK : \n" + line + b"\n")
                    start = int(m.group(1), 16)
                    if start > 0xFFFFFFFFFFFF:
                        continue
                    end = int(m.group(2), 16)
                    sys.stderr.write("start = " + str(start) + "\n")
                    mem_file.seek(start)  # seek to region start
                    chunk = mem_file.read(end - start)  # read region contents
                    sys.stdout.buffer.write(chunk)  # dump contents to standard output
                else:
                    sys.stderr.buffer.write(b"\nPASS : \n" + line + b"\n")

if __name__ == '__main__': # Execute this code when run from the commandline.
    try:
        assert len(sys.argv) == 2, "Provide exactly 1 PID (process ID)"
        pid = int(sys.argv[1])
        print_memory_of_pid(pid)
    except (AssertionError, ValueError) as e:
        print("Please provide 1 PID as a commandline argument.")
        print("You entered: %s" % ' '.join(sys.argv))
        raise e
