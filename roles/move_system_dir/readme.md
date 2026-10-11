### Move system directory from the first system disk to a separate LV/partition
This role helps you to move a system directory (e.g. /var) or multiple directories to a separate logical volume(s) or partition(s). The main disadvantage of the role is that it doesn't clean up the original system directory location, so you are going to lose some disk space on the fisrt disk. We are considering to use this role basically on VMs, which are freshly deployed from a cloud image, so the waste of the disk space will be really insignificant.

## Requirements
Your VM must already have a mounted file system (e.g. /data1), which is gonna be used as a destination point for the system directory data.

## Process overview
- make rsync filter in the source directory if some exclusions are defined;
- collect stats about source files and sub-directories numbers;
- synchronize data from the source to the destination;
- collect the destination stats (files and dirs numbers) and compare them to the source stats;
- edit /etc/fstab, so the current destination (e.g. /data1) becomes the current source (e.g. /var);
- reboot;
- show  the moved system directory mount information;
- test file creation and removal.  

## Exclusions description
Synchronization exclusions are made via .rsync-filter file. Directories to be excluded must be specified as **relative** paths. To exclude /var/lib from /var (if you are planning to move both /var and /var/lib to separate volumes) the variable must look like that:
```
move_system_dir_config:
  - source: /var
    dest: /data1
    excludes:
      - /lib
``` 
You may specify multiple exclusions and multiple directories to move. **Correct example**:
```
move_system_dir_config:
  - source: /var
    dest: /data1
    excludes:
      - /lib
      - /snap
  - source: /var/lib
    dest: /data2
  - source: /var/snap
    dest: /data3
```
**Incorrect example** (do not specify list "excludes" if it is empty)
```
move_system_dir_config:
  - source: /var
    dest: /data1
    excludes:
      - /lib
      - /snap
  - source: /var/lib
    dest: /data2
    excludes:
  - source: /var/snap
    dest: /data3
    excludes:
```
To collect files and sub-directories stats (numbers tbh) ansible shell module is used, because ansible.builtin.find doesn't properly work with exclusions at the moment. Find commands are templated and their forms depend on the exclusions.<br />
Be careful: besides the fact you can specify exclusions, **synchronization source is bound to a single file system**. That means, if /var/lib is already located on a separate volume and you are going to move /var to its own volume, you don't have to specify the exclusion for /var/lib (but you can though). If you want to change this behaviour and control your exclusions with **only** "excludes" sub-list, remove **"--one-file-system"** from tasks/sync_stats_and_mount_config.yml.
Option "--hard-links" is added to preserve hard links structure on the destination file system (e.g. /var has a few hard links).
