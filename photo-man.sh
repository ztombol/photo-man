#!/bin/bash

# Simple bash script to automate vairous photo management related tasks.
# 
# Dependencies:
#	+ exiftool - metadata management
#
# Author:  Zoltan Vass <zoltan.vass.2k6@gmail.com>
# Licence: ?
#

PROGRESS='-progress'

# rename
exiftool $PROGRESS '-FileName<DateTimeOriginal' -d %Y-%m-%d_%H-%M-%S%%-c.%%e  $1

# fix timestamp
exiftool $PROGRESS '-FileModifyDate<DateTimeOriginal' $1

