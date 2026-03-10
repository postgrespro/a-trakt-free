#!/usr/bin/perl

use strict;
use FindBin;
use lib $FindBin::Bin."/../lib";
use Trakt;
use Test::More;
use Test::Exception;
use Path::Tiny;
use JSON;

my $branch_name = 'none';
my $trakt_name  = "011_forced_conf";

my $tmp_dir   = path($FindBin::Bin."/tmp");
$tmp_dir->remove_tree if $tmp_dir->exists;

my $trakt_dir = path($FindBin::Bin)->child($trakt_name);

sub _copy_trakt_dir {
    my ( $src, $dst ) = @_;
    $dst->mkpath;
    for my $child ( $src->children ) {
        if ( $child->is_dir ) {
            _copy_trakt_dir( $child, $dst->child( $child->basename ) );
        }
        else {
            $child->copy( $dst->child( $child->basename ) );
        }
    }
}

my $tmpl = "/tmp/011_forced_conf.none.";
my $cache_tmpl_step = $tmpl."cache/step3";
my $target_cache_dir = path($FindBin::Bin.$cache_tmpl_step."/target1");

=head1 GROUP: Методы
=head1 SUBGROUP: Trakt::Step::conf
=head1 TYPE: Негативные
=head1 TEST: Вызывает die, если JSON-файл конфигурации не найден (по умолчанию — config.json)
=cut
subtest 'Вызывает die, если JSON-файл конфигурации не найден (по умолчанию — config.json)' => sub {
    my $trakt = Trakt->create( name => $trakt_name, branch => $branch_name );
    $trakt->work_dir($tmp_dir);
    # step1 не имеет конфигурационных файлов
    throws_ok(
        sub {
            $trakt->step('step1')->conf;
        }, qr/config.json\' is not found at/
    );
};

=head1 GROUP: Методы
=head1 SUBGROUP: Trakt::Step::conf
=head1 TYPE: Негативные
=head1 TEST: Вызывает die, если указанный в параметрах JSON-файл (например, my_config.json) не найден
=cut
subtest 'Вызывает die, если указанный в параметрах JSON-файл (например, my_config.json) не найден' => sub {
    my $trakt = Trakt->create( name => $trakt_name, branch => $branch_name );
    $trakt->work_dir($tmp_dir);
    # step1 имеет пустую conf_dir — my_config.json отсутствует
    throws_ok(
        sub {
            $trakt->step('step1')->conf('my_config');
        }, qr/my_config.json\' is not found at/
    );
};

=head1 GROUP: Методы
=head1 SUBGROUP: Trakt::Step::conf
=head1 TYPE: Позитивные
=head1 TEST: Возвращает hashref с параметрами из указанного JSON-файла (my_config.json), если forced_conf не задан
=cut
subtest 'Возвращает hashref с параметрами из указанного JSON-файла (my_config.json), если forced_conf не задан' => sub {
    $tmp_dir->mkpath unless $tmp_dir->exists;
    my $trakt = Trakt->create( name => $trakt_name, branch => $branch_name );
    $trakt->work_dir($tmp_dir);
    # step2 имеет my_config.json и не упоминается в 011_forced_conf.toml — читаем из файла
    my $actual = $trakt->step('step2')->conf('my_config');
    my $expected = {
        string => 'custom_string',
        list   => [ 'custom_value1', 'custom_value2', 'custom_value3' ],
        hash   => { 'key1' => 'custom_key1value', 'key2' => 'custom_key2value' },
    };
    is_deeply $actual, $expected, 'возвращает данные из файла my_config.json';

    #clean
    $tmp_dir->remove_tree if $tmp_dir->exists;
};

=head1 GROUP: Методы
=head1 SUBGROUP: Trakt::Step::conf
=head1 TYPE: Позитивные
=head1 TEST: Возвращает hashref с параметрами из forced_conf (приоритет над локальным файлом конфигурации)
=cut
subtest 'Возвращает hashref с параметрами из forced_conf (приоритет над локальным файлом конфигурации)' => sub {
    $tmp_dir->mkpath unless $tmp_dir->exists;
    my $trakt = Trakt->create( name => $trakt_name, branch => $branch_name );
    $trakt->work_dir($tmp_dir);
    # forced_conf читается из work_dir/011_forced_conf.toml; step3 и my_config заданы в toml
    $trakt_dir->child("$trakt_name.toml")->copy($tmp_dir);

    my $actual = $trakt->step('step3')->conf('my_config');
    my $expected = { list => [ 'value1', 'value2', 'value3' ] };
    is_deeply $actual, $expected, 'возвращает данные раздела step3 из файла trakt_name.toml';

    #clean
    $tmp_dir->remove_tree if $tmp_dir->exists;
};

=head1 GROUP: Методы
=head1 SUBGROUP: Trakt::Step::conf
=head1 TYPE: Позитивные
=head1 TEST: Первое обращение читает конфиг из файла, второе и последующие — из кеша (подмена файла не влияет)
=cut
subtest 'Первое обращение читает конфиг из файла, второе и последующие — из кеша (подмена файла не влияет)' => sub {
    $tmp_dir->mkpath unless $tmp_dir->exists;
    _copy_trakt_dir( $trakt_dir, $tmp_dir->child($trakt_name) );
    my $trakt = Trakt->create( name => $trakt_name, branch => $branch_name );
    $trakt->work_dir($tmp_dir);
    $trakt->trakt_path($tmp_dir);

    my $step    = $trakt->step('step2');
    my $cfg_dir = $step->conf_dir;
    my $expected = decode_json( $trakt_dir->child('step2')->child('my_config.json')->slurp );

    my $actual_first = $step->conf('my_config');
    is_deeply $actual_first, $expected, 'первый вызов conf возвращает данные из файла';

    # подменяем файл содержимым заранее подготовленного my_config_spoofed.json
    $cfg_dir->child('my_config.json')->spew( $cfg_dir->child('my_config_spoofed.json')->slurp );

    my $actual_second = $step->conf('my_config');
    is_deeply $actual_second, $expected, 'второй вызов conf возвращает данные из кеша, не из подменённого файла';

    #clean
    $tmp_dir->remove_tree if $tmp_dir->exists;
};

=head1 GROUP: Методы
=head1 SUBGROUP: Trakt::Step::conf
=head1 TYPE: Позитивные
=head1 TEST: При forced_conf первое обращение — из forced_conf, второе — из кеша
=cut
subtest 'При forced_conf первое обращение — из forced_conf, второе — из кеша' => sub {
    $tmp_dir->mkpath unless $tmp_dir->exists;
    _copy_trakt_dir( $trakt_dir, $tmp_dir->child($trakt_name) );
    $trakt_dir->child("$trakt_name.toml")->copy($tmp_dir);

    my $trakt = Trakt->create( name => $trakt_name, branch => $branch_name );
    $trakt->work_dir($tmp_dir);
    $trakt->trakt_path($tmp_dir);

    my $step = $trakt->step('step3');
    my $expected_forced = { list => [ 'value1', 'value2', 'value3' ] };

    my $actual_first = $step->conf('my_config');
    is_deeply $actual_first, $expected_forced, 'первый вызов conf возвращает данные из forced_conf';

    $step->conf_dir->child('my_config.json')->remove;

    my $actual_second = $step->conf('my_config');
    is_deeply $actual_second, $expected_forced, 'второй вызов conf возвращает данные из кеша после удаления файла';

    #clean
    $tmp_dir->remove_tree if $tmp_dir->exists;
};

=head1 GROUP: Методы
=head1 SUBGROUP: Trakt::Step::conf
=head1 TYPE: Позитивные
=head1 TEST: Вызов conf для другого конфига не затирает кеш первого (изоляция кеша по имени конфига)
=cut
subtest 'Вызов conf для другого конфига не затирает кеш первого (изоляция кеша по имени конфига)' => sub {
    $tmp_dir->mkpath unless $tmp_dir->exists;
    my $trakt = Trakt->create( name => $trakt_name, branch => $branch_name );
    $trakt->work_dir($tmp_dir);
    my $step = $trakt->step('step3');
    # config_one.json и config_two.json уже лежат в тракте step3/
    my $config1 = { list => [ 1, 2 ] };
    my $config2 = { list => [ 3, 4 ] };

    my $actual1 = $step->conf('config_one');
    is_deeply $actual1, $config1, 'conf(config_one) возвращает первый конфиг';

    my $actual2 = $step->conf('config_two');
    is_deeply $actual2, $config2, 'conf(config_two) возвращает второй конфиг';

    my $actual1_again = $step->conf('config_one');
    is_deeply $actual1_again, $config1, 'повторный conf(config_one) по-прежнему возвращает первый конфиг (кеш не затёрт)';

    #clean
    $tmp_dir->remove_tree if $tmp_dir->exists;
};

done_testing();
