#!/bin/bash

# Simple bash script to automate vairous photo management related tasks.
#
# Features:
#   * rename files using EXIF timestamp
#   * set modification time to creation
# 
# Dependencies:
#   * exiftool - metadata management
#
# Author:  Zoltan Vass <zoltan.vass.2k6@gmail.com>
# Licence: ?
#


###############################################################################
# Global variables, default parameters
###############################################################################

PROGRESS='-progress'
ACT_RENAME=0  # Rename files.
ACT_TOUCH=0   # Set modification time.


###############################################################################
# Usage
###############################################################################

# Prints usage information
usage () {
echo "Usage:
  $0 [actions...] <inputs...>
Where:
  <inputs...> - image files to be processed, wildcards allowed,
                eg. ~/photos/concert/*.jpeg

Actions:
  Arguments mandatory for short options are mandatory for long options too.

  General:
    -r, --rename
        Rename the input files using the timestamp of creation found in EXIF.
    -t, --touch
        Set modification time to the creation time found in EXIF.
    -h, --help
        Displays this screen.
"
}


###############################################################################
# Parse options
###############################################################################
TEMP=$(getopt --options rth \
              --longoptions rename,touch,help \
              --name "$0" \
              -- "$@")
if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi
eval set -- "$TEMP"

while true ; do
  case "$1" in
    -r|--rename) ACT_RENAME=1 ; shift 1 ;;
    -t|--touch) ACT_TOUCH=1 ; shift 1 ;;
    -h|--help) usage ; exit 0 ;;
    --) shift ; break ;;
    *) echo "Internal error!" ; exit 1 ;;
  esac
done


###############################################################################
# Auxiliary functions
###############################################################################

# Renames an image using it's EXIF creation timestamp.
#
# @param [in] $1 - path to file
act_rename() { img="$1"
  exiftool $PROGRESS '-FileName<DateTimeOriginal' -d %Y-%m-%d_%H-%M-%S%%-c.%%e "$img" >/dev/null
}

# Sets the modification timestamp to that of EXIF creation.
#
# @param [in] $1 - path to file
act_touch() { img="$1"
  exiftool $PROGRESS '-FileModifyDate<DateTimeOriginal' "$img" >/dev/null
}

###############################################################################
# Perform actions
###############################################################################

echo ':: Processing images'

# Process an image fully before moving onto the next.
for arg do
  for file in $(ls "$arg"); do
    echo -n "[    ] processing $file "
    
    # Perform requested actions.
    if [ "$ACT_TOUCH" -eq "1" ]; then
      echo -n 'timestamp... '
      act_rename $file
      echo -n 'done! '
    fi

    # Do rename last!
    if [ "$ACT_RENAME" -eq "1" ]; then
      echo -n 'renaming... '
      act_rename $file
      echo -n 'done! '
    fi
    
    echo -e '\r[DONE]'
  done
done

# Exit
exit 0
