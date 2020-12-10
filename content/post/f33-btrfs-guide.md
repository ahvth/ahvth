---
title: "Getting Started with BTRFS Snapshots in Fedora 33"
tags: ["guide", "btrfs", "backup", "snapshotting"]
date: 2020-11-08T19:46:59+01:00
draft: false
---

I've been convinced for a while now that Fedora is the cleanest, most "put together" of the mainstream Linux distros. With the release of Fedora 33, I was finally persuaded to make the move from Arch Linux to Fedora on my main workstation, in no small part because I really wanted to see what the Fedora team was doing with BTRFS. Call me disappointed when I found out that all they had really done with BTRFS was set it as default and roll a somewhat uninspired subvolume layout, but we'll try to wrap our head around what we can do with the default setup. Here's how the subvolumes look by default on Fedora:

```
~ $ sudo btrfs sub list /
ID 256 gen 43073 top level 5 path home
ID 257 gen 43073 top level 5 path root
ID 265 gen 31079 top level 257 path var/lib/machines
```

Looking at fstab I can see that the first two subvolumes are set up exactly where I'd expect them to be:

```
~ $ cat /etc/fstab
UUID=765f6fff-7a69-4af8-97e8-9e0171283a69	/		btrfs	subvol=root			0 0
UUID=44f6a310-41aa-4d2e-8a75-d1f02d92949b	/boot		ext4    defaults			1 2
UUID=9FFB-450F					/boot/efi	vfat    umask=0077,shortname=winnt	0 2
UUID=765f6fff-7a69-4af8-97e8-9e0171283a69	/home		btrfs   subvol=home			0 0
```

There wasn't really much documentation to go off on how they intended me to start using BTRFS for its advanced features, besides [two](https://fedoramagazine.org/btrfs-snapshots-backup-incremental/) [posts](https://fedoramagazine.org/recover-your-files-from-btrfs-snapshots/) in the Fedora magazine, which, while posing a serviceable solution, didn't really make the fullest use of the feature set of BTRFS.

In the end, I decided to go off my previous experience with BTRFS and use the `snapper` tool from SUSE. So, from this point forward, we'll be looking at how we can use `snapper` to take automated incremental snapshots and restore from those on a live system **instantly**.

## Manual Snapshotting

First, we want to install `snapper`. Easy.

```
sudo dnf install snapper
```

Our first step out of the box will be to set up a "config" which really acts like a repository for snapshots. I will be setting up snapshotting for the `root` subvolume, as that's the area where I might need to revert changes (say, due to a borked update or major version upgrade - snapshotting root won't include the kernel, more on that later).

```
sudo snapper -c root create-config /
```

This will set up a config called `root` for the root directory. Note that because `/home` and `var/lib/machines` exist in separate subvolumes, they will be excluded from the snapshots. Handy! Now we know we can move our files into new subvolumes within our existing subvolumes to exclude those files from snapshots taken from the root of the "parent" subvolume.

But, moving on, let's test out our new config to make sure everything works. I'll take a snapshot called "base" to get us started:

```
sudo snapper -c root create -d "base"
```

Now let's confirm it's creation:

```
~ $ sudo snapper -c root list
  # | Type   | Pre # | Date                            | User | Used Space | Cleanup  | Description | Userdata
----+--------+-------+---------------------------------+------+------------+----------+-------------+---------
 0  | single |       |                                 | root |            |          | current     |         
 1  | single |       | Sat 07 Nov 2020 12:14:50 AM CET | root | 468.00 KiB |          | base        |
```

There she blows! We can see that the first snapshot was successfully created. A short note - if `snapper list` takes a long time for you, that has been my experience with it as well, so don't be alarmed. Maybe we can fix this later.

Now let's test a rollback to make sure everything works. Create a file in your root directory, in my case a directory called `/beacon` and take another snapshot:

```
sudo mkdir /beacon
sudo snapper -c root create -d "beacon"
```

Check if the snapshot is there:

```
~ $ sudo snapper -c root list
  # | Type   | Pre # | Date                            | User | Used Space | Cleanup  | Description | Userdata
----+--------+-------+---------------------------------+------+------------+----------+-------------+---------
 0  | single |       |                                 | root |            |          | current     |         
 1  | single |       | Sat 07 Nov 2020 12:14:50 AM CET | root | 468.00 KiB |          | base        |         
 2  | single |       | Sat 07 Nov 2020 12:16:22 AM CET | root |   5.09 MiB |          | beacon      |
```

Nice! Now we can use snapper to get a list of what changed between the snapshots by referencing the id in the `#` column... really handy for finding out why you borked your system (with a little create use of `grep`)

```
~ $ sudo snapper -c root status 1..2
+..... /beacon
c..... /var/lib/NetworkManager/timestamps
c..... /var/log/audit/audit.log
c..... /var/log/journal/1bdc1ee18ec74e4394197459cf787353/system.journal
c..... /var/log/journal/1bdc1ee18ec74e4394197459cf787353/user-1000.journal
c..... /var/log/snapper.log
```

We can see that `/beacon` was added, and there were some changes in my system logs, which is to be expected, naturally! Lets try a rollback...

```
sudo snapper -c root undochange 1..2
```

You should see that the root folder was reset to the state in the `base` snapshot, and the `/beacon` folder is now gone! You can roll back really complex changes in realtime while the filesystem is active, but it's probably best to ignore directories that you know are in frequent motion to avoid data inconsistency issues, as BTRFS doesn't do any data consistency checks on snapshotting. One way to do that would be to put those directories in separate subvolumes to avoid them being captured in a snapshot of their parent subvolume.

> To do: investigate implementing snapper / grub implementation on Fedora for more reliable rollbacks!

## Automating Snapshotting

Now that we know the basic commands to manage snapshots, let's set up an automated `timeline` snapshot. This is enabled by default in the config's configuration file, which will be located at `/etc/snapper/configs/root`. All we really need to do is turn on the associated systemd timer and set a snapshot retention policy that's sympathetic to us. I have some space to spare and I'd like to have the freedom to make some bigger rollbacks (in case it takes me a while to realize there's an issue I need to rollback for), so I told snapper to retain 12 daily snapshots. Here's the relevant section in `/etc/snapper/configs/root`:

```
# cleanup hourly snapshots after some time
TIMELINE_CLEANUP="yes"

# limits for timeline cleanup
TIMELINE_MIN_AGE="1800"
TIMELINE_LIMIT_HOURLY="10"
TIMELINE_LIMIT_DAILY="12"
TIMELINE_LIMIT_WEEKLY="0"
TIMELINE_LIMIT_MONTHLY="10"
TIMELINE_LIMIT_YEARLY="10"
```

In order for the cleanup to take effect, we need to activate the related systemd timer:

```
sudo systemctl enable snapper-cleanup.timer
sudo systemctl start snapper-cleanup.timer
```

All that's left at this point is to activate the systemd timer for the actual snapshotting service:

```
sudo systemctl enable snapper-timeline.timer
sudo systemctl start snapper-timeline.timer
```

Check that the timer is active:

```
~ $ sudo systemctl status snapper-timeline.service
● snapper-timeline.service - Timeline of Snapper Snapshots
     Loaded: loaded (/usr/lib/systemd/system/snapper-timeline.service; static)
     Active: inactive (dead) since Sun 2020-11-08 20:00:02 CET; 40min ago
TriggeredBy: ● snapper-timeline.timer
       Docs: man:snapper(8)
             man:snapper-configs(5)
    Process: 215148 ExecStart=/usr/libexec/snapper/systemd-helper --timeline (code=exited, status=0/SUCCESS)
   Main PID: 215148 (code=exited, status=0/SUCCESS)
        CPU: 6ms

Nov 08 20:00:01 onyx systemd[1]: Started Timeline of Snapper Snapshots.
Nov 08 20:00:01 onyx systemd-helper[215148]: running timeline for 'root'.
Nov 08 20:00:02 onyx systemd[1]: snapper-timeline.service: Succeeded.
```

If we wait a couple hours, we should see that our `snapper -c root list` table is filling up with timeline snapshots!

```
~ $ sudo snapper -c root list
  # | Type   | Pre # | Date                            | User | Used Space | Cleanup  | Description | Userdata
----+--------+-------+---------------------------------+------+------------+----------+-------------+---------
 0  | single |       |                                 | root |            |          | current     |         
 1  | single |       | Sat 07 Nov 2020 12:14:50 AM CET | root | 468.00 KiB |          | base        |         
 2  | single |       | Sat 07 Nov 2020 12:16:22 AM CET | root |   5.09 MiB |          | beacon      |         
 3  | single |       | Sat 07 Nov 2020 12:22:02 AM CET | root |  30.85 MiB |          | rm geary    |         
 4  | single |       | Sat 07 Nov 2020 01:00:23 PM CET | root |   7.29 MiB | timeline | timeline    |         
 5  | single |       | Sat 07 Nov 2020 02:00:23 PM CET | root | 972.00 KiB | timeline | timeline    |         
 6  | single |       | Sat 07 Nov 2020 03:00:23 PM CET | root |   8.73 MiB | timeline | timeline    |         
 7  | single |       | Sat 07 Nov 2020 04:00:23 PM CET | root |   7.51 MiB | timeline | timeline    |         
 8  | single |       | Sat 07 Nov 2020 05:00:23 PM CET | root |   8.40 MiB | timeline | timeline    |         
 9  | single |       | Sat 07 Nov 2020 06:00:23 PM CET | root |  83.77 MiB | timeline | timeline    |         
```

And that's it!

I mentioned before that we don't capture the kernel in these snapshots. So for the best results, if you roll back to a period with a previous kernel, it's probably best (for consistency reasons, if nothing else), to roll back the kernel by booting the previous kernel in GRUB before you roll back the system.

Happy snapshotting!
