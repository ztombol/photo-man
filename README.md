# photo-man

photo-man is a free and open-source utility aiming to simplify photo management
on the Linux command line by providing an easy to use interface to common
tasks, such as:

- moving and renaming based on `EXIF DateTimeDigitized`
- set file system modification timestamp to the date and time corresponding to
  `EXIF DateTimeDigitized` in the local time zone

For all features, see the manual by issuing `$ photo-man --man`.

# Examples

You arrived home from your month-long vacation in Japan a week ago and it's
time to sort your photos you took with your camera, phone and Google glass.
There are quite a few inconveniences photo-man can spare you from.

## Sorting & re-ordering

The photos are scattered though your gadgets, which very likely follow
different naming conventions. So even if you copy all photos to the same
directory, related photos may still end up far from each other and/or out of
order.

photo-man can sort your photos moving them to separate directories based on
which day they were taken, while also renaming them to ensure related photos
end up next to each other in correct order.

```sh
$ photo-man --move   'vacation/\%y.\%m'             \
            --rename 'img-\%y\%m\%d-\%h\%m\%s'      \
            /mnt/camera/* /mnt/phone/* /mnt/glass/*
```

The above command will make sure that you will find related photos easily, to
maybe further sort them manually, and that they will all be in the order they
were taken.

Of course, the *templates* describing the directory and file naming convention
can be arbitrarily changed to sort photos at greater/smaller granularity, and
name files differently.

## Slight OCD fixation

Optionally, you can also add `--use-magic` to fix badly spelled, incorrect or
missing extensions by determining the correct one using the [magic
number][wiki-magic] of the file.

```sh
$ photo-man --rename --use-magic *
```

This command will fix the extension of every file in the current directory and
potentially cause a fair amount of satisfaction for OCD enthusiasts.

# Contribute!

photo-man is my first contribution to the open-source community I benefited so
much from. The project is licensed under [GPL version 3][gplv3] to ensure user
freedom, encourage collaboration, and thank the free software community.

Contribution at any level, new features, fixes, bug reports, testing, feature
requests, suggestions, saying hi!, are all welcome.

photo-man is written in Perl. You can find the latest source on
[github][pm-gh]. For contact see the [authors section](authors).

Use it, fork it, hack it, have fun with it!

# Authors

[zoltan vass][zvass-hp] -- zoltan.tombol (at) gmail (dot) com


[wiki-magic]: <http://en.wikipedia.org/wiki/file_format#magic_number>
[gplv3]:      <http://gplv3.fsf.org/>
[pm-gh]:      <https://github/ztombol/photo-man> "fork me! \^o^/"
[zvass-hp]:   <https://github.com/ztombol>
