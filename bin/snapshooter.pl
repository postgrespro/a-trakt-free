#!/usr/bin/perl

use strict;

my $command = shift @ARGV;

die "Укажите команду первым аргументом" unless $command;

if ($command eq "init")
{
    my $mount_path = shift @ARGV;
    my $image_path = shift @ARGV;
    my $snapshot_size = shift @ARGV;
    my $snapshots_count = shift @ARGV;

    unless ($image_path && $mount_path && $snapshot_size && $snapshots_count)
    {
      die "Команде init нужны 4 параметра: точка монтирования,путь к образу,  размер снэпшота и из кол-во";
    }

    `sudo mountpoint -q $mount_path`;
    unless( $?)
    {
        print "$mount_path -- примонтирован. Пробуем отмонтировать...\n";
        `sudo umount $mount_path`;
    }

    my $min_btrfs_size = 114294784;
    if ($snapshot_size * $snapshots_count < $min_btrfs_size)
    {
        print "Увеличиваем размер образа до минимально возможных $min_btrfs_size байт";
        $snapshot_size = $min_btrfs_size;
        $snapshots_count = 1;
    }

    print "Создаем и форматируем образ...\n";
    `dd if=/dev/zero of=$image_path count=$snapshots_count bs=$snapshot_size`;
    `sudo mkfs.btrfs $image_path`;

    print "Монтируем образ...\n";
    `mkdir -p $mount_path`;
    `sudo mount $image_path $mount_path`;

    print "Создаем reference снэпшот...\n";
    `sudo btrfs subvolume create $mount_path/_reference`;
}

if ($command eq "clone")
{
    my $mount_path = shift @ARGV;
    my $target = shift @ARGV;

    unless ($target)
    {
      die "Команде $command нужны 2 параметра: точка монтирования, имя снэпшота";
    }

    my $name = "$mount_path/$target.base";

    if (-e $name)
    {
        die "Снэпшот $name уже существует";
    }
    print "Создаю основу для снэпшота $target: $name\n";

    `sudo btrfs subvolume snapshot $mount_path/_reference $name`;
}

if ($command eq "reset")
{

    my $mount_path = shift @ARGV;
    my $target = shift @ARGV;

    unless ($target)
    {
      die "Команде $command нужны 2 параметра: точка монтирования, имя снэпшота";
    }
    my $name = "$mount_path/$target";
    unless (-e "$name.base")
    {
        die "Не существует основы для снэпшота $target: $name.base";
    }

    print "Обновляю снэпшот $target: \n";

    if (-e $name)
    {
        `sudo btrfs subvolume delete $name`;
         print "Удаляем старый\n";
    }

    print "Создаем новый\n";

    `sudo btrfs subvolume snapshot $name.base $name`;
}
